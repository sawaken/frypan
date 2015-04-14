#!/usr/bin/env ruby

require 'socket'

loop do
  print "execution-command> "
  com = STDIN.gets
  print "execution-time> "
  time = STDIN.gets
  
  break unless com && time

  socket = TCPSocket.open("localhost", 20000)
  socket.write(com + time)
  puts "response: #{socket.gets}"
  socket.close
end
