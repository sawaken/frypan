require "frypan/version"

module Frypan

  # Reactor : Object to calculate (Signal -> Value)
  # ----------------------------------------

  class Reactor
    include Enumerable

    def initialize(signal, init_memos=[{}, {}])
      @signal = signal
      @init_memos = init_memos
    end

    def loop(&block)
      memos = @init_memos
      while true
        last_memo = @signal.__pull({}, *memos)
        memos = [last_memo, memos[0]]
        block.call(last_memo[@signal])
      end
    end
    
    def each(&block)
      loop(&block)
    end
  end

  # Signal : Abstraction of time-varing value
  # ----------------------------------------

  class Signal

    # Utility Class methods (public to library-user)
    # ----------------------------------------

    def self.const(val)
      Const.new(val)
    end

    def self.input(&proc)
      Input.new(&proc)
    end

    def self.async_input(buf_size=1, &proc)
      InputThread.new(buf_size, &proc)[0]
    end

    def self.lift(*arg_signals, &proc)
      Lift.new(*arg_signals, &proc)
    end

    def self.foldp(init_state, *arg_signals, &proc)
      Foldp.new(init_state, *arg_signals, &proc)
    end

    # Utility Instance methods (public to library-user)
    # ----------------------------------------

    def method_missing(name, *args, &proc)
      Lift.new(self){|a| a.send(name, *args, &proc)}
    end

    def lift(&proc)
      Lift.new(self, &proc)
    end

    def foldp(init_state, &proc)
      Foldp.new(init_state, self, &proc)
    end

    # Implementation of each Signals (library-user need not understand)
    # ----------------------------------------

    def __pull(memo0, memo1, memo2)
      if memo0.has_key?(self)
        memo0
      else
        __calc(__pull_deps(memo0, memo1, memo2), memo1, memo2)
      end
    end

    def __pull_deps(memo0, memo1, memo2)
      memo0
    end

    def __same(memo_a, memo_b)
      memo_a.has_key?(self) && memo_b.has_key?(self) && memo_a[self] == memo_b[self]
    end

    class Const < Signal
      def initialize(val)
        @val = val
      end

      def __calc(memo0, memo1, memo2)
        memo0.merge(self => @val)
      end
    end

    class Input < Signal
      def initialize(&proc)
        @input_proc = proc
      end

      def __calc(memo0, memo1, memo2)
        memo0.merge(self => @input_proc.call)
      end
    end

    class InputThread < Signal
      def initialize(buf_size=1, &proc)
        @buf_size = buf_size
        @proc = proc
      end

      def atom(thread, &block)
        thread[:mutex].synchronize(&block)
      end

      def make_thread
        thread = ::Thread.new(@proc) do |proc| 
          sleep
          while true
            input = proc.call
            size = atom(Thread.current){
              Thread.current[:inputs] << input
              Thread.current[:inputs].size
            }
            sleep if size >= @buf_size
          end
        end
        thread[:mutex] = Mutex.new
        thread[:inputs] = []
        thread.run
        return thread
      end

      def get_inputs(thread)
        atom(thread){
          inputs = thread[:inputs]
          thread[:inputs] = []
          return inputs
        }
      end

      def __calc(memo0, memo1, memo2)
        unless memo1.has_key?(self)
          memo0.merge(self => [[], make_thread])
        else
          inputs = get_inputs(memo1[self][1])
          memo1[self][1].run
          return memo0.merge(self => [inputs, memo1[self][1]])
        end
      end
    end

    class Lift < Signal
      def initialize(*arg_signals, &proc)
        @arg_signals, @proc = arg_signals, proc
      end

      def __pull_deps(memo0, memo1, memo2)
        @arg_signals.inject(memo0){|acc, sig| sig.__pull(acc, memo1, memo2)}
      end

      def __calc(memo0, memo1, memo2)
        if @arg_signals.all?{|sig| sig.__same(memo0, memo1)}
          memo0.merge(self => memo1[self])
        else
          memo0.merge(self => @proc.call(*@arg_signals.map{|sig| memo0[sig]}))
        end
      end
    end
    
    class Foldp < Signal
      def initialize(init_state, *arg_signals, &proc)
        @init_state, @arg_signals, @proc = init_state, arg_signals, proc
      end

      def __pull_deps(memo0, memo1, memo2)
        @arg_signals.inject(memo0){|acc, sig| sig.__pull(acc, memo1, memo2)}
      end

      def __calc(memo0, memo1, memo2)
        if __same(memo1, memo2) && @arg_signals.all?{|sig| sig.__same(memo0, memo1)}
          memo0.merge(self => memo1[self])
        else
          state = memo1.has_key?(self) ? memo1[self] : @init_state
          memo0.merge(self => @proc.call(state, *@arg_signals.map{|sig| memo0[sig]}))
        end
      end
    end
  end
end
