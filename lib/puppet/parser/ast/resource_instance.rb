# A simple container for a parameter for an object.  Consists of a
# title and a set of parameters.
#
class Puppet::Parser::AST::ResourceInstance < Puppet::Parser::AST::Branch
  attr_accessor :title, :parameters
  def initialize(argshash)
    Puppet.warn_once('deprecation', 'AST::ResourceInstance', 'Use of Puppet::Parser::AST::ResourceInstance is deprecated')
    super(argshash)
  end
end
