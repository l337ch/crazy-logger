module CrazyLogger
  
  MAX_WAIT = 60  # Max time to wait before checking to see if the file has been closed or moved
  
  def tail(file, interval=1)
     raise "Illegal interval #{interval}" if interval < 0

     File.open(file) do |io|
       loop do
         while ( line = io.gets )
           print line
         end

         # uncomment next to watch what is happening
         # puts "-"
         sleep interval
       end
     end
  end
  
end

=begin
      File.open(OPTIONS[:file], 'r') do |file|
        file.extend(File::Tail)
        file.interval = 1
        file.backward(0)
        file.tail do |line|    
          data = url + CGI.escape(servername + ':' + line)
          Curl::Easy.perform(data)
        end
      end
=end
