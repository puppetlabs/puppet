# The parent class of all AST objects that contain other AST objects.
# Everything but the really simple objects descend from this.  It is
# important to note that Branch objects contain other AST objects only --
# if you want to contain values, use a descendant of the AST::Leaf class.
#
# @api private
class Puppet::Parser::AST::Branch < Puppet::Parser::AST
  include Enumerable
  attr_accessor :pin, :children

  def each
    @children.each { |child| yield child }
  end

  def initialize(arghash)
    super(arghash)
    @children ||= []
  end
end
