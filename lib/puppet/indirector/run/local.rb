require 'puppet/run'
require 'puppet/indirector/code'

class Puppet::Run::Local < Puppet::Indirector::Code

  desc "Trigger a Puppet run locally. Only used internally."

  def save( request )
    request.instance.run
  end
end
