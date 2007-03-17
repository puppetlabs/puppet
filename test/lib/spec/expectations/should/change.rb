module Spec
  module Expectations
    module Should
      class Change < Base

        def initialize(target, receiver=nil, message=nil, &block)
          @block = block
          @target = target
          @receiver = receiver
          @message = message
          execute_change
          evaluate_change
        end

        def execute_change
          @before_change = @block.nil? ? @receiver.send(@message) : @block.call
          @target.call
          @after_change = @block.nil? ? @receiver.send(@message) : @block.call
        end
        
        def message
          @message.nil? ? 'result' : @message
        end

        def evaluate_change
          if @before_change == @after_change
            fail_with_message "#{message} should have changed, but is still #{@after_change.inspect}"
          end
        end

        def from(value)
          if @before_change != value
            fail_with_message "#{message} should have initially been #{value.inspect}, but was #{@before_change.inspect}"
          end
          self
        end

        def to(value)
          if @after_change != value
            fail_with_message "#{message} should have been changed to #{value.inspect}, but is now #{@after_change.inspect}"
          end
          self
        end

        def by(expected_delta)
          if actual_delta != expected_delta
            fail_with_message "#{message} should have been changed by #{expected_delta}, but was changed by #{actual_delta}"
          end
          self
        end
        
        private
          def actual_delta
            @after_change - @before_change
          end
      end
      
      class NotChange < Change
        def evaluate_change
          if @before_change != @after_change
            fail_with_message "#{@message} should not have changed, but did change from #{@before_change.inspect} to #{@after_change.inspect}"
          end
        end
      end

    end
  end
end

