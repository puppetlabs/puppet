require 'puppet/application/faces_base'

class Puppet::Application::Help < Puppet::Application::FacesBase
  def render(result)
    result.join("\n")
  end
end
