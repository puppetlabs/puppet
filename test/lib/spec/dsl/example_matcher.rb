module Spec
  module DSL
    class ExampleMatcher

      attr_writer :example_desc
      def initialize(behaviour_desc, example_desc=nil)
        @behaviour_desc = behaviour_desc
        @example_desc = example_desc
      end
      
      def matches?(specified_examples)
        specified_examples.each do |specified_example|
          return true if matches_literal_example?(specified_example) || matches_example_not_considering_modules?(specified_example)
        end
        false
      end
      
      private
        def matches_literal_example?(specified_example)
          specified_example =~ /(^#{context_regexp} #{example_regexp}$|^#{context_regexp}$|^#{example_regexp}$)/
        end

        def matches_example_not_considering_modules?(specified_example)
          specified_example =~ /(^#{context_regexp_not_considering_modules} #{example_regexp}$|^#{context_regexp_not_considering_modules}$|^#{example_regexp}$)/
        end

        def context_regexp
          Regexp.escape(@behaviour_desc)
        end

        def context_regexp_not_considering_modules
          Regexp.escape(@behaviour_desc.split('::').last)
        end
        
        def example_regexp
          Regexp.escape(@example_desc)
        end
    end
  end
end
