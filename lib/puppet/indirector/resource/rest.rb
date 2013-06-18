require 'puppet/indirector/status'
require 'puppet/indirector/rest'

class Puppet::Resource::Rest < Puppet::Indirector::REST

  private

  def deserialize_save(content_type, body)
    # Body is [ral_res.to_resource, transaction.report]
    format = Puppet::Network::FormatHandler.protected_format(content_type)
    ary = format.intern(Array, body)
    [Puppet::Resource.from_pson(ary[0]), Puppet::Transaction::Report.from_pson(ary[1])]
  end
end
