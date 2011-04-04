require 'puppet/application/faces_base'

class Puppet::Application::Help < Puppet::Application::FacesBase
  def render(result)
    puts result.join("\n")
  end
end
