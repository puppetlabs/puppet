require 'puppet/face'

Puppet::Face.define(:ca, '0.1.0') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Local Puppet Certificate Authority management."

  description <<-TEXT
    This provides local management of the Puppet Certificate Authority.

    You can use this subcommand to sign outstanding certificate requests, list
    and manage local certificates, and inspect the state of the CA.
  TEXT

  action :list do
    summary "List certificates and/or certificate requests."

    description <<-TEXT
      This will list the current certificates and certificate signing requests
      in the Puppet CA.  You will also get the fingerprint, and any certificate
      verification failure reported.
    TEXT

    option "--[no-]all" do
      summary "Include all certificates and requests."
    end

    option "--[no-]pending" do
      summary "Include pending certificate signing requests."
    end

    option "--[no-]signed" do
      summary "Include signed certificates."
    end

    option "--digest ALGORITHM" do
      summary "The hash algorithm to use when displaying the fingerprint"
    end

    option "--subject PATTERN" do
      summary "Only list if the subject matches PATTERN."

      description <<-TEXT
        Only include certificates or requests where subject matches PATTERN.

        PATTERN is interpreted as a regular expression, allowing complex
        filtering of the content.
      TEXT
    end

    when_invoked do |options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :only

      pattern = options[:subject].nil? ? nil :
        Regexp.new(options[:subject], Regexp::IGNORECASE)

      pending = options[:pending].nil? ? options[:all] : options[:pending]
      signed  = options[:signed].nil?  ? options[:all] : options[:signed]

      # By default we list pending, so if nothing at all was requested...
      unless pending or signed then pending = true end

      hosts = []

      pending and hosts += ca.waiting?
      signed  and hosts += ca.list

      pattern and hosts = hosts.select {|hostname| pattern.match hostname }

      hosts.sort.map {|host| Puppet::SSL::Host.new(host) }
    end

    when_rendering :console do |hosts, options|
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end

      length = hosts.map{|x| x.name.length }.max.to_i + 1

      hosts.map do |host|
        name = host.name.ljust(length)
        if host.certificate_request then
          "  #{name} #{host.certificate_request.digest(options[:digest])}"
        else
          begin
            ca.verify(host.name)
            "+ #{name} #{host.certificate.digest(options[:digest])}"
          rescue Puppet::SSL::CertificateAuthority::CertificateVerificationError => e
            "- #{name} #{host.certificate.digest(options[:digest])} (#{e.to_s})"
          end
        end
      end.join("\n")
    end
  end

  action :destroy do
    summary "Destroy named certificate or pending certificate request."
    when_invoked do |host, options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :local

      ca.destroy host
    end
  end

  action :revoke do
    summary "Add certificate to certificate revocation list."
    when_invoked do |host, options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :only

      begin
        ca.revoke host
      rescue ArgumentError => e
        # This is a bit naff, but it makes the behaviour consistent with the
        # destroy action.  The underlying tools could be nicer for that sort
        # of thing; they have fairly inconsistent reporting of failures.
        raise unless e.to_s =~ /Could not find a serial number for /
        "Nothing was revoked"
      end
    end
  end

  action :generate do
    summary "Generate a certificate for a named client."
    option "--dns-alt-names NAMES" do
      summary "Additional DNS names to add to the certificate request"
      description Puppet.settings.setting(:dns_alt_names).desc
    end

    when_invoked do |host, options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :local

      begin
        ca.generate(host, :dns_alt_names => options[:dns_alt_names])
      rescue RuntimeError => e
        if e.to_s =~ /already has a requested certificate/
          "#{host} already has a certificate request; use sign instead"
        else
          raise
        end
      rescue ArgumentError => e
        if e.to_s =~ /A Certificate already exists for /
          "#{host} already has a certificate"
        else
          raise
        end
      end
    end
  end

  action :sign do
    summary "Sign an outstanding certificate request."
    option("--[no-]allow-dns-alt-names") do
      summary "Whether or not to accept DNS alt names in the certificate request"
    end

    when_invoked do |host, options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :only

      begin
        ca.sign(host, options[:allow_dns_alt_names])
      rescue ArgumentError => e
        if e.to_s =~ /Could not find certificate request/
          e.to_s
        else
          raise
        end
      end
    end
  end

  action :print do
    summary "Print the full-text version of a host's certificate."
    when_invoked do |host, options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :only

      ca.print host
    end
  end

  action :fingerprint do
    summary "Print the DIGEST (defaults to the signing algorithm) fingerprint of a host's certificate."
    option "--digest ALGORITHM" do
      summary "The hash algorithm to use when displaying the fingerprint"
    end

    when_invoked do |host, options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :only

      if cert = (Puppet::SSL::Certificate.indirection.find(host) || Puppet::SSL::CertificateRequest.indirection.find(host))
        cert.digest(options[:digest]).to_s
      else
        nil
      end
    end
  end

  action :verify do
    summary "Verify the named certificate against the local CA certificate."
    when_invoked do |host, options|
      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      Puppet::SSL::Host.ca_location = :only

      begin
        ca.verify host
        { :host => host, :valid => true }
      rescue ArgumentError => e
        raise unless e.to_s =~ /Could not find a certificate for/
        { :host => host, :valid => false, :error => e.to_s }
      rescue Puppet::SSL::CertificateAuthority::CertificateVerificationError => e
        { :host => host, :valid => false, :error => e.to_s }
      end
    end

    when_rendering :console do |value|
      if value[:valid]
        nil
      else
        "Could not verify #{value[:host]}: #{value[:error]}"
      end
    end
  end
end
