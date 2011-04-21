require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:file, '0.0.1') do
  summary "Retrieve and store files in a filebucket"

  set_indirection_name :file_bucket_file
end
