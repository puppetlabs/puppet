require 'puppet/application/face_base'

class Puppet::Application::Module < Puppet::Application::FaceBase
  def setup
    super
    if self.render_as.name == :console
      Puppet::Util::Log.close(:console)
      Puppet::Util::Log.newdestination(:new_console)
    end
  end
end
