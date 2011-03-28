require 'puppet/string/indirector'

Puppet::String::Indirector.define(:file, '0.0.1') do
  set_indirection_name :file_bucket_file
end
