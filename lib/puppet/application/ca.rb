require 'puppet/application/face_base'
require 'puppet/ssl/oids'

class Puppet::Application::Ca < Puppet::Application::FaceBase
  run_mode :master

  def setup
    Puppet::SSL::Oids.register_puppet_oids
    super
  end
end
