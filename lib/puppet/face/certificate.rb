require 'puppet/indirector/face'
require 'puppet/ssl/host'

Puppet::Indirector::Face.define(:certificate, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Provide access to the CA for certificate management"
  description <<-'EOT'
    This face interacts with a local or remote Puppet certificate
    authority. Currently, its behavior is not a full superset of `puppet
    cert`; specifically, it is unable to mimic puppet cert's "clean" option,
    and its "generate" action submits a CSR rather than creating a
    signed certificate.
  EOT
  notes <<-'EOT'
    This is an indirector face, which exposes `find`, `search`, `save`, and
    `destroy` actions for an indirected subsystem of Puppet. Valid termini
    for this face include:

    * `ca`
    * `file`
    * `rest`
  EOT

  option "--ca-location LOCATION" do
    summary "The certificate authority to query"
    description <<-'EOT'
      Whether to act on the local certificate authority or one provided by a
      remote puppet master. Allowed values are 'local' and 'remote.'
    EOT

    before_action do |action, args, options|
      Puppet::SSL::Host.ca_location = options[:ca_location].to_sym
    end
  end

  action :generate do
    summary "Generate a new certificate signing request for HOST."
    arguments "<host>"
    returns "Nothing."
    description <<-'EOT'
      Generates and submits a certificate signing request (CSR) for the
      specified host. This CSR will then have to be signed by a user
      with the proper authorization on the certificate authority.

      Puppet agent usually handles CSR submission automatically. This action is
      primarily useful for requesting certificates for individual users and
      external applications.
    EOT
    examples <<-'EOT'
      Request a certificate for "somenode" from the site's CA:

      $ puppet certificate generate somenode.puppetlabs.lan --ca-location remote
    EOT

    when_invoked do |name, options|
      host = Puppet::SSL::Host.new(name)
      host.generate_certificate_request
      host.certificate_request.class.indirection.save(host.certificate_request)
    end
  end

  action :list do
    summary "List all certificate signing requests."
    returns <<-'EOT'
      An array of CSR object #inspect strings. This output is currently messy,
      but does contain the names of nodes requesting certificates.
    EOT

    when_invoked do |options|
      Puppet::SSL::Host.indirection.search("*", {
        :for => :certificate_request,
      }).map { |h| h.inspect }
    end
  end

  action :sign do
    summary "Sign a certificate signing request for HOST."
    arguments "<host>"
    returns <<-'EOT'
      A string that appears to be an x509 certificate, but is actually
      not. Retrieve certificates using the `find` action.
    EOT
    examples <<-'EOT'
      Sign somenode.puppetlabs.lan's certificate:

      $ puppet certificate sign somenode.puppetlabs.lan --ca-location remote
    EOT

    when_invoked do |name, options|
      host = Puppet::SSL::Host.new(name)
      host.desired_state = 'signed'
      Puppet::SSL::Host.indirection.save(host)
    end
  end

  # Indirector action doc overrides
  find = get_action(:find)
  find.summary "Retrieve a certificate"
  find.arguments "<host>"
  find.returns <<-'EOT'
    An x509 SSL certificate. You will usually want to render this as a
    string ('--render-as s').

    Note that this action has a side effect of caching a copy of the
    certificate in Puppet's `ssldir`.
  EOT

  destroy = get_action(:destroy)
  destroy.summary "Delete a local certificate."
  destroy.arguments "<host>"
  destroy.returns "Nothing."
  destroy.description <<-'EOT'
    Deletes a certificate. This action currently only works with a local CA.
  EOT

  get_action(:search).summary "Invalid for this face."
  get_action(:save).summary "Invalid for this face."
end
