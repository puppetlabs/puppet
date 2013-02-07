require 'net/https'
require 'zlib'
require 'digest/sha1'
require 'uri'
require 'puppet/forge/errors'

class Puppet::Forge
  # = Repository
  #
  # This class is a file for accessing remote repositories with modules.
  class Repository
    include Puppet::Forge::Errors

    attr_reader :uri, :cache

    # List of Net::HTTP exceptions to catch
    NET_HTTP_EXCEPTIONS = [
      EOFError,
      Errno::ECONNABORTED,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EINVAL,
      Errno::ETIMEDOUT,
      Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError,
      Net::ProtocolError,
      SocketError,
      Zlib::GzipFile::Error,
    ]

    # Instantiate a new repository instance rooted at the +url+.
    # The agent will report +consumer_version+ in the User-Agent to
    # the repository.
    def initialize(url, consumer_version)
      @uri = url.is_a?(::URI) ? url : ::URI.parse(url)
      @cache = Cache.new(self)
      @consumer_version = consumer_version
    end

    # Read HTTP proxy configurationm from Puppet's config file, or the
    # http_proxy environment variable.
    def http_proxy_env
      proxy_env = ENV["http_proxy"] || ENV["HTTP_PROXY"] || nil
      begin
        return URI.parse(proxy_env) if proxy_env
      rescue URI::InvalidURIError
        return nil
      end
      return nil
    end

    def http_proxy_host
      env = http_proxy_env

      if env and env.host then
        return env.host
      end

      if Puppet.settings[:http_proxy_host] == 'none'
        return nil
      end

      return Puppet.settings[:http_proxy_host]
    end

    def http_proxy_port
      env = http_proxy_env

      if env and env.port then
        return env.port
      end

      return Puppet.settings[:http_proxy_port]
    end

    # Return a Net::HTTPResponse read for this +request_path+.
    def make_http_request(request_path)
      request = Net::HTTP::Get.new(URI.escape(request_path), { "User-Agent" => user_agent })
      if ! @uri.user.nil? && ! @uri.password.nil?
        request.basic_auth(@uri.user, @uri.password)
      end
      return read_response(request)
    end

    # Return a Net::HTTPResponse read from this HTTPRequest +request+.
    #
    # @param request [Net::HTTPRequest] request to make
    # @return [Net::HTTPResponse] response from request
    # @raise [Puppet::Forge::Errors::CommunicationError] if there is a network
    #   related error
    # @raise [Puppet::Forge::Errors::SSLVerifyError] if there is a problem
    #  verifying the remote SSL certificate
    def read_response(request)
      http_object = get_http_object

      http_object.start do |http|
        http.request(request)
      end
    rescue *NET_HTTP_EXCEPTIONS => e
      raise CommunicationError.new(:uri => @uri.to_s, :original => e)
    rescue OpenSSL::SSL::SSLError => e
      if e.message =~ /certificate verify failed/
        raise SSLVerifyError.new(:uri => @uri.to_s, :original => e)
      else
        raise e
      end
    end

    # Return a Net::HTTP::Proxy object constructed from the settings provided
    # accessing the repository.
    #
    # This method optionally configures SSL correctly if the URI scheme is
    # 'https', including setting up the root certificate store so remote server
    # SSL certificates can be validated.
    #
    # @return [Net::HTTP::Proxy] object constructed from repo settings
    def get_http_object
      proxy_class = Net::HTTP::Proxy(http_proxy_host, http_proxy_port)
      proxy = proxy_class.new(@uri.host, @uri.port)

      if @uri.scheme == 'https'
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths

        proxy.use_ssl = true
        proxy.verify_mode = OpenSSL::SSL::VERIFY_PEER
        proxy.cert_store = cert_store
      end

      proxy
    end

    # Return the local file name containing the data downloaded from the
    # repository at +release+ (e.g. "myuser-mymodule").
    def retrieve(release)
      return cache.retrieve(@uri + release)
    end

    # Return the URI string for this repository.
    def to_s
      return @uri.to_s
    end

    # Return the cache key for this repository, this a hashed string based on
    # the URI.
    def cache_key
      return @cache_key ||= [
        @uri.to_s.gsub(/[^[:alnum:]]+/, '_').sub(/_$/, ''),
        Digest::SHA1.hexdigest(@uri.to_s)
      ].join('-')
    end

    def user_agent
      "#{@consumer_version} Puppet/#{Puppet.version} (#{Facter.value(:operatingsystem)} #{Facter.value(:operatingsystemrelease)}) #{ruby_version}"
    end
    private :user_agent

    def ruby_version
      # the patchlevel is not available in ruby 1.8.5
      patch = defined?(RUBY_PATCHLEVEL) ? "-p#{RUBY_PATCHLEVEL}" : ""
      "Ruby/#{RUBY_VERSION}#{patch} (#{RUBY_RELEASE_DATE}; #{RUBY_PLATFORM})"
    end
    private :ruby_version
  end
end
