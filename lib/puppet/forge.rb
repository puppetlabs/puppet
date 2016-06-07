require 'puppet/vendor'
Puppet::Vendor.load_vendored

require 'net/http'
require 'tempfile'
require 'uri'
require 'pathname'
require 'json'
require 'semantic'

class Puppet::Forge < Semantic::Dependency::Source
  require 'puppet/forge/cache'
  require 'puppet/forge/repository'
  require 'puppet/forge/errors'

  include Puppet::Forge::Errors

  USER_AGENT = "PMT/1.1.1 (v3; Net::HTTP)".freeze

  attr_reader :host, :repository

  def initialize(host = Puppet[:module_repository])
    @host = host
    @repository = Puppet::Forge::Repository.new(host, USER_AGENT)
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
  #     "project_url" => "https://github.com/puppetlabs/puppetlabs-bacula",
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
    matches = []
    uri = "/v3/modules?query=#{URI.escape(term)}"
    if Puppet[:module_groups]
      uri += "&module_groups=#{Puppet[:module_groups]}"
    end

    while uri
      response = make_http_request(uri)

      if response.code == '200'
        result = JSON.parse(response.body)
        uri = result['pagination']['next']
        matches.concat result['results']
      else
        raise ResponseError.new(:uri => URI.parse(@host).merge(uri), :response => response)
      end
    end

    matches.each do |mod|
      mod['author'] = mod['owner']['username']
      mod['tag_list'] = mod['current_release']['tags']
      mod['full_name'] = "#{mod['author']}/#{mod['name']}"
      mod['version'] = mod['current_release']['version']
      mod['project_url'] = mod['homepage_url']
      mod['desc'] = mod['current_release']['metadata']['summary'] || ''
    end
  end

  # Fetches {ModuleRelease} entries for each release of the named module.
  #
  # @param input [String] the module name to look up
  # @return [Array<Semantic::Dependency::ModuleRelease>] a list of releases for
  #         the given name
  # @see Semantic::Dependency::Source#fetch
  def fetch(input)
    name = input.tr('/', '-')
    uri = "/v3/releases?module=#{name}"
    if Puppet[:module_groups]
      uri += "&module_groups=#{Puppet[:module_groups]}"
    end
    releases = []

    while uri
      response = make_http_request(uri)

      if response.code == '200'
        response = JSON.parse(response.body)
      else
        raise ResponseError.new(:uri => URI.parse(@host).merge(uri), :response => response)
      end

      releases.concat(process(response['results']))
      uri = response['pagination']['next']
    end

    return releases
  end

  def make_http_request(*args)
    @repository.make_http_request(*args)
  end

  class ModuleRelease < Semantic::Dependency::ModuleRelease
    attr_reader :install_dir, :metadata

    def initialize(source, data)
      @data = data
      @metadata = meta = data['metadata']

      name = meta['name'].tr('/', '-')
      version = Semantic::Version.parse(meta['version'])
      release = "#{name}@#{version}"

      if meta['dependencies']
        dependencies = meta['dependencies'].collect do |dep|
          begin
            Puppet::ModuleTool::Metadata.new.add_dependency(dep['name'], dep['version_requirement'], dep['repository'])
            Puppet::ModuleTool.parse_module_dependency(release, dep)[0..1]
          rescue ArgumentError => e
            raise ArgumentError, "Malformed dependency: #{dep['name']}. Exception was: #{e}"
          end
        end
      else
        dependencies = []
      end

      super(source, name, version, Hash[dependencies])
    end

    def install(dir)
      staging_dir = self.prepare

      module_dir = dir + name[/-(.*)/, 1]
      module_dir.rmtree if module_dir.exist?

      # Make sure unpacked module has the same ownership as the folder we are moving it into.
      Puppet::ModuleTool::Applications::Unpacker.harmonize_ownership(dir, staging_dir)

      FileUtils.mv(staging_dir, module_dir)
      @install_dir = dir

      # Return the Pathname object representing the directory where the
      # module release archive was unpacked the to.
      return module_dir
    ensure
      staging_dir.rmtree if staging_dir.exist?
    end

    def prepare
      return @unpacked_into if @unpacked_into

      download(@data['file_uri'], tmpfile)
      validate_checksum(tmpfile, @data['file_md5'])
      unpack(tmpfile, tmpdir)

      @unpacked_into = Pathname.new(tmpdir)
    end

    private

    # Obtain a suitable temporary path for unpacking tarballs
    #
    # @return [Pathname] path to temporary unpacking location
    def tmpdir
      @dir ||= Dir.mktmpdir(name, Puppet::Forge::Cache.base_path)
    end

    def tmpfile
      @file ||= Tempfile.new(name, Puppet::Forge::Cache.base_path).tap do |f|
        f.binmode
      end
    end

    def download(uri, destination)
      response = @source.make_http_request(uri, destination)
      destination.flush and destination.close
      unless response.code == '200'
        raise Puppet::Forge::Errors::ResponseError.new(:uri => uri, :response => response)
      end
    end

    def validate_checksum(file, checksum)
      if Digest::MD5.file(file.path).hexdigest != checksum
        raise RuntimeError, "Downloaded release for #{name} did not match expected checksum"
      end
    end

    def unpack(file, destination)
      begin
        Puppet::ModuleTool::Applications::Unpacker.unpack(file.path, destination)
      rescue Puppet::ExecutionFailure => e
        raise RuntimeError, "Could not extract contents of module archive: #{e.message}"
      end
    end
  end

  private

  def process(list)
    l = list.map do |release|
      metadata = release['metadata']
      begin
        ModuleRelease.new(self, release)
      rescue ArgumentError => e
        Puppet.warning "Cannot consider release #{metadata['name']}-#{metadata['version']}: #{e}"
        false
      end
    end

    l.select { |r| r }
  end
end
