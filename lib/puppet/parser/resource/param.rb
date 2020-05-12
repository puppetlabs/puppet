# The parameters we stick in Resources.
class Puppet::Parser::Resource::Param
  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper

  attr_accessor :name, :value, :source, :add, :ast_node

  def initialize(hash)
    set_options(hash)
    requiredopts(:name)
    @name = @name.intern
  end

  def line
    @line ||= @ast_node && @ast_node.line
  end

  def line=(lineno)
    @line = lineno
  end

  def file
    @file ||= @ast_node && @ast_node.file
  end

  def file=(filepath)
    @file = filepath
  end

  def line_to_i
    line ? Integer(line) : nil
  end

  def to_s
    "#{self.name} => #{self.value}"
  end
end
