require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:file, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Retrieve and store files in a filebucket"

  set_indirection_name :file_bucket_file
end
