#!/usr/bin/env ruby1.9
#
# = Summary
# Crazy Logger Client
#  Created by Lee Chang on 2009-02-03.
#  Copyright (c) 2009. All rights reserved.
#

ROOT = File.join(File.expand_path(File.dirname(__FILE__)), "../")
require 'rubygems'
require 'optparse'
require 'curb'
require 'cgi'
require 'socket'

# set some default values
APP_NAME = 'crazylogger'

WORKER = {
  :status => :working,
  :max_read => 1000,
  :interval => 1,
  :max_interval => 120,
  :max_delay => 30,
  :max_retry => 30
}

OPTIONS = {
  :file => 'test.log',
  :log => 'crazy_logger.log',
  :server => Socket.gethostname,
  :url => 'http://127.0.0.1',
  :product => 'none',
  :port => 3000,
  :pid => 'crazylogger.pid',
  :action => ARGV.last
}
OPTIONS[:tmp] = '/tmp/' + File.basename(OPTIONS[:file]) + '.tmp'
URL = "#{OPTIONS[:url]}:#{OPTIONS[:port]}/#{OPTIONS[:product]}/"
  
  
# Send output to logging server
module CrazyLogger
  # default behavior is to read the file from the begin then start tailing
  class LogFile < File
    
    attr_reader :product, :date, :date_string
    # add some date and string functions to class File
    def initialize(fd, mode)
      super
      @product = OPTIONS[:product]
    end
    
    def open(fd, mode_string="r")
      super
    end
    
    def gets(sep_string=$/)
      super
      # find the date in the string and cast to date
      case @product
      when 'phone'
        $_[/(\d+)-(\d+)-(\d+)\s(\d+):(\d+):(\d+),(\d+)/]
        # $1 year, $2 month, $3 day, $4 hour, $5 min, $6 sec, $7 milli
        @date = Time.local($1, $2, $3, $4, $5, $6, $7)
      when 'rails'
        $_[/(\.*)\s(\d+)\s(\d+):(\d+):(\d+)/]
        # $1 mon(Abbr), $2 day, $3 hour, $4 min, $5 sec
        # need to set the year for rails _ HAVE TO FIX THIS FORMAT FOR RAILS APPS
        year = '2009'
        @date = Time.local(year, $1, $2, $3, $4, $5)
      when 'radio'
        $_[/(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+).(\d+)/]
        # $1 year, $2 month, $3 day, $4 hour, $5 min, $6 sec, $7 milli
        @date = Time.local($1, $2, $3, $4, $5, $6, $7)
      when 'apache'
        $_[/(\d+)\/(.*)\/(\d+):(\d+):(\d+):(\d+)/]
        # $1 day, $2 month(Abbr), $3 year, $4 hour, $5 min, $6 sec
        @date = Time.local($3, $2, $1, $4, $5, $6)
      end
      @date_string = @date.strftime("%m-%d-%Y")
      return $_
    end
  end
  
  class TailFile
    
    attr_accessor :io_pos
    
    def self.io_pos(tmp)
      # the file will be read for a previous position if a valid temp file is present
      if File.exists?(tmp)
        File.open(tmp, 'r').each_line { |line| @io_pos = line}
        # reset the read position if it is larger then the actual file size
        @io_pos = nil if @io_pos.to_i > File.size(OPTIONS[:file])
      else
        @io_pos = nil
      end
      return @io_pos
    end
    
    def self.mark_pos(tmp, io_pos)
      # record the last read position in a temp file
      File.open(OPTIONS[:tmp], 'w') {|f| f.write(io_pos) }
    end
    
    def self.send_data(line)
      data = URL + CGI.escape(OPTIONS[:server] + ':' + line)
      Curl::Easy.perform(data)
    end
    
    def self.conn_retry
      try = 1   # track number of retries
      success = false
      interval = 1
      max_retry = WORKER[:max_retry]
      curl = Curl::Easy.new("#{OPTIONS[:url]}:#{OPTIONS[:port]}")
      while !success
        begin
          success = curl.http_get
        rescue
          success = false
        end
        if !success
          puts "still trying"
          try += 1
          if try == max_retry && interval < WORKER[:max_interval]
            interval += 10
            puts "We've retried to often.  retrying every #{interval} secs now"
            max_retry += WORKER[:max_retry]/10
          end
          sleep interval
        end
      end
    end
    
    def self.run(file, io_pos = nil, interval=1)
      raise "Illegal interval #{interval}" if interval < 0
      @io_pos = io_pos || 0   # last file read position
      i = 0   # track how many lines are read
      LogFile.open(file, 'r') do |io|
        io.pos = @io_pos.to_i
        loop do
          while ( line = io.gets )
            if WORKER[:status] == :term
              shutdown(io_pos)
            end
            # get the date and the date without time
            date = io.date
            date_string = io.date_string
            begin
              send_data(line, date, date_string)
            rescue Curl::Err::ConnectionFailedError
              # server is unreachable for whatever reason
              puts "connection to server failed"
              # let's be safe amd save the file position
              mark_pos(OPTIONS[:tmp], io_pos)
              conn_retry
              retry
            end
            i += 1
            # mark the file position in the temp file if more then max_read lines
            if i > WORKER[:max_read]
              @io_pos = io_pos
              mark_pos(OPTIONS[:tmp], @io_pos)
              i = 0
            end
          end
          # save the file read position to the tmp file while sleeping
          if io.pos > @io_pos.to_i
            @io_pos = io.pos
            mark_pos(OPTIONS[:tmp], @io_pos)
          end
          sleep interval
        end
      end
    end
  end
    
  class CrazyCtl
  
    def self.handle_signals(io_pos)
      # termination signal
      Signal.trap("TERM") {terminate}
      # reload signal
      Signal.trap("HUP")  {reload}
    end
  
    def self.terminate(io_pos)
      # shutdown the program gracefully
      # save the current read position, no need to worry about setting @io_pos since we're leaving
      mark_pos(OPTIONS[:tmp], io_pos)
      exit    # we're outie
    end
  
    def self.reload
      # reload the program without interuption - not a restart
    
    end
  
    def self.status
      return File.exists?(OPTIONS[:pid])
    end

    def self.start
      if status
        puts "#{APP_NAME} is already running"
      else
        pidFile = File.new(OPTIONS[:pid], 'w')
        pid = fork do
          io_pos = CrazyLogger::TailFile.io_pos(OPTIONS[:tmp])
          CrazyLogger::TailFile.run(OPTIONS[:file], io_pos)
        end
        #Process.detach(pid)
        pidFile.puts(pid)
        pidFile.close
      end
    end
  
    def self.stop
      if status
        pidFile = File.open(OPTIONS[:pid], 'r')
        pidFile.each_line do |pid|
          pid.chomp!
          begin
            Process.kill("TERM", pid.to_i)
          rescue
            puts "Unable to kill process #{pid}"
          end
        end
        pidFile.close
        File.delete(OPTIONS[:pid])
      else
        puts "#{APP_NAME} is not started"
      end
    end
  
    def self.reload
    
    end

  end

