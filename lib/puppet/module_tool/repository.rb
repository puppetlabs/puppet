require 'net/http'
require 'digest/sha1'

module Puppet::Module::Tool

  # = Repository
  #
  # This class is a file for accessing remote repositories with modules.
  class Repository
    include Utils::URI
    include Utils::Interrogation

    attr_reader :uri, :cache

    # Instantiate a new repository instance rooted at the optional string
    # +url+, else an instance of the default Puppet modules repository.
    def initialize(url=Puppet::Module::Tool::REPOSITORY_URL)
      @uri = normalize(url)
      @cache = Cache.new(self)
    end

    # Return a Net::HTTPResponse read for this +request+.
    #
    # Options:
    # * :authenticate => Request authentication on the terminal. Defaults to false.
    def contact(request, options = {})
      if options[:authenticate]
        authenticate(request)
      end
      if ! @uri.user.nil? && ! @uri.password.nil?
        request.basic_auth(@uri.user, @uri.password)
      end
      return read_contact(request)
    end

    # Return a Net::HTTPResponse read from this HTTPRequest +request+.
    def read_contact(request)
      begin
        Net::HTTP::Proxy(
            Puppet::Module::Tool::http_proxy_host,
            Puppet::Module::Tool::http_proxy_port
            ).start(@uri.host, @uri.port) do |http|
          http.request(request)
        end
      rescue Errno::ECONNREFUSED, SocketError
        raise SystemExit, "Could not reach remote repository"
      end
    end

    # Set the HTTP Basic Authentication parameters for the Net::HTTPRequest
    # +request+ by asking the user for input on the console.
    def authenticate(request)
      Puppet.notice "Authenticating for #{@uri}"
      email = prompt('Email Address')
      password = prompt('Password', true)
      request.basic_auth(email, password)
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
  end
end
