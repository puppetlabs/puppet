# The parameters we stick in Resources.
class Puppet::Parser::Resource::Param
  include Puppet::Util
  include Puppet::Util::Errors

  attr_accessor :name, :value, :source, :add, :file, :line

  def initialize(hash)
    @value = hash.delete(:value)
    @source = hash.delete(:source)
    @line = hash.delete(:line)
    @file = hash.delete(:file)
    @add = hash.delete(:add)

    unless hash[:name]
      # This must happen after file and line are set to have them reported in the error
      self.fail(Puppet::ResourceError, "'name' is a required option for #{self.class}")
    end
    @name = hash.delete(:name).intern

    raise ArgumentError, "Unknown hash arguments #{hash}" unless hash.empty?
  end

  def line_to_i
    line ? Integer(line) : nil
  end

  def to_s
    "#{self.name} => #{self.value}"
  end
end
