require 'puppet/indirector/code'
require 'puppet/ssl/certificate'

class Puppet::SSL::Certificate::DisabledCa < Puppet::Indirector::Code
  desc "Manage SSL certificates on disk, but reject any remote access
to the SSL data store.  Used when a master has an explicitly disabled
CA to prevent clients getting confusing 'success' behaviour."

  def initialize
    @file = Puppet::SSL::Certificate.indirection.terminus(:file)
  end

  [:find, :head, :search, :save, :destroy].each do |name|
    define_method(name) do |request|
      if request.remote?
        raise Puppet::Error, "this master is not a CA"
      else
        @file.send(name, request)
      end
    end
  end
end
