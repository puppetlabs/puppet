require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_revocation_list, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage the list of revoked certificates."
  description <<-EOT
    This subcommand is primarily for retrieving the certificate revocation
    list from the CA.
  EOT

  find = get_action(:find)
  find.summary "Retrieve the certificate revocation list."
  find.render_as = :s
  find.returns <<-EOT
    The certificate revocation list. When used from the Ruby API: returns an
    OpenSSL::X509::CRL object.
  EOT
  find.short_description <<-EOT
    Retrieves the certificate revocation list.
  EOT
  find.notes <<-EOT
    Although this action always returns the CRL from the specified terminus.
  EOT
  find.examples <<-EXAMPLES
    Retrieve a copy of the puppet master's CRL:

    $ puppet certificate_revocation_list find --terminus rest
  EXAMPLES

  destroy = get_action(:destroy)
  destroy.summary "Delete the certificate revocation list."
  destroy.arguments "<dummy_text>"
  destroy.returns "Nothing."
  destroy.description <<-EOT
    Deletes the certificate revocation list. This cannot be done over REST, but
    it is possible to delete the locally cached copy or the local CA's copy of
    the CRL.
  EOT
  destroy.short_description <<-EOT
    Deletes the certificate revocation list. This cannot be done over REST, but
    it is possible to delete the locally cached copy or the local CA's copy of
    the CRL. Due to a known bug, this action requires a dummy argument, the
    content of which is irrelevant.
  EOT
  destroy.notes <<-EOT
    Although this action always deletes the CRL from the specified terminus, it
    requires a dummy argument; this is a known bug.
  EOT

  deactivate_action(:search)
  deactivate_action(:save)
end
