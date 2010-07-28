require 'puppet/parser/ast'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST::ResourceReference < Puppet::Parser::AST::Branch
  attr_accessor :title, :type

  # Evaluate our object, but just return a simple array of the type
  # and name.
  def evaluate(scope)
    a_type = type
    titles = Array(title.safeevaluate(scope))

    case type.downcase
    when "class"
      # resolve the titles
      titles = titles.collect do |a_title|
        hostclass = scope.find_hostclass(a_title)
        hostclass ?  hostclass.name : a_title
      end
    when "node"
      # no-op
    else
      # resolve the type
      resource_type = scope.find_resource_type(type)
      a_type = resource_type.name if resource_type
    end

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
