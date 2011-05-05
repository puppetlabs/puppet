require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:file, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Retrieve and store files in a filebucket"
  # TK this needs a description of how to find files in a filebucket, and
  # some good use cases for retrieving/storing them. I can't write either
  # of these yet.
  notes <<-EOT
    This is an indirector face, which exposes find, search, save, and
    destroy actions for an indirected subsystem of Puppet. Valid terminuses
    for this face include:

    * `file`
    * `rest`
  EOT

  set_indirection_name :file_bucket_file
end
