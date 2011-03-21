require 'puppet/application/interface_base'
require 'puppet/interface'

class Puppet::Application::IndirectionBase < Puppet::Application::InterfaceBase
  option("--terminus TERMINUS") do |arg|
    @from = arg
  end

  attr_accessor :from, :indirection

  def setup
    super

    if interface.respond_to?(:indirection)
      raise "Could not find data type #{type} for application #{self.class.name}" unless interface.indirection

      interface.set_terminus(from) if from
    end
  end
end