def options
  OptionParser.new do |opts|
    opts.banner = "Usage: crazy_logger.rb [options] [action]"
    opts.separator ""
    opts.separator "Options"
    opts.on("-s", "--server Servername", "Name of server this is running on") {|s| OPTIONS[:server] = s}
    opts.on("-f", "--file Filename", "File to process") {|f| OPTIONS[:file] = f}
    opts.on("-P", "--port Port", "Port the logging server is listen on") {|p| OPTIONS[:port] = p}
    opts.on("-l", "--log Logfile", "Server log file") {|l| OPTIONS[:log] = l}
    opts.on("-k", "--product Productname", "Product name for the log. This is a required field") {|l| OPTIONS[:product] = l}
    opts.on("-u", "--url", "URL for logging server") {|u| OPTIONS[:url] = u}
    opts.on("-p", "--pid Pidfile", "Pidfile location") {|p| OPTIONS[:pid] = p}
    opts.on("-t", "--temp Tempfile", "Temp file location") {|t| OPTIONS[:tmp] = t}
    opts.on("-h", "--help", "Show this help message") {puts opts; exit}
    opts.separator ""
    opts.separator "Actions"
    opts.separator "\s\s\s\sstart\t\t\t\s\s\s\s\sStart the log reader"
    opts.separator "\s\s\s\sstop\t\t\t\s\s\s\s\sStop the log reader"
    opts.separator "\s\s\s\sreload\t\t\t\s\s\s\s\sReload the log reader"
    opts.separator "\s\s\s\srestart\t\t\t\s\s\s\s\sRestart the log reader"
    opts.separator "\s\s\s\sstatus\t\t\t\s\s\s\s\sShow log reader status"
    opts.separator ""
    opts.separator ""
    opts.parse!
    @opts = opts
  end
end

def main
  include CrazyLogger::CrazyCtl
  options
  
  # make sure product is defined
  if OPTIONS[:product] == 'none'
    puts "Missing product name"
    puts @opts
    exit
  end

  case OPTIONS[:action]
    when 'start'
      CrazyLogger.start
    when 'stop'
      CrazyLogger.stop
    when 'restart'
      CrazyLogger.stop
      CrazyLogger.start
    when 'status'
      if CrazyLogger.status
        puts "crazylogger is started"
      else
        puts "crazylogger is stopped"
      end
    else
      puts @opts
  end
end

main