#!/usr/bin/env ruby

require 'socket'

socket = TCPSocket.open("localhost", 20000)
socket.write(STDIN.gets)
puts socket.gets
socket.close
