
module Puppet
  module DSL
    class Parser

      def initialize(scope, code)
        @scope = scope
        @code = proc do
          instance_eval code
        end
      end

      def parse!
        Context.new(@scope, @code).evaluate
      rescue
        require 'pry'
        binding.pry
      end

    end
  end
end

