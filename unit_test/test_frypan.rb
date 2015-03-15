$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'frypan'
require 'test/unit'

module Frypan
  module UnitTest
    class FrypanTest < Test::Unit::TestCase

      S = Frypan::Signal

      def test_const
        c = S::Const.new(:obj)
        assert_equal([:obj, :obj, :obj], Reactor.new(c).take(3))
      end

      def test_input
        a = (0..100).to_a
        i = S::Input.new{a.shift}
        assert_equal([0, 1, 2], Reactor.new(i).take(3))
      end

      def test_input_thread
        a = (0..1000).to_a
        i = S::InputThread.new(2){a.shift}
        val = Reactor.new(i).take(100).map(&:first).inject(&:+).take(10)
        assert_equal((0..9).to_a, val)
      end

      def test_lifte
        c1, c2 = S::Const.new(:c1), S::Const.new(:c2)
        l = S::Lift.new(c1, c2){|a, b| a.to_s + b.to_s}
        assert_equal(["c1c2", "c1c2"], Reactor.new(l).take(2))
      end

      def test_foldp
        c1, c2 = S::Const.new(:c1), S::Const.new(:c2)
        f = S::Foldp.new("", c1, c2){|acc, a, b| acc + a.to_s + b.to_s}
        assert_equal(["c1c2", "c1c2c1c2"], Reactor.new(f).take(2))
      end

      def test_lift_memorization
        seff = []
        l = S.lift(S.const(1), S.const(2)){|a, b| seff << a + b; a + b}
        assert_equal([3, 3, 3, 3, 3], Reactor.new(l).take(5))
        assert_equal([3], seff)
      end

      def test_foldp_memorization
        seff = []
        f = S.foldp(0, S.const(1), S.const(2)){|acc, a, b| seff << acc*a*b; acc*a*b}
        assert_equal([0, 0, 0, 0, 0], Reactor.new(f).take(5))
        assert_equal([0, 0], seff)
      end

      def test_utility
        l = S.const(0)
          .lift{|a| a + 1}
          .foldp(0){|acc, a| acc + a}
          .foldp([]){|acc, a| acc + [a]}
          .select{|a| a.even?}
          .map{|a| a * a}
        assert_equal([[], [4], [4], [4, 16], [4, 16], [4, 16, 36]], Reactor.new(l).take(6))
      end
    end
  end
end
