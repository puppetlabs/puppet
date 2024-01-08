# frozen_string_literal: true

require_relative '../../../puppet/transaction/report'
require_relative '../../../puppet/indirector/msgpack'

class Puppet::Transaction::Report::Msgpack < Puppet::Indirector::Msgpack
  desc "Store last report as a flat file, serialized using MessagePack."

  # Force report to be saved there
  def path(name, ext = '.msgpack')
    Puppet[:lastrunreport]
  end
end
