require 'puppet/interface/indirector'

class Puppet::Interface::Indirector.new(:file) do
  set_indirection_name :file_bucket_file
end
