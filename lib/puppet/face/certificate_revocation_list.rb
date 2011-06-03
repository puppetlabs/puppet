require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_revocation_list, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage the list of revoked certificates."
  description <<-'EOT'
    This subcommand is primarily for retrieving the certificate revocation
    list from the CA.
  EOT

  get_action(:find).summary "Retrieve the certificate revocation list."
  get_action(:find).arguments "<dummy_key>"
  get_action(:find).returns <<-'EOT'
    A certificate revocation list. When used from the Ruby API: returns an
    OpenSSL::X509::CRL object.

    RENDERING ISSUES: this should usually be rendered as a string
    ('--render-as s').
  EOT
  get_action(:find).examples <<-'EXAMPLES'
    Retrieve a copy of the puppet master's CRL:

    $ puppet certificate_revocation_list find crl --terminus rest
  EXAMPLES

  get_action(:destroy).summary "Delete the certificate revocation list."
  get_action(:destroy).arguments "<dummy_key>"
  get_action(:destroy).returns "Nothing."
  get_action(:destroy).description <<-'EOT'
    Deletes the certificate revocation list. This cannot be done over REST, but
    it is possible to delete the locally cached copy or (if run from the CA) the
    CA's own copy of the CRL.
  EOT

  get_action(:search).summary "Invalid for this subcommand."
  get_action(:save).summary "Invalid for this subcommand."
end
