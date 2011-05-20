require 'puppet/application/face_base'

class Puppet::Application::Help < Puppet::Application::FaceBase
  # Meh.  Disable the default behaviour, which is to inspect the
  # string and return that – not so helpful. --daniel 2011-04-11
  def render(result) result end
end
