module Spec
  module Matchers
    
    class RaiseError #:nodoc:
      def initialize(exception=Exception, message=nil)
        @expected_error = exception
        @expected_message = message
      end
      
      def matches?(proc)
        @raised_expected_error = false
        @raised_other = false
        begin
          proc.call
        rescue @expected_error => @actual_error
          if @expected_message.nil?
            @raised_expected_error = true
          else
            case @expected_message
            when Regexp
              if @expected_message =~ @actual_error.message
                @raised_expected_error = true
              else
                @raised_other = true
              end
            else
              if @actual_error.message == @expected_message
                @raised_expected_error = true
              else
                @raised_other = true
              end
            end
          end
        rescue => @actual_error
          @raised_other = true
        ensure
          return @raised_expected_error
        end
      end
      
      def failure_message
        return "expected #{expected_error}#{actual_error}" if @raised_other || !@raised_expected_error
      end

      def negative_failure_message
        "expected no #{expected_error}#{actual_error}"
      end
      
      def description
        "raise #{expected_error}"
      end
      
      private
        def expected_error
          case @expected_message
          when nil
            @expected_error
          when Regexp
            "#{@expected_error} with message matching #{@expected_message.inspect}"
          else
            "#{@expected_error} with #{@expected_message.inspect}"
          end
        end

        def actual_error
          @actual_error.nil? ? " but nothing was raised" : ", got #{@actual_error.inspect}"
        end
    end
    
    # :call-seq:
    #   should raise_error()
    #   should raise_error(NamedError)
    #   should raise_error(NamedError, String)
    #   should raise_error(NamedError, Regexp)
    #   should_not raise_error()
    #   should_not raise_error(NamedError)
    #   should_not raise_error(NamedError, String)
    #   should_not raise_error(NamedError, Regexp)
    #
    # With no args, matches if any error is raised.
    # With a named error, matches only if that specific error is raised.
    # With a named error and messsage specified as a String, matches only if both match.
    # With a named error and messsage specified as a Regexp, matches only if both match.
    #
    # == Examples
    #
    #   lambda { do_something_risky }.should raise_error
    #   lambda { do_something_risky }.should raise_error(PoorRiskDecisionError)
    #   lambda { do_something_risky }.should raise_error(PoorRiskDecisionError, "that was too risky")
    #   lambda { do_something_risky }.should raise_error(PoorRiskDecisionError, /oo ri/)
    #
    #   lambda { do_something_risky }.should_not raise_error
    #   lambda { do_something_risky }.should_not raise_error(PoorRiskDecisionError)
    #   lambda { do_something_risky }.should_not raise_error(PoorRiskDecisionError, "that was too risky")
    #   lambda { do_something_risky }.should_not raise_error(PoorRiskDecisionError, /oo ri/)
    def raise_error(error=Exception, message=nil)
      Matchers::RaiseError.new(error, message)
    end
  end
end
