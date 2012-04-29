require 'puppet/application/face_base'
require 'puppet/face'

class Puppet::Application::SecretAgent < Puppet::Application::FaceBase
  run_mode :agent
end
