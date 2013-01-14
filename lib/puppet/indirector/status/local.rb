require 'puppet/indirector/status'

class Puppet::Indirector::Status::Local < Puppet::Indirector::Code

  desc "Get status locally. Only used internally."

  def find( *anything )
    model.new
  end
end
