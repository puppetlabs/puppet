require 'puppet/indirector/status'

class Puppet::Indirector::Status::Local < Puppet::Indirector::Code
  def find( *anything )
    model.new
  end
end
