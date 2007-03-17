module Spec
  module Expectations
    module Should # :nodoc:

      class Should < Base

        def initialize(target, expectation=nil)
          @target = target
          @be_seen = false
        end
        
        deprecated do
          #Gone for 0.9
          def not
            Not.new(@target)
          end
            
          #Gone for 0.9
          def be(expected = :___no_arg)
            @be_seen = true
            return self if (expected == :___no_arg)
            if Symbol === expected
              fail_with_message(default_message("should be", expected)) unless (@target.equal?(expected))
            else
              fail_with_message("expected #{expected}, got #{@target} (using .equal?)") unless (@target.equal?(expected))
            end
          end
        
          #Gone for 0.9
          def have(expected_number=nil)
            Have.new(@target, :exactly, expected_number)
          end

          #Gone for 0.9
          def change(receiver=nil, message=nil, &block)
            Change.new(@target, receiver, message, &block)
          end

          #Gone for 0.9
          def raise(exception=Exception, message=nil)
            begin
              @target.call
            rescue exception => e
              unless message.nil?
                if message.is_a?(Regexp)
                  e.message.should =~ message
                else
                  e.message.should == message
                end
              end
              return
            rescue => e
              fail_with_message("expected #{exception}#{message.nil? ? "" : " with #{message.inspect}"}, got #{e.inspect}")
            end
            fail_with_message("expected #{exception}#{message.nil? ? "" : " with #{message.inspect}"} but nothing was raised")
          end
  
          #Gone for 0.9
          def throw(symbol)
            begin
              catch symbol do
                @target.call
                fail_with_message("expected #{symbol.inspect} to be thrown, but nothing was thrown")
              end
            rescue NameError => e
              fail_with_message("expected #{symbol.inspect} to be thrown, got #{e.inspect}")
            end
          end
        end

        private
        def __delegate_method_missing_to_target(original_sym, actual_sym, *args)
          ::Spec::Matchers.generated_description = "should #{original_sym} #{args[0].inspect}"
          return if @target.send(actual_sym, *args)
          fail_with_message(default_message(original_sym, args[0]), args[0], @target)
        end
      end

    end
  end
end
