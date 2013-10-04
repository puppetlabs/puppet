require 'puppet/indirector/status'

class Puppet::Indirector::Status::Local < Puppet::Indirector::Code

  desc "Get status locally. Only used internally."

  def find( *anything )
    status = model.new
    status.version= Puppet.version
    status
  end
end
