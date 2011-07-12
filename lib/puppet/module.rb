require 'puppet/util/logging'

# Support for modules
class Puppet::Module
  class Error < Puppet::Error; end
  class MissingModule < Error; end
  class IncompatibleModule < Error; end
  class UnsupportedPlatform < Error; end
  class IncompatiblePlatform < Error; end
  class MissingMetadata < Error; end
  class InvalidName < Error; end

  include Puppet::Util::Logging

  TEMPLATES = "templates"
  FILES = "files"
  MANIFESTS = "manifests"
  PLUGINS = "plugins"

  FILETYPES = [MANIFESTS, FILES, TEMPLATES, PLUGINS]

  # Return an array of paths by splitting the +modulepath+ config
  # parameter. Only consider paths that are absolute and existing
  # directories
  def self.modulepath(environment = nil)
    Puppet::Node::Environment.new(environment).modulepath
  end

  # Find and return the +module+ that +path+ belongs to. If +path+ is
  # absolute, or if there is no module whose name is the first component
  # of +path+, return +nil+
  def self.find(modname, environment = nil)
    return nil unless modname
    Puppet::Node::Environment.new(environment).module(modname)
  end

  attr_reader :name, :environment
  attr_writer :environment

  attr_accessor :source, :author, :version, :license, :puppetversion, :summary, :description, :project_page

  def has_metadata?
    return false unless metadata_file

    return false unless FileTest.exist?(metadata_file)

    metadata = PSON.parse File.read(metadata_file)
    return metadata.is_a?(Hash) && !metadata.keys.empty?
  end

  def initialize(name, environment = nil)
    @name = name

    assert_validity

    if environment.is_a?(Puppet::Node::Environment)
      @environment = environment
    else
      @environment = Puppet::Node::Environment.new(environment)
    end

    load_metadata if has_metadata?

    validate_puppet_version
    validate_dependencies
  end

  FILETYPES.each do |type|
    # A boolean method to let external callers determine if
    # we have files of a given type.
    define_method(type +'?') do
      return false unless path
      return false unless FileTest.exist?(subpath(type))
      return true
    end

    # A method for returning a given file of a given type.
    # e.g., file = mod.manifest("my/manifest.pp")
    #
    # If the file name is nil, then the base directory for the
    # file type is passed; this is used for fileserving.
    define_method(type.to_s.sub(/s$/, '')) do |file|
      return nil unless path

      # If 'file' is nil then they're asking for the base path.
      # This is used for things like fileserving.
      if file
        full_path = File.join(subpath(type), file)
      else
        full_path = subpath(type)
      end

      return nil unless FileTest.exist?(full_path)
      return full_path
    end
  end

  def exist?
    ! path.nil?
  end

  # Find the first 'files' directory.  This is used by the XMLRPC fileserver.
  def file_directory
    subpath("files")
  end

  def license_file
    return @license_file if defined?(@license_file)

    return @license_file = nil unless path
    @license_file = File.join(path, "License")
  end

  def load_metadata
    data = PSON.parse File.read(metadata_file)
    [:source, :author, :version, :license, :puppetversion].each do |attr|
      unless value = data[attr.to_s]
        unless attr == :puppetversion
          raise MissingMetadata, "No #{attr} module metadata provided for #{self.name}"
        end
      end
      send(attr.to_s + "=", value)
    end
  end

  # Return the list of manifests matching the given glob pattern,
  # defaulting to 'init.{pp,rb}' for empty modules.
  def match_manifests(rest)
    pat = File.join(path, MANIFESTS, rest || 'init')
    [manifest("init.pp"),manifest("init.rb")].compact + Dir.
      glob(pat + (File.extname(pat).empty? ? '.{pp,rb}' : '')).
      reject { |f| FileTest.directory?(f) }
  end

  def metadata_file
    return @metadata_file if defined?(@metadata_file)

    return @metadata_file = nil unless path
    @metadata_file = File.join(path, "metadata.json")
  end

  # Find this module in the modulepath.
  def path
    environment.modulepath.collect { |path| File.join(path, name) }.find { |d| FileTest.directory?(d) }
  end

  # Find all plugin directories.  This is used by the Plugins fileserving mount.
  def plugin_directory
    subpath("plugins")
  end

  def requires(name, version = nil)
    @requires ||= []
    @requires << [name, version]
  end

  def supports(name, version = nil)
    @supports ||= []
    @supports << [name, version]
  end

  def to_s
    result = "Module #{name}"
    result += "(#{path})" if path
    result
  end

  def validate_dependencies
    return unless defined?(@requires)

    @requires.each do |name, version|
      unless mod = environment.module(name)
        raise MissingModule, "Missing module #{name} required by #{self.name}"
      end

      if version and mod.version != version
        raise IncompatibleModule, "Required module #{name} is version #{mod.version} but #{self.name} requires #{version}"
      end
    end
  end

  def validate_puppet_version
    return unless puppetversion and puppetversion != Puppet.version
    raise IncompatibleModule, "Module #{self.name} is only compatible with Puppet version #{puppetversion}, not #{Puppet.version}"
  end

  private

  def subpath(type)
    return File.join(path, type) unless type.to_s == "plugins"

    backward_compatible_plugins_dir
  end

  def backward_compatible_plugins_dir
    if dir = File.join(path, "plugins") and FileTest.exist?(dir)
      Puppet.warning "using the deprecated 'plugins' directory for ruby extensions; please move to 'lib'"
      return dir
    else
      return File.join(path, "lib")
    end
  end

  def assert_validity
    raise InvalidName, "Invalid module name; module names must be alphanumeric (plus '-'), not '#{name}'" unless name =~ /^[-\w]+$/
  end
end
