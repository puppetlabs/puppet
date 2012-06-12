
module Puppet
  module DSL
    class Parser

      def initialize(code)
        @code = proc do
          instance_eval code
        end
      end

      def parse!
        main = Context.new(:how_to_set_scope_from_here?, &@code).evaluate
        nodes = Puppet::Parser::AST::ASTArray.new :children => main
        Puppet::Parser::AST::Hostclass.new '', :code => nodes
      end

    end
  end
end

