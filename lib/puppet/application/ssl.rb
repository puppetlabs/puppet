require 'puppet/application/face_base'

class Puppet::Application::Ssl < Puppet::Application::FaceBase
  def app_defaults
    super.merge({
      :catalog_terminus => :rest,
      :catalog_cache_terminus => :json,
      :node_terminus => :rest,
      :facts_terminus => :facter,
    })
  end

  def setup
    super
    Puppet::SSL::Host.ca_location = :none
    Puppet.settings.preferred_run_mode = "agent"
    Puppet.settings.use(:ssl)
  end
end
