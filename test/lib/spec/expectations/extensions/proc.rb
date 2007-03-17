module Spec
  module Expectations
    module ProcExpectations
      # Given a receiver and a message (Symbol), specifies that the result
      # of sending that message that receiver should change after
      # executing the proc.
      #
      #   lambda { @team.add player }.should_change(@team.players, :size)
      #   lambda { @team.add player }.should_change(@team.players, :size).by(1)
      #   lambda { @team.add player }.should_change(@team.players, :size).to(23)
      #   lambda { @team.add player }.should_change(@team.players, :size).from(22).to(23)
      #
      # You can use a block instead of a message and receiver.
      #
      #   lambda { @team.add player }.should_change{@team.players.size}
      #   lambda { @team.add player }.should_change{@team.players.size}.by(1)
      #   lambda { @team.add player }.should_change{@team.players.size}.to(23)
      #   lambda { @team.add player }.should_change{@team.players.size}.from(22).to(23)
      def should_change(receiver=nil, message=nil, &block)
        should.change(receiver, message, &block)
      end
  
      # Given a receiver and a message (Symbol), specifies that the result
      # of sending that message that receiver should NOT change after
      # executing the proc.
      #
      #   lambda { @team.add player }.should_not_change(@team.players, :size)
      #
      # You can use a block instead of a message and receiver.
      #
      #   lambda { @team.add player }.should_not_change{@team.players.size}
      def should_not_change(receiver, message)
        should.not.change(receiver, message)
      end

      def should_raise(exception=Exception, message=nil)
        should.raise(exception, message)
      end
      
      def should_not_raise(exception=Exception, message=nil)
        should.not.raise(exception, message)
      end
      
      def should_throw(symbol)
        should.throw(symbol)
      end
      
      def should_not_throw(symbol=:___this_is_a_symbol_that_will_likely_never_occur___)
        should.not.throw(symbol)
      end
    end
  end
end

class Proc
  include Spec::Expectations::ProcExpectations
end