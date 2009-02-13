
module CrazyLogger
  require 'eventmachine'
  require 'evma_httpserver'
  require 'cgi'
  module Server
    class LoggerHttpParser
    
      def self.parse_uri(request_path)
        begin
          uri = (request_path.split("/").collect {|r| r.intern unless r.empty?}).compact
        rescue NoMethodError
          uri = Hash.new
        end
        return uri
      end

      def self.parse_query_string(query_string)
        begin
          params = query_string.split('&').inject({}) {|h,(k,v)| h[k.split('=')[0].intern] = k.split('=')[1]; h}
        rescue NoMethodError
          params = Hash.new
        end
        return params
      end
    
    end
  
    class LoggerHttpResponse < EM::HttpResponse
      extend Forwardable
      def_delegators :@connection, :send_data, :close_connection_after_writing, :close_connection

      def initialize connection
        @connection = connection
        super()
      end

    end
  
    class  LoggerService< EM::Connection
      include EM::HttpServer

      def recieve_data data
        @uri = LoggerHttpParser.parse_uri(@http_request_uri)
        @params = LoggerHttpParser.parse_query_string(@http_query_string)
      end
      
      def process_http_request
        recieve_data self
        response = LoggerHttpResponse.new(self)
        response.status = 200
        response.content_type 'text/plain'
        #response.content = "#{@uri.inspect}\n#{URI.unescape(@params.inspect)}"
        begin
          $write.add(CGI.unescape(@params[:data]))
        rescue NoMethodError
          #$write.add("No data"   # don't care if there is no data
        end
        response.send_response
        response.close_connection_after_writing
      end
    
    end

    def self.run
      # Start the Master servers
      EM.run{
        EM.epoll
        EM.start_server '0.0.0.0', WORKER_PORT, LoggerService
        puts"Listening on PORT #{WORKER_PORT}..."
      }
      # Spawn workers to handle requests
    end

  end
  
end
  