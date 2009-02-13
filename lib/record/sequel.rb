
module Record
  
  require 'mysql'
  require  ROOT + '/lib/crazy_time.rb'
  
  class Mysql
    attr_reader :status
  
    def initialize
      $db_conn = Mysql.real_connect(DBCONN[:host], DBCONN[:username], DBCONN[:password], DBCONN[:database], DBCONN[:port])
      $logger.debug("Primary database initialized => #{DBCONN[:host]}")
      # Check to make sure there is a read db in the configs
      if DBCONN[:read_host].nil?
        $db_conn_read = $db_conn
      else
        $db_conn_read = Mysql.real_connect(DBCONN[:read_host], DBCONN[:read_username], DBCONN[:read_password], DBCONN[:read_database], DBCONN[:read_port])
      end
      $logger.debug("Secondary database initialized => #{DBCONN[:read_host]}")
    end

    def self.query(query_string)
      n = 0							# track how many times that the system had to reconnect to the db
=begin
      begin
        # Test to see if the query starts with a select which would mean it was a read query
        # This is way too slow.  Use the one below.  Bye bye automatic read and update dbs
        if query_string[/^SELECT|select/].nil?
          $logger.debug("Using update database => \"#{query_string}\"")
          res = $db_conn.query(query_string)
        else
          $logger.debug("Using read database => \"#{query_string}\"")
          res = $db_conn_read.query(query_string)
        end
      end
=end  
      begin
        res = $db_conn.query(query_string)
      rescue Mysql::Error => e
        $logger.error("Mysql query => #{query_string}")
        $logger.error("Mysql::Error '#{e.to_s}'")
        case e.to_s
          when 'MySQL server has gone away'
            $logger.warn("Connection to database #{DBCONN[:host]} has gone away.  Trying to reconnect.") if n == 0
            self.new
            n += 1
            retry
          when 'Lost connection to MySQL server during query'
            $logger.warn("Lost connection #{DBCONN[:host]}.  Trying to reconnect.") if n == 0
            self.new
            n += 1
            retry
          else
            # Don't know what to do because of an unknown error so to play it safe we'll just break instead looping
            $logger.warn("ERROR: #{e.to_s} Not sure what this error is to #{DBCONN[:host]}.")
            break
          end
        end
      return res
    end
  
  end
end