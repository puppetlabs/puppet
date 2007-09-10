module Spec
  module Mocks
    class Proxy
      DEFAULT_OPTIONS = {
        :null_object => false,
      }

      def initialize(target, name, options={})
        @target = target
        @name = name
        @error_generator = ErrorGenerator.new target, name
        @expectation_ordering = OrderGroup.new @error_generator
        @expectations = []
        @messages_received = []
        @stubs = []
        @proxied_methods = []
        @options = options ? DEFAULT_OPTIONS.dup.merge(options) : DEFAULT_OPTIONS
      end

      def null_object?
        @options[:null_object]
      end

      def add_message_expectation(expected_from, sym, opts={}, &block)
        __add sym, block
        @expectations << MessageExpectation.new(@error_generator, @expectation_ordering, expected_from, sym, block_given? ? block : nil, 1, opts)
        @expectations.last
      end

      def add_negative_message_expectation(expected_from, sym, &block)
        __add sym, block
        @expectations << NegativeMessageExpectation.new(@error_generator, @expectation_ordering, expected_from, sym, block_given? ? block : nil)
        @expectations.last
      end

      def add_stub(expected_from, sym)
        __add sym, nil
        @stubs.unshift MethodStub.new(@error_generator, @expectation_ordering, expected_from, sym, nil)
        @stubs.first
      end

      def verify #:nodoc:
        begin
          verify_expectations
        ensure
          reset
        end
      end

      def reset
        clear_expectations
        clear_stubs
        reset_proxied_methods
        clear_proxied_methods
      end

      def received_message?(sym, *args, &block)
        return true if @messages_received.find {|array| array == [sym, args, block]}
        return false
      end

      def has_negative_expectation?(sym)
        @expectations.detect {|expectation| expectation.negative_expectation_for?(sym)}
      end

      def message_received(sym, *args, &block)
        if expectation = find_matching_expectation(sym, *args)
          expectation.invoke(args, block)
        elsif stub = find_matching_method_stub(sym)
          stub.invoke([], block)
        elsif expectation = find_almost_matching_expectation(sym, *args)
          raise_unexpected_message_args_error(expectation, *args) unless has_negative_expectation?(sym) unless null_object?
        else
          @target.send :method_missing, sym, *args, &block
        end
      end

      def raise_unexpected_message_args_error(expectation, *args)
        @error_generator.raise_unexpected_message_args_error expectation, *args
      end

      def raise_unexpected_message_error(sym, *args)
        @error_generator.raise_unexpected_message_error sym, *args
      end
      
    private

      def __add(sym, block)
        $rspec_mocks.add(@target) unless $rspec_mocks.nil?
        define_expected_method(sym)
      end
      
      def define_expected_method(sym)
        if target_responds_to?(sym) && !@proxied_methods.include?(sym)
          metaclass.__send__(:alias_method, munge(sym), sym) if metaclass.instance_methods.include?(sym.to_s)
          @proxied_methods << sym
        end
        
        metaclass_eval(<<-EOF, __FILE__, __LINE__)
          def #{sym}(*args, &block)
            __mock_proxy.message_received :#{sym}, *args, &block
          end
        EOF
      end

      def target_responds_to?(sym)
        return @target.send(munge(:respond_to?),sym) if @already_proxied_respond_to
        return @already_proxied_respond_to = true if sym == :respond_to?
        return @target.respond_to?(sym)
      end

      def munge(sym)
        "proxied_by_rspec__#{sym.to_s}".to_sym
      end

      def clear_expectations
        @expectations.clear
      end

      def clear_stubs
        @stubs.clear
      end

      def clear_proxied_methods
        @proxied_methods.clear
      end

      def metaclass_eval(str, filename, lineno)
        metaclass.class_eval(str, filename, lineno)
      end
      
      def metaclass
        (class << @target; self; end)
      end

      def verify_expectations
        @expectations.each do |expectation|
          expectation.verify_messages_received
        end
      end

      def reset_proxied_methods
        @proxied_methods.each do |sym|
          if metaclass.instance_methods.include?(munge(sym).to_s)
            metaclass.__send__(:alias_method, sym, munge(sym))
            metaclass.__send__(:undef_method, munge(sym))
          else
            metaclass.__send__(:undef_method, sym)
          end
        end
      end

      def find_matching_expectation(sym, *args)
        @expectations.find {|expectation| expectation.matches(sym, args)}
      end

      def find_almost_matching_expectation(sym, *args)
        @expectations.find {|expectation| expectation.matches_name_but_not_args(sym, args)}
      end

      def find_matching_method_stub(sym)
        @stubs.find {|stub| stub.matches(sym, [])}
      end

    end
  end
end
