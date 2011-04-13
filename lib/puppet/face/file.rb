require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:file, '0.0.1') do
  set_indirection_name :file_bucket_file
end
