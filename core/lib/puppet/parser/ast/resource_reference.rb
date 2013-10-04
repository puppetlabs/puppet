require 'puppet/parser/ast'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST::ResourceReference < Puppet::Parser::AST::Branch
  attr_accessor :title, :type

  # Evaluate our object, but just return a simple array of the type
  # and name.
  def evaluate(scope)
    titles = Array(title.safeevaluate(scope)).flatten

    a_type, titles = scope.resolve_type_and_titles(type, titles)

    resources = titles.collect{ |a_title|
      Puppet::Resource.new(a_type, a_title)
    }

    return(resources.length == 1 ? resources.pop : resources)
  end

  def to_s
    if title.is_a?(Puppet::Parser::AST::ASTArray)
      "#{type.to_s.capitalize}#{title}"
    else
      "#{type.to_s.capitalize}[#{title}]"
    end
  end
end
