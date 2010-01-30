require 'puppet/parser/ast'
require 'puppet/parser/ast/branch'
require 'puppet/resource'

class Puppet::Parser::AST::ResourceReference < Puppet::Parser::AST::Branch
    attr_accessor :title, :type

    # Evaluate our object, but just return a simple array of the type
    # and name.
    def evaluate(scope)
        titles = Array(title.safeevaluate(scope)).collect { |t| Puppet::Resource.new(type, t, :namespaces => scope.namespaces) }
        return titles.pop if titles.length == 1
        return titles
    end

    def to_s
        if title.is_a?(Puppet::Parser::AST::ASTArray)
            "#{type.to_s.capitalize}#{title}"
        else
            "#{type.to_s.capitalize}[#{title}]"
        end
    end
end
