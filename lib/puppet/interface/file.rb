require 'puppet/interface/indirector'

Puppet::Interface::Indirector.interface(:file) do
  set_indirection_name :file_bucket_file
end
