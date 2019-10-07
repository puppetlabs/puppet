# The parameters we stick in Resources.
class Puppet::Parser::Resource::Param
  include Puppet::Util
  include Puppet::Util::Errors

  attr_accessor :name, :value, :source, :add, :file, :line

  def initialize(name: nil, value: nil, source: nil, line: nil, file: nil, add: nil)
    @value = value
    @source = source
    @line = line
    @file = file
    @add = add

    unless name
      # This must happen after file and line are set to have them reported in the error
      self.fail(Puppet::ResourceError, "'name' is a required option for #{self.class}")
    end
    @name = name.intern
  end

  def line_to_i
    line ? Integer(line) : nil
  end

  def to_s
    "#{self.name} => #{self.value}"
  end
end
