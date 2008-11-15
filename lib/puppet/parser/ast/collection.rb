require 'puppet'
require 'puppet/parser/ast/branch'
require 'puppet/parser/collector'

# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::AST
class Collection < AST::Branch
    attr_accessor :type, :query, :form

    associates_doc

    # We return an object that does a late-binding evaluation.
    def evaluate(scope)
        if self.query
            str, code = self.query.safeevaluate scope
        else
            str = code = nil
        end

        newcoll = Puppet::Parser::Collector.new(scope, @type, str, code, self.form)

        scope.compiler.add_collection(newcoll)

        newcoll
    end
end
end
