require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_revocation_list, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage the list of revoked certificates."
  description <<-EOT
    This face is primarily for retrieving the certificate revocation
    list from the CA. Although it exposes search/save/destroy methods,
    they shouldn't be used under normal circumstances.
  EOT
  notes <<-EOT
    Although the find action must be given an argument, this argument is
    never read, and can contain the descriptive text of your choice.

    This is an indirector face, which exposes find, search, save, and
    destroy actions for an indirected subsystem of Puppet. Valid terminuses
    for this face include:

    * `ca`
    * `file`
    * `rest`
  EOT
  examples <<-EXAMPLES
    Retrieve the CRL:

        puppet certificate_revocation_list find crl
  EXAMPLES
end
