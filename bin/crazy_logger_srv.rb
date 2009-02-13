#!/usr/bin/env ruby
#
# = Summary
# Crazy Logger Server
#  Created by Lee Chang on 2009-02-03.
#  Copyright (c) 2009. All rights reserved.
#
# = Usage
#    crazy_logger_srv.rb [option] <action>
#                   [-l | --logfile log file path]
#                   [-d | --device place for output]
#                   [-p | --port  port number]
#                   [--reload, ],  
#                   [--verbose, ]                      
#                   [-h | --help]
#
# logfile::
#   Log file to write to.
# port::
#   Port number that the server is listening on.
# reload::
#   Reload the configuration file and continue monitoring.
# help::
#   Displays this message.

ROOT = File.join(File.expand_path(File.dirname(__FILE__)), "../")
require 'rubygems'
require ROOT + '/lib/logger_http_service'
require ROOT + '/lib/daemonize'
require 'optparse'
include Daemonize

Dir[ "#{ROOT}/lib/*.rb"].each {|f| require f}

OPTIONS = Hash.new
OPTIONS[:port] = 3000
OPTIONS[:env] = :development
OPTIONS[:log] = "test.log"
OPTIONS[:pid] = "test.pid"
OPTIONS[:device] = "test.file"

OptionParser.new do |opts|
  opts.banner = "Usage: crazy_logger_srv.rb [options] [action]"

  opts.separator ""
  opts.separator "Options:"
  opts.on("-e", "--env ENVIRONMENT", "Environment to run as") {|env| OPTIONS[:env] = env.intern}
  opts.on("-P", "--port PORT", "Port for the server to listen on") {|port| OPTIONS[:port] = port}
  opts.on("-p", "--pid PATH", "Path to store the PID file") {|pid| OPTIONS[:pid] = pid}
  opts.on("-l", "--log PATH", "Path to log files") {|log| OPTIONS[:logs] = log}
  opts.on("-d", "--device DEVICE", "Device to send output to") {|device| OPTIONS[:device] = device}
  
  opts.separator ""
  opts.separator "Actions"
  opts.on("--restart", "Restart the server") {OPTIONS[:action] = :restart}

  opts.separator ""
  opts.on("-h", "--help", "Show this help message") {puts opts; exit}

  opts.separator""
  opts.parse!
end

def self.status
  return File.exists?(OPTIONS[:pid])
end

def self.start
  if status
    puts "#{APP_NAME} is already running"
  end
  pidFile = File.new(OPTIONS[:pid], 'w')
  pid = fork do
    TailFile.run
  end
  Process.detach(pid)
  pidFile.puts(pid)
  pidFile.close
end

def self.stop
  if status
    pidFile = File.open(OPTIONS[:pid], 'r')
    pidFile.each_line do |pid|
      pid.chomp!
      begin
        Process.kill("TERM", pid.to_i)
      #rescue
        #puts "Unable to kill process #{pid}"
      end
    end
    pidFile.close
    File.delete(OPTIONS[:pid])
  else
    puts "#{APP_NAME} is not started"
  end
end

# track open files
OPEN = {
  
}

puts OPTIONS[:device]
WORKER_PORT = OPTIONS[:port]
WORKER_PID = '.'
$write = CrazyLogger::FastWriter.new(OPTIONS[:device])

daemonize

CrazyLogger::Server.run