module Spec
  module Matchers

    class Include #:nodoc:
      
      def initialize(expected)
        @expected = expected
      end
      
      def matches?(actual)
        @actual = actual
        actual.include?(@expected)
      end
      
      def failure_message
        _message
      end
      
      def negative_failure_message
        _message("not ")
      end
      
      def description
        "include #{@expected.inspect}"
      end
      
      private
        def _message(maybe_not="")
          "expected #{@actual.inspect} #{maybe_not}to include #{@expected.inspect}"
        end
    end

    # :call-seq:
    #   should include(expected)
    #   should_not include(expected)
    #
    # Passes if actual includes expected. This works for
    # collections and Strings
    #
    # == Examples
    #
    #   [1,2,3].should include(3)
    #   [1,2,3].should_not include(4)
    #   "spread".should include("read")
    #   "spread".should_not include("red")
    def include(expected)
      Matchers::Include.new(expected)
    end
  end
end
