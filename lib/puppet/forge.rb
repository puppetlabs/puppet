# frozen_string_literal: true
require_relative '../puppet/vendor'
Puppet::Vendor.load_vendored

require 'net/http'
require 'tempfile'
require 'uri'
require 'pathname'
require_relative '../puppet/util/json'
require 'semantic_puppet'

class Puppet::Forge < SemanticPuppet::Dependency::Source
  require_relative 'forge/cache'
  require_relative 'forge/repository'
  require_relative 'forge/errors'

  include Puppet::Forge::Errors

  USER_AGENT = "PMT/1.1.1 (v3; Net::HTTP)"

  # From https://forgeapi.puppet.com/#!/release/getReleases
  MODULE_RELEASE_EXCLUSIONS=%w[readme changelog license uri module tags supported file_size downloads created_at updated_at deleted_at].join(',').freeze

  attr_reader :host, :repository

  def initialize(host = Puppet[:module_repository])
    super()
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
    uri = "/v3/modules?query=#{term}"
    if Puppet[:module_groups]
      uri += "&module_groups=#{Puppet[:module_groups].tr('+', ' ')}"
    end

    while uri
      # make_http_request URI encodes parameters
      response = make_http_request(uri)

      if response.code == 200
        result = Puppet::Util::Json.load(response.body)
        uri = decode_uri(result['pagination']['next'])
        matches.concat result['results']
      else
        raise ResponseError.new(:uri => response.url, :response => response)
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
  # @return [Array<SemanticPuppet::Dependency::ModuleRelease>] a list of releases for
  #         the given name
  # @see SemanticPuppet::Dependency::Source#fetch
  def fetch(input)
    name = input.tr('/', '-')
    uri = "/v3/releases?module=#{name}&sort_by=version&exclude_fields=#{MODULE_RELEASE_EXCLUSIONS}"
    if Puppet[:module_groups]
      uri += "&module_groups=#{Puppet[:module_groups].tr('+', ' ')}"
    end
    releases = []

    while uri
      # make_http_request URI encodes parameters
      response = make_http_request(uri)

      if response.code == 200
        response = Puppet::Util::Json.load(response.body)
      else
        raise ResponseError.new(:uri => response.url, :response => response)
      end

      releases.concat(process(response['results']))
      uri = decode_uri(response['pagination']['next'])
    end

    return releases
  end

  def make_http_request(*args)
    @repository.make_http_request(*args)
  end

  class ModuleRelease < SemanticPuppet::Dependency::ModuleRelease
    attr_reader :install_dir, :metadata

    def initialize(source, data)
      @data = data
      @metadata = meta = data['metadata']

      name = meta['name'].tr('/', '-')
      version = SemanticPuppet::Version.parse(meta['version'])
      release = "#{name}@#{version}"

      if meta['dependencies']
        dependencies = meta['dependencies'].collect do |dep|
          begin
            Puppet::ModuleTool::Metadata.new.add_dependency(dep['name'], dep['version_requirement'], dep['repository'])
            Puppet::ModuleTool.parse_module_dependency(release, dep)[0..1]
          rescue ArgumentError => e
            raise ArgumentError, _("Malformed dependency: %{name}.") % { name: dep['name'] } +
                ' ' + _("Exception was: %{detail}") % { detail: e }
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

      Puppet.warning "#{@metadata['name']} has been deprecated by its author! View module on Puppet Forge for more info." if deprecated?

      download(@data['file_uri'], tmpfile)
      checksum = @data['file_sha256']
      if checksum
        validate_checksum(tmpfile, checksum, Digest::SHA256)
      else
        checksum = @data['file_md5']
        if checksum
          validate_checksum(tmpfile, checksum, Digest::MD5)
        else
          raise _("Forge module is missing SHA256 and MD5 checksums")
        end
      end

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
      unless response.code == 200
        raise Puppet::Forge::Errors::ResponseError.new(:uri => response.url, :response => response)
      end
    end

    def validate_checksum(file, checksum, digest_class)
      if Puppet.runtime[:facter].value(:fips_enabled) && digest_class == Digest::MD5
        raise _("Module install using MD5 is prohibited in FIPS mode.")
      end

      if digest_class.file(file.path).hexdigest != checksum
        raise RuntimeError, _("Downloaded release for %{name} did not match expected checksum %{checksum}") % { name: name, checksum: checksum }
      end
    end

    def unpack(file, destination)
      begin
        Puppet::ModuleTool::Applications::Unpacker.unpack(file.path, destination)
      rescue Puppet::ExecutionFailure => e
        raise RuntimeError, _("Could not extract contents of module archive: %{message}") % { message: e.message }
      end
    end

    def deprecated?
      @data['module'] && (@data['module']['deprecated_at'] != nil)
    end
  end

  private

  def process(list)
    l = list.map do |release|
      metadata = release['metadata']
      begin
        ModuleRelease.new(self, release)
      rescue ArgumentError => e
        Puppet.warning _("Cannot consider release %{name}-%{version}: %{error}") % { name: metadata['name'], version: metadata['version'], error: e }
        false
      end
    end

    l.select { |r| r }
  end

  def decode_uri(uri)
    return if uri.nil?

    Puppet::Util.uri_unescape(uri.tr('+', ' '))
  end
end
