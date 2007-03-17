module Spec
  module Mocks
    module Methods
      def should_receive(sym, opts={}, &block)
        __mock_handler.add_message_expectation(opts[:expected_from] || caller(1)[0], sym, opts, &block)
      end

      def should_not_receive(sym, &block)
        __mock_handler.add_negative_message_expectation(caller(1)[0], sym, &block)
      end
      
      def stub!(sym)
        __mock_handler.add_stub(caller(1)[0], sym)
      end
      
      def received_message?(sym, *args, &block) #:nodoc:
        __mock_handler.received_message?(sym, *args, &block)
      end
      
      def __verify #:nodoc:
        __mock_handler.verify
      end

      def __reset_mock #:nodoc:
        __mock_handler.reset
      end

      def method_missing(sym, *args, &block) #:nodoc:
        __mock_handler.instance_eval {@messages_received << [sym, args, block]}
        super(sym, *args, &block)
      end
      
      private

      def __mock_handler
        @mock_handler ||= MockHandler.new(self, @name, @options)
      end
    end
  end
end