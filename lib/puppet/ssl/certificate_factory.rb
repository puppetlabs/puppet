require 'puppet/ssl'

# The tedious class that does all the manipulations to the
# certificate to correctly sign it.  Yay.
class Puppet::SSL::CertificateFactory
    # How we convert from various units to the required seconds.
    UNITMAP = {
        "y" => 365 * 24 * 60 * 60,
        "d" => 24 * 60 * 60,
        "h" => 60 * 60,
        "s" => 1
    }

    attr_reader :name, :cert_type, :csr, :issuer, :serial

    def initialize(cert_type, csr, issuer, serial)
        @cert_type, @csr, @issuer, @serial = cert_type, csr, issuer, serial

        @name = @csr.subject
    end

    # Actually generate our certificate.
    def result
        @cert = OpenSSL::X509::Certificate.new

        @cert.version = 2 # X509v3
        @cert.subject = @csr.subject
        @cert.issuer = @issuer.subject
        @cert.public_key = @csr.public_key
        @cert.serial = @serial

        build_extensions()

        set_ttl

        @cert
    end

    private

    # This is pretty ugly, but I'm not really sure it's even possible to do
    # it any other way.
    def build_extensions
        @ef = OpenSSL::X509::ExtensionFactory.new

        @ef.subject_certificate = @cert

        if @issuer.is_a?(OpenSSL::X509::Request) # It's a self-signed cert
            @ef.issuer_certificate = @cert
        else
            @ef.issuer_certificate = @issuer
        end

        @subject_alt_name = []
        @key_usage = nil
        @ext_key_usage = nil
        @extensions = []

        method = "add_#{@cert_type.to_s}_extensions"

        begin
            send(method)
        rescue NoMethodError
            raise ArgumentError, "%s is an invalid certificate type" % @cert_type
        end

        @extensions << @ef.create_extension("nsComment", "Puppet Ruby/OpenSSL Generated Certificate")
        @extensions << @ef.create_extension("basicConstraints", @basic_constraint, true)
        @extensions << @ef.create_extension("subjectKeyIdentifier", "hash")
        @extensions << @ef.create_extension("keyUsage", @key_usage.join(",")) if @key_usage
        @extensions << @ef.create_extension("extendedKeyUsage", @ext_key_usage.join(",")) if @ext_key_usage
        @extensions << @ef.create_extension("subjectAltName", @subject_alt_name.join(",")) if ! @subject_alt_name.empty?

        @cert.extensions = @extensions

        # for some reason this _must_ be the last extension added
        @extensions << @ef.create_extension("authorityKeyIdentifier", "keyid:always,issuer:always") if @cert_type == :ca
    end

    # TTL for new certificates in seconds. If config param :ca_ttl is set,
    # use that, otherwise use :ca_days for backwards compatibility
    def ttl
        ttl = Puppet.settings[:ca_ttl]

        return ttl unless ttl.is_a?(String)

        raise ArgumentError, "Invalid ca_ttl #{ttl}" unless ttl =~ /^(\d+)(y|d|h|s)$/

        return $1.to_i * UNITMAP[$2]
    end

    def set_ttl
        # Make the certificate valid as of yesterday, because
        # so many people's clocks are out of sync.
        from = Time.now - (60*60*24)
        @cert.not_before = from
        @cert.not_after = from + ttl
    end

    # Woot! We're a CA.
    def add_ca_extensions
        @basic_constraint = "CA:TRUE"
        @key_usage = %w{cRLSign keyCertSign}
    end

    # We're a terminal CA, probably not self-signed.
    def add_terminalsubca_extensions
        @basic_constraint = "CA:TRUE,pathlen:0"
        @key_usage = %w{cRLSign keyCertSign}
    end

    # We're a normal server.
    def add_server_extensions
        @basic_constraint = "CA:FALSE"
        dnsnames = Puppet[:certdnsnames]
        name = @name.to_s.sub(%r{/CN=},'')
        if dnsnames != ""
            dnsnames.split(':').each { |d| @subject_alt_name << 'DNS:' + d }
            @subject_alt_name << 'DNS:' + name # Add the fqdn as an alias
        elsif name == Facter.value(:fqdn) # we're a CA server, and thus probably the server
            @subject_alt_name << 'DNS:' + "puppet" # Add 'puppet' as an alias
            @subject_alt_name << 'DNS:' + name # Add the fqdn as an alias
            @subject_alt_name << 'DNS:' + name.sub(/^[^.]+./, "puppet.") # add puppet.domain as an alias
        end
        @key_usage = %w{digitalSignature keyEncipherment}
        @ext_key_usage = %w{serverAuth clientAuth emailProtection}
    end

    # Um, no idea.
    def add_ocsp_extensions
        @basic_constraint = "CA:FALSE"
        @key_usage = %w{nonRepudiation digitalSignature}
        @ext_key_usage = %w{serverAuth OCSPSigning}
    end

    # Normal client.
    def add_client_extensions
        @basic_constraint = "CA:FALSE"
        @key_usage = %w{nonRepudiation digitalSignature keyEncipherment}
        @ext_key_usage = %w{clientAuth emailProtection}

        @extensions << @ef.create_extension("nsCertType", "client,email")
    end
end

