module Spec
  module Mocks
    class Mock
      include Methods

      # Creates a new mock with a +name+ (that will be used in error messages only)
      # == Options:
      # * <tt>:null_object</tt> - if true, the mock object acts as a forgiving null object allowing any message to be sent to it.
      def initialize(name, options={})
        @name = name
        @options = options
      end

      def method_missing(sym, *args, &block)
        __mock_proxy.instance_eval {@messages_received << [sym, args, block]}
        begin
          return self if __mock_proxy.null_object?
          super(sym, *args, &block)
        rescue NoMethodError
          __mock_proxy.raise_unexpected_message_error sym, *args
        end
      end
      
      def inspect
        "#<#{self.class}:#{sprintf '0x%x', self.object_id} @name=#{@name.inspect}>"
      end
    end
  end
end
