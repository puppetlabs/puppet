module Spec
  module Matchers
    
    class RespondTo #:nodoc:
      def initialize(sym)
        @sym = sym
      end
      
      def matches?(target)
        return target.respond_to?(@sym)
      end
      
      def failure_message
        "expected target to respond to #{@sym.inspect}"
      end
      
      def negative_failure_message
        "expected target not to respond to #{@sym.inspect}"
      end
      
      def description
        "respond to ##{@sym.to_s}"
      end
    end
    
    # :call-seq:
    #   should respond_to(:sym)
    #   should_not respond_to(:sym)
    #
    # Matches if the target object responds to :sym
    def respond_to(sym)
      Matchers::RespondTo.new(sym)
    end
  end
end
