require 'puppet/interface/indirector'

Puppet::Interface::Indirector.define(:file, '0.0.1') do
  set_indirection_name :file_bucket_file
end
