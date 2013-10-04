require 'puppet/indirector/status'
require 'puppet/indirector/rest'

class Puppet::Indirector::Status::Rest < Puppet::Indirector::REST

  desc "Get puppet master's status via REST. Useful because it tests the health
    of both the web server and the indirector."

end
