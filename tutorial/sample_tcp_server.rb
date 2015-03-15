#!/usr/bin/env ruby

require 'socket'

socket = TCPServer.new(20000)

loop do
  connection = socket.accept
  connection.write(connection.gets)
  connection.close
end

socket.close
