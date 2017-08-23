require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_request, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   "Apache 2 license; see COPYING"

  summary _("Manage certificate requests.")
  description <<-EOT
    This subcommand retrieves and submits certificate signing requests (CSRs).
  EOT

  deactivate_action(:destroy)

  find = get_action(:find)
  find.summary "Retrieve a single CSR."
  find.arguments "[<host>]"
  find.render_as = :s
  find.returns <<-EOT
    A single certificate request. When used from the Ruby API, returns a
    Puppet::SSL::CertificateRequest object.

    Defaults to the current nodes certname.
  EOT
  find.examples <<-EOT
    Retrieve a single CSR from the puppet master's CA:

    $ puppet certificate_request find somenode.puppetlabs.lan --terminus rest
  EOT

  search = get_action(:search)
  search.summary "Retrieve all outstanding CSRs."
  search.arguments "<dummy_text>"
  search.render_as = :s
  search.returns <<-EOT
    A list of certificate requests. When used from the Ruby API, returns an
    array of Puppet::SSL::CertificateRequest objects.
  EOT
  search.short_description <<-EOT
    Retrieves all outstanding certificate signing requests. Due to a known bug,
    this action requires a dummy search key, the content of which is irrelevant.
  EOT
  search.notes <<-EOT
    Although this action always returns all CSRs, it requires a dummy search
    key; this is a known bug.
  EOT
  search.examples <<-EOT
    Retrieve all CSRs from the local CA (similar to 'puppet cert list'):

    $ puppet certificate_request search x --terminus ca
  EOT

  get_action(:save).summary "API only: submit a certificate signing request."
  get_action(:save).arguments "<x509_CSR>"

  deprecate
end
