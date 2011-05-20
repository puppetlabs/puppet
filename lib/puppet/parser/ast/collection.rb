require 'puppet'
require 'puppet/parser/ast/branch'
require 'puppet/parser/collector'

# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::AST
  class Collection < AST::Branch
    attr_accessor :type, :query, :form
    attr_reader :override

    associates_doc

    # We return an object that does a late-binding evaluation.
    def evaluate(scope)
      str, code = query && query.safeevaluate(scope)

      resource_type = scope.find_resource_type(@type)
      fail "Resource type #{@type} doesn't exist" unless resource_type
      newcoll = Puppet::Parser::Collector.new(scope, resource_type.name, str, code, self.form)

      scope.compiler.add_collection(newcoll)

      # overrides if any
      # Evaluate all of the specified params.
      if @override
        params = @override.collect { |param| param.safeevaluate(scope) }
        newcoll.add_override(
          :parameters => params,
          :file       => @file,
          :line       => @line,
          :source     => scope.source,
          :scope      => scope
        )
      end

      newcoll
    end

    # Handle our parameter ourselves
    def override=(override)
      @override = if override.is_a?(AST::ASTArray)
        override
      else
        AST::ASTArray.new(:line => override.line,:file => override.file,:children => [override])
      end
    end
  end
end
