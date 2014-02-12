require 'puppet/transaction/report'
require 'puppet/indirector/msgpack'

class Puppet::Transaction::Report::Msgpack < Puppet::Indirector::Msgpack
  desc "Store last report as a flat file, serialized using MessagePack."

  # Force report to be saved there
  def path(name,ext='.msgpack')
    Puppet[:lastrunreport]
  end
end
