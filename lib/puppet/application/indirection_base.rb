require 'puppet/application/interface_base'
require 'puppet/interface'

class Puppet::Application::IndirectionBase < Puppet::Application::InterfaceBase
  option("--from TERMINUS", "-f") do |arg|
    @from = arg
  end

  attr_accessor :from, :indirection

  def main
    # Call the method associated with the provided action (e.g., 'find').
    result = interface.send(verb, name, *arguments)
    render_method = Puppet::Network::FormatHandler.format(format).render_method
    puts result.send(render_method) if result
  end

  def setup
    super

    if interface.respond_to?(:indirection)
      raise "Could not find data type #{type} for application #{self.class.name}" unless interface.indirection

      interface.set_terminus(from) if from
    end
  end
end
