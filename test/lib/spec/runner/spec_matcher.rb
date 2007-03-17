module Spec
  module Runner
    class SpecMatcher

      attr_writer :spec_desc
      def initialize(context_desc, spec_desc=nil)
        @context_desc = context_desc
        @spec_desc = spec_desc
      end
      
      def matches?(desc)
        desc =~ /(^#{context_regexp} #{spec_regexp}$|^#{context_regexp}$|^#{spec_regexp}$)/
      end
      
      private
        def context_regexp
          Regexp.escape(@context_desc)
        end
        
        def spec_regexp
          Regexp.escape(@spec_desc)
        end
    end
  end
end
