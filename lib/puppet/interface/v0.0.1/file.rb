require 'puppet/interface/indirector'

Puppet::Interface::Indirector.interface(:file, '0.0.1') do
  set_indirection_name :file_bucket_file
end
