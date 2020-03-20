# A project is a special type of environment used for developing Bolt content. 
class Puppet::Node::BoltProject < Puppet::Node::Environment
  # Create a new project with the given name
  #
  # @param name [Symbol] the name of the project
  # @param path [String] the absolute path to the project
  # @param modulepath [Array<String>] the list of paths from which to load modules
  # @param manifest [String] the path to the manifest for the environment or
  #   the constant Puppet::Node::Environment::NO_MANIFEST if there is none.
  # @param config_version [String] path to a script whose output will be added
  #   to report logs (optional)
  # @return [Puppet::Node::Environment]
  #
  # @api public
  def self.create(name, path, modulepath, manifest = NO_MANIFEST, config_version = nil)
    new(name, path, modulepath, manifest, config_version)
  end

  # Instantiate a new project
  #
  # @param name [Symbol] The environment name
  # @param path [String] the absolute path to the project
  def initialize(name, path, modulepath, manifest, config_version)
    @path = path
    @lock = Puppet::Concurrent::Lock.new
    @name = name.intern
    @modulepath = self.class.expand_dirs(self.class.extralibs() + modulepath)
    @manifest = manifest == NO_MANIFEST ? manifest : Puppet::FileSystem.expand_path(manifest)
    @config_version = config_version
  end

  # Return all modules for the project in the order they appear in the
  # modulepath.
  # @note If multiple modules with the same name are present they will
  #   both be added, but methods like {#module} and {#module_by_forge_name}
  #   will return the first matching entry in this list.
  # @note This value is cached so that the filesystem doesn't have to be
  #   re-enumerated every time this method is invoked, since that
  #   enumeration could be a costly operation and this method is called
  #   frequently. The cache expiry is determined by `Puppet[:filetimeout]`.
  # @api public
  # @return [Array<Puppet::Module>] All modules for this environment
  def modules 
    if @modules.nil?
      module_references = []
      seen_modules = {}

      # This cannot have a duplicate name with boltlib modules, so it's safe to
      # put it at the front of the modulepath
      project_name = File.basename(@path)
      module_references << {:name => project_name, :path => @path }
      seen_modules[project_name] = true

      modulepath.each do |path|
        Dir.entries(path).each do |name|
          next unless Puppet::Module.is_module_directory?(name, path)
          warn_about_mistaken_path(path, name)
          if not seen_modules[name]
            module_references << {:name => name, :path => File.join(path, name)}
            seen_modules[name] = true
          end
        end
      end
      @modules = module_references.collect do |reference|
        begin
          Puppet::Module.new(reference[:name], reference[:path], self)
        rescue Puppet::Module::Error => e
          Puppet.log_exception(e)
          nil
        end
      end.compact
    end
    @modules
  end
end
