
module Puppet
  module DSL
    class Parser

      @@frames = []

      def initialize(main, code)
        @main = main
        @code = proc do
          instance_eval code
        end
      end

      def evaluate
        @main.ruby_code = Context.new(@code)
      end

      def self.top_scope
        @@frames.first
      end

      def self.current_scope
        @@frames.last
      end

      def self.add_scope(scope)
        @@frames.push scope
      end

      def self.remove_scope
        @@frames.pop
      end

      def self.valid_nesting?
        Parser.top_scope == Parser.current_scope
      end

    end
  end
end

