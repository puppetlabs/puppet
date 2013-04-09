require 'net/http'
require 'open-uri'
require 'pathname'
require 'uri'
require 'puppet/forge/cache'
require 'puppet/forge/repository'
require 'puppet/forge/errors'

class Puppet::Forge
  include Puppet::Forge::Errors

  # +consumer_name+ is a name to be used for identifying the consumer of the
  # forge and +consumer_semver+ is a SemVer object to identify the version of
  # the consumer
  def initialize(consumer_name, consumer_semver)
    @consumer_name = consumer_name
    @consumer_semver = consumer_semver
  end

  # Return a list of module metadata hashes that match the search query.
  # This return value is used by the module_tool face install search,
  # and displayed to on the console.
  #
  # Example return value:
  #
  # [
  #   {
  #     "author"      => "puppetlabs",
  #     "name"        => "bacula",
  #     "tag_list"    => ["backup", "bacula"],
  #     "releases"    => [{"version"=>"0.0.1"}, {"version"=>"0.0.2"}],
  #     "full_name"   => "puppetlabs/bacula",
  #     "version"     => "0.0.2",
  #     "project_url" => "http://github.com/puppetlabs/puppetlabs-bacula",
  #     "desc"        => "bacula"
  #   }
  # ]
  #
  # @param term [String] search term
  # @return [Array] modules found
  # @raise [Puppet::Forge::Errors::CommunicationError] if there is a network
  #   related error
  # @raise [Puppet::Forge::Errors::SSLVerifyError] if there is a problem
  #   verifying the remote SSL certificate
  # @raise [Puppet::Forge::Errors::ResponseError] if the repository returns a
  #   bad HTTP response
  def search(term)
    server = Puppet.settings[:module_repository]
    Puppet.notice "Searching #{server} ..."
    response = repository.make_http_request("/modules.json?q=#{URI.escape(term)}")

    case response.code
    when "200"
      matches = PSON.parse(response.body)
    else
      raise ResponseError.new(:uri => uri.to_s, :input => term, :response => response)
    end

    matches
  end

  # Return a hash of releases of the requested module and all of its
  # dependencies. The keys in the hash are the forge module names
  # of the modules and the values are arrays containing release metadata
  # of each matching release of the respective module sorted by the version
  # in the descending order (from the newest to the oldest).
  #
  # Example return value:
  #
  # {
  #    "puppetlabs/mcollective" => [
  #       {
  #          "version" => "0.1.8",
  #          "dependencies" => [
  #             [
  #                "puppetlabs/stdlib",
  #                ">= 0.1.6"
  #             ]
  #          ],
  #          "file" => "/system/releases/p/puppetlabs/puppetlabs-mcollective-0.1.8.tar.gz",
  #       },
  #    ],
  #    "puppetlabs/stdlib" => [
  #       {
  #          "version" => "3.2.0",
  #          "dependencies" => [],
  #          "file" => "/system/releases/p/puppetlabs/puppetlabs-stdlib-3.2.0.tar.gz",
  #       },
  #       {
  #          "version" => "3.1.1",
  #          "dependencies" => [],
  #          "file" => "/system/releases/p/puppetlabs/puppetlabs-stdlib-3.1.1.tar.gz",
  #       },
  #    ],
  # }
  #
  # @param author [String] module's author name
  # @param mod_name [String] module name
  # @param version [String] optional module version number
  # @return [Hash] module and dependency metadata
  # @raise [Puppet::Forge::Errors::CommunicationError] if there is a network
  #   related error
  # @raise [Puppet::Forge::Errors::SSLVerifyError] if there is a problem
  #   verifying the remote SSL certificate
  # @raise [Puppet::Forge::Errors::ResponseError] if the repository returns
  #   an error in its API response or a bad HTTP response
  def remote_dependency_info(author, mod_name, version)
    version_string = version ? "&version=#{version}" : ''
    response = repository.make_http_request("/api/v1/releases.json?module=#{author}/#{mod_name}#{version_string}")
    json = PSON.parse(response.body) rescue {}
    case response.code
    when "200"
      return json
    else
      error = json['error']
      if error && error =~ /^Module #{author}\/#{mod_name} has no release/
        return []
      else
        raise ResponseError.new(:uri => uri.to_s, :input => "#{author}/#{mod_name}", :message => error, :response => response)
      end
    end
  end

  # Return the same structure as the +remote_dependency_info+ method but
  # possibly for multiple modules and their dependencies.
  #
  # @param modules [Array] modules to query the Forge for; each member
  #   of the Array is another Array where the first element is the forge
  #   name of a module and the second element is a version constraint
  #   on the module; example of the parameter value:
  #   [
  #   	["puppetlabs/nginx", ">= 0.0.1"],
  #   	["puppetlabs/ntp", "0.2.0"],
  #   ]
  # @return [Hash] module and dependency metadata
  # @raise [Puppet::Forge::Errors::CommunicationError] if there is a network
  #   related error
  # @raise [Puppet::Forge::Errors::SSLVerifyError] if there is a problem
  #   verifying the remote SSL certificate
  # @raise [Puppet::Forge::Errors::ResponseError] if the repository returns
  #   an error in its API response or a bad HTTP response
  def multiple_remote_dependency_info(modules)
    query_string = ''
    modules.each do |mod|
      query_string << "&module[]=#{mod.first}&version[]=#{mod.last}"
    end
    response = repository.make_http_request('/api/v1/releases.json?' << query_string[1..-1])
    json = PSON.parse(response.body) rescue {}
    case response.code
    when "200"
      return json
    else
      raise ResponseError.new(:uri => uri.to_s, :input => modules.map(&:first), :message => json['error'], :response => response)
    end
  end

  def get_release_packages_from_repository(install_list)
    install_list.map do |release|
      modname, version, file = release
      cache_path = nil
      if file
        begin
          cache_path = repository.retrieve(file)
        rescue OpenURI::HTTPError => e
          raise HttpResponseError.new(:uri => uri.to_s, :input => modname, :message => e.message)
        end
      else
        raise RuntimeError, "Malformed response from module repository."
      end
      cache_path
    end
  end

  # Locate a module release package on the local filesystem and move it
  # into the `Puppet.settings[:module_working_dir]`. Do not unpack it, just
  # return the location of the package on disk.
  def get_release_package_from_filesystem(filename)
    if File.exist?(File.expand_path(filename))
      repository = Repository.new('file:///')
      uri = URI.parse("file://#{URI.escape(File.expand_path(filename))}")
      cache_path = repository.retrieve(uri)
    else
      raise ArgumentError, "File does not exists: #{filename}"
    end

    cache_path
  end

  def retrieve(release)
    repository.retrieve(release)
  end

  def uri
    repository.uri
  end

  def repository
    version = "#{@consumer_name}/#{[@consumer_semver.major, @consumer_semver.minor, @consumer_semver.tiny].join('.')}#{@consumer_semver.special}"
    @repository ||= Puppet::Forge::Repository.new(Puppet[:module_repository], version)
  end
  private :repository
end
