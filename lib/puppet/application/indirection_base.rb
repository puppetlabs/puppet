require 'puppet/application/interface_base'

class Puppet::Application::IndirectionBase < Puppet::Application::InterfaceBase
  option("--terminus TERMINUS") do |arg|
    @terminus = arg
  end

  attr_accessor :terminus, :indirection

  def setup
    super

    if interface.respond_to?(:indirection)
      raise "Could not find data type #{type} for application #{self.class.name}" unless interface.indirection

      interface.set_terminus(terminus) if terminus
    end
  end
end
