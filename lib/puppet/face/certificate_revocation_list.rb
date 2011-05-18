require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_revocation_list, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage the list of revoked certificates."
  description <<-'EOT'
    This face is primarily for retrieving the certificate revocation
    list from the CA. Although it exposes search/save/destroy methods,
    they shouldn't be used under normal circumstances.
  EOT
  notes <<-'EOT'
    This is an indirector face, which exposes `find`, `search`, `save`, and
    `destroy` actions for an indirected subsystem of Puppet. Valid termini
    for this face include:

    * `ca`
    * `file`
    * `rest`
  EOT

  get_action(:find).summary "Retrieve the certificate revocation list."
  get_action(:find).arguments "<dummy_key>"
  get_action(:find).returns <<-'EOT'
    A certificate revocation list. You will usually want to render this
    as a string ('--render-as s').
  EOT
  get_action(:find).examples <<-'EXAMPLES'
    Retrieve a copy of the puppet master's CRL:

    $ puppet certificate_revocation_list find crl --terminus rest
  EXAMPLES

  get_action(:destroy).summary "Delete the certificate revocation list."
  get_action(:destroy).arguments "<dummy_key>"
  get_action(:destroy).returns "Nothing."
  get_action(:destroy).description <<-'EOT'
    Deletes the certificate revocation list. This cannot be done over
    REST, but it is possible to both delete the locally cached copy of
    the CA's CRL and delete the CA's own copy (if running on the CA
    machine and invoked with '--terminus ca'). Needless to say, don't do
    this unless you know what you're up to.
  EOT

  get_action(:search).summary "Invalid for this face."
  get_action(:save).summary "Invalid for this face."
end
