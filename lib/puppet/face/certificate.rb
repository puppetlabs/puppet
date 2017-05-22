require 'puppet/indirector/face'
require 'puppet/ssl/host'

Puppet::Indirector::Face.define(:certificate, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("Provide access to the CA for certificate management.")
  description <<-EOT
    This subcommand interacts with a local or remote Puppet certificate
    authority. Currently, its behavior is not a full superset of `puppet
    cert`; specifically, it is unable to mimic puppet cert's "clean" option,
    and its "generate" action submits a CSR rather than creating a
    signed certificate.
  EOT

  option "--ca-location " + _("LOCATION") do
    required
    summary _("Which certificate authority to use (local or remote).")
    description <<-EOT
      Whether to act on the local certificate authority or one provided by a
      remote puppet master. Allowed values are 'local' and 'remote.'

      This option is required.
    EOT

    before_action do |action, args, options|
      unless [:remote, :local, :only].include? options[:ca_location].to_sym
        raise ArgumentError, _("Valid values for ca-location are 'remote', 'local', 'only'.")
      end
      Puppet::SSL::Host.ca_location = options[:ca_location].to_sym
    end
  end

  action :generate do
    summary _("Generate a new certificate signing request.")
    arguments _("<host>")
    returns "Nothing."
    description <<-EOT
      Generates and submits a certificate signing request (CSR) for the
      specified host. This CSR will then have to be signed by a user
      with the proper authorization on the certificate authority.

      Puppet agent usually handles CSR submission automatically. This action is
      primarily useful for requesting certificates for individual users and
      external applications.
    EOT
    examples <<-EOT
      Request a certificate for "somenode" from the site's CA:

      $ puppet certificate generate somenode.puppetlabs.lan --ca-location remote
    EOT

    # Duplicate the option here explicitly to distinguish if it was passed arg
    # us vs. set in the config file.
    option "--dns-alt-names "+ _("NAMES") do
      summary _("Additional DNS names to add to the certificate request")
      description Puppet.settings.setting(:dns_alt_names).desc
    end

    when_invoked do |name, options|
      host = Puppet::SSL::Host.new(name)

      # We have a weird case where we have --dns_alt_names from Puppet, but
      # this option is --dns-alt-names. Until we can get rid of --dns-alt-names
      # or do a global tr('-', '_'), we have to support both.
      # In supporting both, we'll use Puppet[:dns_alt_names] if specified on
      # command line. We'll use options[:dns_alt_names] if specified on
      # command line. If both specified, we'll fail.
      # jeffweiss 17 april 2012

      global_setting_from_cli = Puppet.settings.set_by_cli?(:dns_alt_names) == true
      raise ArgumentError, _("Can't specify both --dns_alt_names and --dns-alt-names") if options[:dns_alt_names] and global_setting_from_cli
      options[:dns_alt_names] = Puppet[:dns_alt_names] if global_setting_from_cli

      # If dns_alt_names are specified via the command line, we will always add
      # them. Otherwise, they will default to the config file setting iff this
      # cert is for the host we're running on.

      unless Puppet::FileSystem.exist?(Puppet[:hostcert])
        Puppet.push_context({:ssl_host => host})
      end

      host.generate_certificate_request(:dns_alt_names => options[:dns_alt_names])
    end
  end

  action :list do
    summary _("List all certificate signing requests.")
    returns <<-EOT
      An array of #inspect output from CSR objects. This output is
      currently messy, but does contain the names of nodes requesting
      certificates. This action returns #inspect strings even when used
      from the Ruby API.
    EOT

    when_invoked do |options|
      Puppet::SSL::Host.indirection.search("*", {
        :for => :certificate_request,
      }).map { |h| h.inspect }
    end
  end

  action :sign do
    summary _("Sign a certificate signing request for HOST.")
    arguments _("<host>")
    returns <<-EOT
      A string that appears to be (but isn't) an x509 certificate.
    EOT
    examples <<-EOT
      Sign somenode.puppetlabs.lan's certificate:

      $ puppet certificate sign somenode.puppetlabs.lan --ca-location remote
    EOT

    option("--[no-]allow-dns-alt-names") do
      summary _("Whether or not to accept DNS alt names in the certificate request")
    end

    when_invoked do |name, options|
      host = Puppet::SSL::Host.new(name)
      if Puppet::SSL::Host.ca_location == :remote
        if options[:allow_dns_alt_names]
          raise ArgumentError, _("--allow-dns-alt-names may not be specified with a remote CA")
        end

        host.desired_state = 'signed'
        Puppet::SSL::Host.indirection.save(host)
      else
        # We have to do this case manually because we need to specify
        # allow_dns_alt_names.
        unless ca = Puppet::SSL::CertificateAuthority.instance
          raise ArgumentError, _("This process is not configured as a certificate authority")
        end

        signing_options = {allow_dns_alt_names: options[:allow_dns_alt_names]}

        ca.sign(name, signing_options)
      end
    end
  end

  # Indirector action doc overrides
  find = get_action(:find)
  find.summary _("Retrieve a certificate.")
  find.arguments _("<host>")
  find.render_as = :s
  find.returns <<-EOT
    An x509 SSL certificate.

    Note that this action has a side effect of caching a copy of the
    certificate in Puppet's `ssldir`.
  EOT

  destroy = get_action(:destroy)
  destroy.summary _("Delete a certificate.")
  destroy.arguments _("<host>")
  destroy.returns "Nothing."
  destroy.description <<-EOT
    Deletes a certificate. This action currently only works on the local CA.
  EOT

  deactivate_action(:search)
  deactivate_action(:save)
end
