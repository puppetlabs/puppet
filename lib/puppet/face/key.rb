require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:key, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Create, save, and remove certificate keys."
  description <<-'EOT'
    Manages certificate private keys. Keys are created for you
    automatically when certificate requests are generated with 'puppet
    certificate generate', and it should not be necessary to use this action
    directly.
  EOT
  notes <<-'EOT'
    This is an indirector face, which exposes `find`, `search`, `save`, and
    `destroy` actions for an indirected subsystem of Puppet. Valid termini
    for this face include:

    * `ca`
    * `file`
  EOT

end
