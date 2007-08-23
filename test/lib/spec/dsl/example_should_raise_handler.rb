module Spec
  module DSL
    class ExampleShouldRaiseHandler
      def initialize(file_and_line_number, opts)
        @file_and_line_number = file_and_line_number
        @options = opts
        @expected_error_class = determine_error_class(opts)
        @expected_error_message = determine_error_message(opts)
      end
  
      def determine_error_class(opts)
        if candidate = opts[:should_raise]
          if candidate.is_a?(Class)
            return candidate
          elsif candidate.is_a?(Array)
            return candidate[0]
          else
            return Exception
          end
        end
      end
  
      def determine_error_message(opts)
        if candidate = opts[:should_raise]
          if candidate.is_a?(Array)
            return candidate[1]
          end
        end
        return nil
      end
  
      def build_message(exception=nil)
        if @expected_error_message.nil?
          message = "example block expected #{@expected_error_class.to_s}"
        else
          message = "example block expected #{@expected_error_class.new(@expected_error_message.to_s).inspect}"
        end
        message << " but raised #{exception.inspect}" if exception
        message << " but nothing was raised" unless exception
        message << "\n"
        message << @file_and_line_number
      end
  
      def error_matches?(error)
        return false unless error.kind_of?(@expected_error_class)
        unless @expected_error_message.nil?
          if @expected_error_message.is_a?(Regexp)
            return false unless error.message =~ @expected_error_message
          else
            return false unless error.message == @expected_error_message
          end
        end
        return true
      end

      def handle(errors)
        if @expected_error_class
          if errors.empty?
            errors << Spec::Expectations::ExpectationNotMetError.new(build_message)
          else
            error_to_remove = errors.detect do |error|
              error_matches?(error)
            end
            if error_to_remove.nil?
              errors.insert(0,Spec::Expectations::ExpectationNotMetError.new(build_message(errors[0])))
            else
              errors.delete(error_to_remove)
            end
          end
        end
      end
    end
  end
end
