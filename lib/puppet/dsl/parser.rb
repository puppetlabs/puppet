
module Puppet
  module DSL
    class Parser

      def initialize(main, code)
        @main = main
        @code = proc do
          instance_eval code
        end
      end

      def parse!
        @main.ruby_code = Context.new(@code)
      end

    end
  end
end

