module Spec
  module Expectations
    module Should
      
      class Not < Base #:nodoc:
        def initialize(target)
          @target = target
          @be_seen = false
        end

        deprecated do
          #Gone for 0.9
          def be(expected = :___no_arg)
            @be_seen = true
            return self if (expected == :___no_arg)
            fail_with_message(default_message("should not be", expected)) if (@target.equal?(expected))
          end

          #Gone for 0.9
          def have(expected_number=nil)
            NotHave.new(@target, :exactly, expected_number)
          end

          #Gone for 0.9
          def change(receiver, message)
            NotChange.new(@target, receiver, message)
          end
  
          #Gone for 0.9
          def raise(exception=Exception, message=nil)
            begin
              @target.call
            rescue exception => e
              return unless message.nil? || e.message == message || (message.is_a?(Regexp) && e.message =~ message)
              if e.kind_of?(exception)
                failure_message = "expected no "
                failure_message << exception.to_s
                unless message.nil?
                  failure_message << " with "
                  failure_message << "message matching " if message.is_a?(Regexp)
                  failure_message << message.inspect
                end
                failure_message << ", got " << e.inspect
                fail_with_message(failure_message)
              end
            rescue
              true
            end
          end
    
          #Gone for 0.9
          def throw(symbol=:___this_is_a_symbol_that_will_likely_never_occur___)
            begin
              catch symbol do
                @target.call
                return true
              end
              fail_with_message("expected #{symbol.inspect} not to be thrown, but it was")
            rescue NameError
              true
            end
          end

          def __delegate_method_missing_to_target original_sym, actual_sym, *args
            ::Spec::Matchers.generated_description = "should not #{original_sym} #{args[0].inspect}"
            return unless @target.__send__(actual_sym, *args)
            fail_with_message(default_message("not #{original_sym}", args[0]))
          end
        end
      end

    end
  end
end
