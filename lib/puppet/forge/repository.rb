require 'net/https'
require 'digest/sha1'
require 'uri'
require 'puppet/util/http_proxy'
require 'puppet/forge'
require 'puppet/forge/errors'

if Puppet.features.zlib? && Puppet[:zlib]
  require 'zlib'
end

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
    ]

    if Puppet.features.zlib? && Puppet[:zlib]
      NET_HTTP_EXCEPTIONS << Zlib::GzipFile::Error
    end

    # Instantiate a new repository instance rooted at the +url+.
    # The library will report +for_agent+ in the User-Agent to the repository.
    def initialize(host, for_agent)
      @host  = host
      @agent = for_agent
      @cache = Cache.new(self)
      @uri   = URI.parse(host)
    end

    # Return a Net::HTTPResponse read for this +path+.
    def make_http_request(path, io = nil)
      Puppet.debug "HTTP GET #{@host}#{path}"
      request = get_request_object(path)
      return read_response(request, io)
    end

    def forge_authorization
      if Puppet[:forge_authorization]
        Puppet[:forge_authorization]
      elsif Puppet.features.pe_license?
        PELicense.load_license_key.authorization_token
      end
    end

    def get_request_object(path)
      headers = {
        "User-Agent" => user_agent,
      }

      if Puppet.features.zlib? && Puppet[:zlib] && RUBY_VERSION >= "1.9"
        headers = headers.merge({
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        })
      end

      if forge_authorization
        headers = headers.merge({"Authorization" => forge_authorization})
      end

      request = Net::HTTP::Get.new(URI.escape(path), headers)

      unless @uri.user.nil? || @uri.password.nil? || forge_authorization
        request.basic_auth(@uri.user, @uri.password)
      end

      return request
    end

    # Return a Net::HTTPResponse read from this HTTPRequest +request+.
    #
    # @param request [Net::HTTPRequest] request to make
    # @return [Net::HTTPResponse] response from request
    # @raise [Puppet::Forge::Errors::CommunicationError] if there is a network
    #   related error
    # @raise [Puppet::Forge::Errors::SSLVerifyError] if there is a problem
    #  verifying the remote SSL certificate
    def read_response(request, io = nil)
      http_object = get_http_object

      http_object.start do |http|
        response = http.request(request)

        if Puppet.features.zlib? && Puppet[:zlib]
          if response && response.key?("content-encoding")
            case response["content-encoding"]
            when "gzip"
              response.body = Zlib::GzipReader.new(StringIO.new(response.read_body), :encoding => "ASCII-8BIT").read
              response.delete("content-encoding")
            when "deflate"
              response.body = Zlib::Inflate.inflate(response.read_body)
              response.delete("content-encoding")
            end
          end
        end

        io.write(response.body) if io.respond_to? :write
        response
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
      proxy_class = Net::HTTP::Proxy(Puppet::Util::HttpProxy.http_proxy_host, Puppet::Util::HttpProxy.http_proxy_port, Puppet::Util::HttpProxy.http_proxy_user, Puppet::Util::HttpProxy.http_proxy_password)
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
      path = @host.chomp('/') + release
      return cache.retrieve(path)
    end

    # Return the URI string for this repository.
    def to_s
      "#<#{self.class} #{@host}>"
    end

    # Return the cache key for this repository, this a hashed string based on
    # the URI.
    def cache_key
      return @cache_key ||= [
        @host.to_s.gsub(/[^[:alnum:]]+/, '_').sub(/_$/, ''),
        Digest::SHA1.hexdigest(@host.to_s)
      ].join('-').freeze
    end

    private

    def user_agent
      @user_agent ||= [
        @agent,
        "Puppet/#{Puppet.version}",
        "Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})",
      ].join(' ').freeze
    end
  end
end
