#!/usr/bin/env ruby1.9
# Test crazy logger client

# Genernate messages in a log file

log = 'test.log'
run = ARGV[0].to_i
i = 0
message = "hey there this is message "
loop do
  File.open(log, (File::WRONLY | File::APPEND | File::CREAT)) {|line| line.puts(message + i.to_s )}
  i += 1
  sleep 1
end
  