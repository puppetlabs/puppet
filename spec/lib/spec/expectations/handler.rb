module Spec
  module Expectations
    
    module MatcherHandlerHelper
      def describe(matcher)
        matcher.respond_to?(:description) ? matcher.description : "[#{matcher.class.name} does not provide a description]"
      end
    end
    
    class ExpectationMatcherHandler
      class << self
        include MatcherHandlerHelper
        def handle_matcher(actual, matcher, &block)
          match = matcher.matches?(actual, &block)
          ::Spec::Matchers.generated_description = "should #{describe(matcher)}"
          Spec::Expectations.fail_with(matcher.failure_message) unless match
        end
      end
    end

    class NegativeExpectationMatcherHandler
      class << self
        include MatcherHandlerHelper
        def handle_matcher(actual, matcher, &block)
          unless matcher.respond_to?(:negative_failure_message)
            Spec::Expectations.fail_with(
<<-EOF
Matcher does not support should_not.
See Spec::Matchers for more information
about matchers.
EOF
)
          end
          match = matcher.matches?(actual, &block)
          ::Spec::Matchers.generated_description = "should not #{describe(matcher)}"
          Spec::Expectations.fail_with(matcher.negative_failure_message) if match
        end
      end
    end

  end
end

