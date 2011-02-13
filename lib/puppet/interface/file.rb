require 'puppet/interface/indirector'

class Puppet::Interface::File < Puppet::Interface::Indirector
  def self.indirection_name
    :file_bucket_file
  end
end
