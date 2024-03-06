# frozen_string_literal: true

require_relative '../../puppet/ssl/openssl_loader'
require 'digest/sha1'
require 'uri'
require_relative '../../puppet/forge'
require_relative '../../puppet/forge/errors'
require_relative '../../puppet/network/http'

class Puppet::Forge
  # = Repository
  #
  # This class is a file for accessing remote repositories with modules.
  class Repository
    include Puppet::Forge::Errors

    attr_reader :uri, :cache

    # Instantiate a new repository instance rooted at the +url+.
    # The library will report +for_agent+ in the User-Agent to the repository.
    def initialize(host, for_agent)
      @host  = host
      @agent = for_agent
      @cache = Cache.new(self)
      @uri   = URI.parse(host)

      ssl_provider = Puppet::SSL::SSLProvider.new
      @ssl_context = ssl_provider.create_system_context(cacerts: [])
    end

    # Return a Net::HTTPResponse read for this +path+.
    def make_http_request(path, io = nil)
      raise ArgumentError, "Path must start with forward slash" unless path.start_with?('/')

      begin
        str = @uri.to_s
        str.chomp!('/')
        str += Puppet::Util.uri_encode(path)
        uri = URI(str)

        headers = { "User-Agent" => user_agent }

        if forge_authorization
          uri.user = nil
          uri.password = nil
          headers["Authorization"] = forge_authorization
        end

        http = Puppet.runtime[:http]
        response = http.get(uri, headers: headers, options: { ssl_context: @ssl_context })
        io.write(response.body) if io.respond_to?(:write)
        response
      rescue Puppet::SSL::CertVerifyError => e
        raise SSLVerifyError.new(:uri => @uri.to_s, :original => e.cause)
      rescue => e
        raise CommunicationError.new(:uri => @uri.to_s, :original => e)
      end
    end

    def forge_authorization
      if Puppet[:forge_authorization]
        Puppet[:forge_authorization]
      elsif Puppet.features.pe_license?
        PELicense.load_license_key.authorization_token
      end
    end

    # Return the local file name containing the data downloaded from the
    # repository at +release+ (e.g. "myuser-mymodule").
    def retrieve(release)
      path = @host.chomp('/') + release
      cache.retrieve(path)
    end

    # Return the URI string for this repository.
    def to_s
      "#<#{self.class} #{@host}>"
    end

    # Return the cache key for this repository, this a hashed string based on
    # the URI.
    def cache_key
      @cache_key ||= [
        @host.to_s.gsub(/[^[:alnum:]]+/, '_').sub(/_$/, ''),
        Digest::SHA1.hexdigest(@host.to_s)
      ].join('-').freeze
    end

    private

    def user_agent
      @user_agent ||= [
        @agent,
        Puppet[:http_user_agent]
      ].join(' ').freeze
    end
  end
end
