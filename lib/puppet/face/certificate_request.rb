require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_request, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage certificate requests."
  description <<-'EOT'
    This subcommand retrieves and submits certificate signing requests (CSRs).
  EOT

  # Per-action doc overrides
  get_action(:destroy).summary "Invalid for this subcommand."

  get_action(:find).summary "Retrieve a single CSR."
  get_action(:find).arguments "<host>"
  get_action(:find).returns <<-'EOT'
    A single certificate request. When used from the Ruby API, returns a
    Puppet::SSL::CertificateRequest object.

    RENDERING ISSUES: In most cases, you will want to render this as a string
    ('--render-as s').
  EOT
  get_action(:find).examples <<-'EOT'
    Retrieve a single CSR from the puppet master's CA:

    $ puppet certificate_request find somenode.puppetlabs.lan --terminus rest
  EOT

  get_action(:search).summary "Retrieve all outstanding CSRs."
  get_action(:search).arguments "<dummy_key>"
  get_action(:search).returns <<-'EOT'
    A list of certificate requests; be sure to to render this as a string
    ('--render-as s'). When used from the Ruby API, returns an array of
    Puppet::SSL::CertificateRequest objects.
  EOT
  get_action(:search).notes "This action always returns all CSRs, but requires a dummy search key."
  get_action(:search).examples <<-'EOT'
    Retrieve all CSRs from the local CA (similar to 'puppet cert list'):

    $ puppet certificate_request search x --terminus ca
  EOT

  get_action(:save).summary "API only: submit a certificate signing request."
  get_action(:save).arguments "<x509_CSR>"
end
