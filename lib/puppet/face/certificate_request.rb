require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_request, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage certificate requests."
  description <<-'EOT'
    Retrieves and submits certificate signing requests (CSRs). Invoke
    `search` with a dummy key to retrieve all outstanding CSRs, invoke
    `find` with a node certificate name to retrieve a specific request, and
    invoke `save` to submit a CSR.
  EOT

  # Per-action doc overrides
  get_action(:destroy).summary "Invalid for this face."

  get_action(:find).summary "Retrieve a single CSR."
  get_action(:find).arguments "<host>"
  get_action(:find).returns <<-'EOT'
    A single certificate request. In most cases, you will want to render
    this as a string ('--render-as s').
  EOT
  get_action(:find).examples <<-'EOT'
    Retrieve a single CSR from the puppet master's CA:

    $ puppet certificate_request find somenode.puppetlabs.lan --terminus rest
  EOT

  get_action(:search).summary "Retrieve all outstanding CSRs."
  get_action(:search).arguments "<dummy_key>"
  get_action(:search).returns <<-'EOT'
    An array of certificate request objects. In most cases, you will
    want to render this as a string ('--render-as s').
  EOT
  get_action(:search).notes "This action always returns all CSRs, but requires a dummy search key."
  get_action(:search).examples <<-'EOT'
    Retrieve all CSRs from the local CA:

    $ puppet certificate_request search x --terminus ca
  EOT

  get_action(:save).summary "Submit a certificate signing request."
  get_action(:save).arguments "<x509_CSR>"
end
