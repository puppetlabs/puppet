require 'puppet/indirector/status'
require 'puppet/indirector/rest'

# @deprecated
class Puppet::Resource::Rest < Puppet::Indirector::REST

  desc "Maniuplate resources remotely? Undocumented."

  private

  def deserialize_save(content_type, body)
    # Body is [ral_res.to_resource, transaction.report]
    format = Puppet::Network::FormatHandler.format_for(content_type)
    ary = format.intern(Array, body)
    [Puppet::Resource.from_data_hash(ary[0]), Puppet::Transaction::Report.from_data_hash(ary[1])]
  end
end
