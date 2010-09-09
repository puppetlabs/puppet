require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  class ResourceInstance < Branch
    # A simple container for a parameter for an object.  Consists of a
    # title and a set of parameters.
    attr_accessor :title, :parameters
  end
end
