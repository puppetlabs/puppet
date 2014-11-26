require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:file, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Retrieve and store files in a filebucket"
  description <<-'EOT'
    This subcommand interacts with objects stored in a local or remote
    filebucket. File objects are accessed by their MD5 sum; see the
    examples for the relevant syntax.
  EOT
  notes <<-'EOT'
    To retrieve the unmunged contents of a file, you must call find with
    --render-as s. Rendering as yaml will return a hash of metadata
    about the file, including its contents.

    This subcommand does not interact with the `clientbucketdir` (the default
    local filebucket for puppet agent); it interacts with the primary
    "master"-type filebucket located in the `bucketdir`. If you wish to
    interact with puppet agent's default filebucket, you'll need to set
    the <--bucketdir> option appropriately when invoking actions.
  EOT

  file = get_action(:find)
  file.summary "Retrieve a file from the filebucket."
  file.arguments "md5/<md5sum>"
  file.returns <<-'EOT'
    The file object with the specified checksum.

    RENDERING ISSUES: Rendering as a string returns the contents of the
    file object; rendering as yaml returns a hash of metadata about said
    file, including but not limited to its contents. Rendering as json
    is currently broken, and returns a hash containing only the contents
    of the file.
  EOT
  file.examples <<-'EOT'
    Retrieve the contents of a file:

    $ puppet file find md5/9aedba7f413c97dc65895b1cd9421f2c --render-as s
  EOT

  deactivate_action(:search)
  deactivate_action(:destroy)

  set_indirection_name :file_bucket_file
end
