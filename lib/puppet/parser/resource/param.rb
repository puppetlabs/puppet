require 'puppet/parser/yaml_trimmer'

# The parameters we stick in Resources.
class Puppet::Parser::Resource::Param
  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper
  include Puppet::Parser::YamlTrimmer

  attr_accessor :name, :value, :source, :add, :file, :line

  def initialize(hash)
    set_options(hash)
    requiredopts(:name)
    @name = @name.intern
  end

  def line_to_i
    line ? Integer(line) : nil
  end

  def to_s
    "#{self.name} => #{self.value}"
  end
end
