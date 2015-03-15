#!/usr/bin/env ruby

require 'frypan'
require 'socket'
require 'time'

S = Frypan::Signal

socket = TCPServer.new(20000)
puts "my_atd listening port: 20000..."

accepter = proc do
  connection = socket.accept
  c, t = connection.gets, connection.gets
  {command_str: c.chomp, time_str: t.chomp, connection: connection}
end

timer = proc do
  Time.now
end

update_commands = proc do |commands, ct, cs|
  {
    waitings: commands[:waitings].select{|c| c[:time] > ct} +
    cs.select{|c| acceptable?(c)}.map{|c| c.update(time: Time.parse(c[:time_str]))},
    launcheds: commands[:waitings].select{|c| c[:time] <= ct},
    rejecteds: cs.reject{|c| acceptable?(c)}
  }
end

output_formatize = proc do |coms, cs|
  ress = cs.map do |c|
    if coms[:rejecteds].include?(c)
      msg = "Your specified time '#{c[:time_str]}' seems invalid.\n"
    else
      msg = "OK.\n"
    end
    {message: msg, connection: c[:connection]}
  end
  {commands: coms[:launcheds].map{|c| c[:command_str]}, responses: ress}
end

exec_commands = proc do |commands|
  commands.each do |command|
    puts "execute command '#{command}'"
    pid =  Process.spawn(command, :out => STDOUT, :err => STDERR)
    puts "PID = #{pid}"
  end
end

respond = proc do |responses|
  responses.each do |res|
    res[:connection].write(res[:message])
    res[:connection].close
  end
end

output_processor = proc do |out|
  exec_commands.call(out[:commands])
  respond.call(out[:responses])
end

# helper method (pure function)
def acceptable?(c)
  Time.parse(c[:time_str])
rescue
  nil
end

# Input-Signal representing new clients.
new_clients = S.async_input(5, &accepter)

# Input-Signal representing current time.
current_time = S.input(&timer)

# Foldp-Signal representing registered commands.
initial = {waitings: [], launcheds: [], rejecteds: []}
commands = S.foldp(initial, current_time, new_clients, &update_commands)

# Lift-Signal representing output datas.
main = S.lift(commands, new_clients, &output_formatize)

# FRP's main-loop.
Frypan::Reactor.new(main).loop(&output_processor)

