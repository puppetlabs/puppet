require 'net/https'
require 'digest/sha1'
require 'uri'
require 'puppet/util/http_proxy'
require 'puppet/forge'
require 'puppet/forge/errors'
require 'puppet/network/http'

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

    if Puppet.features.zlib?
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
      request = get_request_object(@uri.path.chomp('/')+path)
      Puppet.debug "HTTP GET #{@host}#{request.path}"
      return read_response(request, io)
    end

    def forge_authorization
      if Puppet[:forge_authorization]
        Puppet[:forge_authorization]
      elsif Puppet.features.pe_license?
        PELicense.load_license_key.authorization_token
      end
    end

    # responsible for properly encoding a URI
    def get_request_object(path)
      headers = {
        "User-Agent" => user_agent,
      }

      if Puppet.features.zlib?
        headers = headers.merge({
          "Accept-Encoding" => Puppet::Network::HTTP::Compression::ACCEPT_ENCODING
        })
      end

      if forge_authorization
        headers = headers.merge({"Authorization" => forge_authorization})
      end

      request = Net::HTTP::Get.new(Puppet::Util.uri_encode(path), headers)

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
      http_object = Puppet::Util::HttpProxy.get_http_object(uri)

      http_object.start do |http|
        response = http.request(request)

        if Puppet.features.zlib?
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
        Puppet[:http_user_agent]
      ].join(' ').freeze
    end
  end
end
