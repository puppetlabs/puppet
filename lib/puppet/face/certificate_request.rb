require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_request, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage certificate requests."
  description <<-EOT
Retrieves and submits certificate signing requests (CSRs). Invoke
`search` with an unread key to retrieve all outstanding CSRs, invoke
`find` with a node certificate name to retrieve a specific request, and
invoke `save` to submit a CSR.
  EOT
  notes <<-EOT
This is an indirector face, which exposes find, search, save, and
destroy actions for an indirected subsystem of Puppet. Valid terminuses
for this face include:

* `ca`
* `file`
* `rest`
  EOT
  examples <<-EOT
Retrieve all CSRs from the local CA:

    puppet certificate_request search no_key --terminus ca

Retrieve a single CSR from the puppet master's CA:

    puppet certificate_request find mynode.puppetlabs.lan --terminus rest
  EOT
end
