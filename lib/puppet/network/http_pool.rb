require 'puppet/sslcertificates/support'
require 'net/https'

module Puppet::Network
end

# Manage Net::HTTP instances for keep-alive.
module Puppet::Network::HttpPool
    # 2008/03/23
    # LAK:WARNING: Enabling this has a high propability of
    # causing corrupt files and who knows what else.  See #1010.
    HTTP_KEEP_ALIVE = false

    def self.keep_alive?
        HTTP_KEEP_ALIVE
    end

    # This handles reading in the key and such-like.
    extend Puppet::SSLCertificates::Support
    @http_cache = {}

    # Clear our http cache, closing all connections.
    def self.clear_http_instances
        @http_cache.each do |name, connection|
            connection.finish if connection.started?
        end
        @http_cache.clear
        @cert = nil
        @key = nil
    end

    # Make sure we set the driver up when we read the cert in.
    def self.read_cert
        if val = super # This calls read_cert from the Puppet::SSLCertificates::Support module.
            # Clear out all of our connections, since they previously had no cert and now they
            # should have them.
            clear_http_instances
            return val
        else
            return false
        end
    end

    # Use cert information from a Puppet client to set up the http object.
    def self.cert_setup(http)
        # Just no-op if we don't have certs.
        return false unless (defined?(@cert) and @cert) or self.read_cert

        store = OpenSSL::X509::Store.new
        store.add_file Puppet[:localcacert]
        store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT

        http.cert_store = store
        http.ca_file = Puppet[:localcacert]
        http.cert = self.cert
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.key = self.key
    end

    # Retrieve a cached http instance of caching is enabled, else return
    # a new one.
    def self.http_instance(host, port, reset = false)
        # We overwrite the uninitialized @http here with a cached one.
        key = "%s:%s" % [host, port]

        # Return our cached instance if we've got a cache, as long as we're not
        # resetting the instance.
        if keep_alive?
            return @http_cache[key] if ! reset and @http_cache[key]

            # Clean up old connections if we have them.
            if http = @http_cache[key]
                @http_cache.delete(key)
                http.finish if http.started?
            end
        end

        args = [host, port]
        if Puppet[:http_proxy_host] == "none"
            args << nil << nil
        else
            args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
        end
        http = Net::HTTP.new(*args)

        # Pop open the http client a little; older versions of Net::HTTP(s) didn't
        # give us a reader for ca_file... Grr...
        class << http; attr_accessor :ca_file; end

        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        # JJM Configurable fix for #896.
        if Puppet[:http_enable_post_connection_check]
            http.enable_post_connection_check = true
        else
            http.enable_post_connection_check = false
        end

        cert_setup(http)

        @http_cache[key] = http if keep_alive?

        return http
    end
end
