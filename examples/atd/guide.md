# Let's Make Atd

To experience FRP (Functional Reactive Programming) and understand how to use this library, we make an imitation of Linux's atd(8) and at(1).

## atd(8) and at(1) on Linux

atd(8) is daemon to execute registered commands at specified time.
And at(1) is command to register command and time on atd(8).

For example, if you want to make a text-file named 'happy-new-century.txt' at '2101-01-01 00:00:00', 
you should use at(1) command as follows.

```sh
$ at '00:00 2101-01-01'
at> touch happy-new-century.txt
at> [Ctrl-D] 

```

## TCP/IP

Our imitation of atd(8) and at(1) (respectively named my_atd and my_at) talk with each other by TCP/IP.

We don't need a good comprehension of TCP/IP because we apply TCP/IP by using Ruby's standard library.

To know easy usage of Ruby's TCP/IP library, understand following server-program.
```ruby
#!/usr/bin/env ruby

require 'socket'

socket = TCPServer.new(20000)

loop do
  connection = socket.accept
  connection.write(connection.gets)
  connection.close
end

socket.close

```
This program works as just 'echo-server' which is receiving one-line-string from client and sending same string to client.

An example of client-program talking with above server-program is shown below.
```ruby
#!/usr/bin/env ruby

require 'socket'

socket = TCPSocket.open("localhost", 20000)
socket.write(STDIN.gets)
puts socket.gets
socket.close
```

## Make `my_atd.rb`

Immediately, let's make my_atd.

At first, write statements to launch tcp-server and print message.
```ruby
socket = TCPServer.new(20000)
puts "my_atd listening port: 20000..."
```

Incidentally, define a Proc to accept and get client's request.
```ruby
accepter = proc do
  connection = socket.accept
  c, t = connection.gets, connection.gets
  {command_str: c.chomp, time_str: t.chomp, connection: connection}
end
```

A Proc to get current time is too.
```ruby
timer = proc do
  Time.now
end
```

Here, use our heads a little.
What should my_atd do as output?

The answer is maybe executing command and responding to client.
So if `commands` is array of command-string and `responses` is array of
`Hash(:connection => client-socket, :message => response-string)`,
we can define Procs to execute command and to respond to client.
```ruby
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
```

And define a Proc to bind these two Procs if `out` is
`Hash(:commands => commands, :responses => responses)`.
```ruby
output_processor = proc do |out|
  exec_commands.call(out[:commands])
  respond.call(out[:responses])
end
```

By the way, there is necessity for my_atd to retain registered commands (and times.)
And we suddenly realize that we can separate registered commands into three parts:

* `waitings`:  commands waiting for execution
* `launcheds`: commands which should be executed right now
* `rejecteds`: commands which are requested to add but rejected

And then we can express each parts as Ruby's data:

* `waitings`:  `Hash(:command_str => command-string, :time => time)`
* `launcheds`: `Hash(:command_str => command-string, :time => time)`
* `rejecteds`: `Hash(:command_str => command-string, :time_str => time-string, :connection => client-socket)`

If `ct` is current time,  `cs` is Array of request which is
`Hash(command_str: command-string, :time_str => time-string, :connection => client-socket)` and
`commands` is current-state which is `Hash(:waitings, :launcheds, :rejecteds)`,
we can update `commands` to next-state by one function `update_commands` as follows:

```
next_commands = update_commands(commands, ct, cs)
```

`update_commands` can be, for example, wrote as follows:

```ruby
update_commands = proc do |commands, ct, cs|
  {
    waitings: acc[:waitings].select{|c| c[:time] > ct} +
    cs.select{|c| acceptable?(c)}.map{|c| c.update(time: Time.parse(c[:time_str]))},
    launcheds: acc[:waitings].select{|c| c[:time] <= ct},
    rejecteds: cs.reject{|c| acceptable?(c)}
  }
end

# helper
def acceptable?(c)
  Time.parse(c[:time_str])
rescue
  nil
end
```

Now, we can make a function to generate data which is `Hash(:commands => commands, :responses => responses)`.
This data is used as argument of Proc `output-processor` which we made earlier.
We can write the function as follows, where `coms` is updated commands and `cs` is Array of request.
```ruby
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
```


Phew, that was steep road. But our task has almost been completed!
So far we only define two input-proc, one output-proc, and two pure-function, but we didn't use `frypan` yet.

Do you remember `frypan`?
It's my library to do FRP.

Do you know FRP?
If you don't know, don't worry!
Experience is the best teacher :)


As finishing of all, we do FRP by using `frypan`.
```ruby
require 'frypan'

S = Frypan::Signal

# Input-Signal representing new clients.
new_clients = S.async_input(5, &accepter)

# Input-Signal representing current time.
current_time = S.input(&timer)

# Foldp-Signal representing registered commands.
initial = {waitings: [], launcheds: [], rejecteds: []}
commands = S.foldp(initial, current_time, new_clients, &update_command)

# Lift-Signal representing output datas.
main = S.lift(commands, new_clients, &output_formatize)

# FRP's main-loop.
Frypan::Reactor.new(main).loop(&output_processor)
```

All of my_atd is completed with this!

It's true!

Complete source-code of executable program (`my_atd.rb`) is here:
```ruby
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
    waitings: acc[:waitings].select{|c| c[:time] > ct} +
    cs.select{|c| acceptable?(c)}.map{|c| c.update(time: Time.parse(c[:time_str]))},
    launcheds: acc[:waitings].select{|c| c[:time] <= ct},
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
    {message: msg, connection: cl[:connection]}
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

# helper method
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
commands = S.foldp(initial, current_time, new_clients, &update_command)

# Lift-Signal representing output datas.
main = S.lift(commands, new_clients, &output_formatize)

# FRP's main-loop.
Frypan::Reactor.new(main).loop(&output_processor)
```

## Make `my_at.rb`

We need not to use `frypan` to make `my_at.rb`.
So, we make `my_at.rb` quickly by sloppy job.

Complete source-code of executable program (`my_at.rb`) is here:
```ruby
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
```

## Let's play `my_atd` and `my_at`

At first, make `my_atd.rb` and `my_at.rb` be executable.
```sh
# chmod +x ./my_atd.rb ./my_at.rb
```

And launch `my_atd` server!
```sh
$ ./my_atd.rb
my_atd listening port: 20000...
```

Open another terminal and run client program `my_at`.
```sh
$ ./mu_at.rb
execution-command> 
```

Type your wishing task!
```sh
execution-command> touch hello-at.txt
execution-time> 2015/03/15 00:00:00 JST
response: OK.
```
At "2015/03/15 00:00:00 JST", you are going to discover a file named `hello-at.txt` on your directory!

## Good job!

We have made one of practical applications by Fryapn.
Are you tired? or excited? or puzzled? ha-ha!

Frypan makes it easy to program Real-time systems such as `atd`.
In many cases, it's hard to write Real-time systems as simple Input-and-Output program.
But by Frypan, we makes structure of Real-time systems' program separate into IO-operator (Proc having side-effect) and pure-function (Proc having no side-effect).
It is one of the best way to write Real-time system as concisely as possible.

Let's leave the frustration of complex-coding behind by Frypan:)



