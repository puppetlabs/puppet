require 'puppet/application/face_base'
require 'puppet/face'

class Puppet::Application::Secret_agent < Puppet::Application::FaceBase
  run_mode :agent
end
