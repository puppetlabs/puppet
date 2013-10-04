require 'puppet/application/face_base'
require 'puppet/face'

# NOTE: this is using an "old" naming convention (underscores instead of camel-case), for backwards
#  compatibility with 2.7.x.  When the old naming convention is officially and publicly deprecated,
#  this should be changed to camel-case.
class Puppet::Application::Secret_agent < Puppet::Application::FaceBase
  run_mode :agent
end
