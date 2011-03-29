require 'puppet/application/string_base'

class Puppet::Application::IndirectionBase < Puppet::Application::StringBase
  attr_accessor :terminus, :indirection

  def setup
    super

    # REVISIT: need to implement this in terms of the string options, eh.
    if string.respond_to?(:indirection)
      raise "Could not find data type #{type} for application #{self.class.name}" unless string.indirection

      string.set_terminus(terminus) if terminus
    end
  end
end
