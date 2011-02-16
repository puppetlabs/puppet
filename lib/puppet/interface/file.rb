require 'puppet/interface'

class Puppet::Interface::File < Puppet::Interface
  def self.indirection_name
    :file_bucket_file
  end
end
