class Puppet::Pops::Loaders

  attr_reader :static_loader
  attr_reader :puppet_system_loader
  attr_reader :environment_loader

  def initialize()
    # The static loader can only be changed after a reboot
    @@static_loader ||= Puppet::Pops::Loader::StaticLoader.new()

    # Create the set of loaders
    # 1. Puppet, loads from the "running" puppet - i.e. bundled functions, types, extension points and extensions
    #    Does not change without rebooting the service running puppet.
    #
    @@puppet_system_loader ||= create_puppet_system_loader()

    # 2. Environment loader - i.e. what is bound across the environment, may change for each setup
    #    TODO: loaders need to work when also running in an agent doing catalog application. There is no
    #    concept of environment the same way as when running as a master (except when doing apply).
    #    The creation mechanisms should probably differ between the two.
    #
    @environment_loader = create_environment_loader()

    # 3. module loaders are set up from the create_environment_loader, they register themselves
  end

  # Clears the cached static and puppet_system loaders (to enable testing)
  #
  def self.clear
    @@static_loader = nil
    @@puppet_system_loader = nil
  end

  def static_loader
    @@static_loader
  end

  def puppet_system_loader
    @@puppet_system_loader
  end

  def self.create_loaders()
    self.new()
  end

  private

  def create_puppet_system_loader()
    module_name = nil
    loader_name = 'puppet_system'

    # Puppet system may be installed in a fixed location via RPM, installed as a Gem, via source etc.
    # The only way to find this across the different ways puppet can be installed is
    # to search up the path from this source file's __FILE__ location until it finds the parent of
    # lib/puppet... e.g.. dirname(__FILE__)/../../..  (i.e. <somewhere>/lib/puppet/pops/loaders.rb).
    #
    puppet_lib = File.join(File.dirname(__FILE__), '../../..')
    Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, module_name, puppet_lib, loader_name)
  end

  def create_environment_loader()
    # This defines where to start parsing/evaluating - the "initial import" (to use 3x terminology)
    # Is either a reference to a single .pp file, or a directory of manifests. If the environment becomes
    # a module and can hold functions, types etc. then these are available across all other modules without
    # them declaring this dependency - it is however valuable to be able to treat it the same way
    # bindings and other such system related configuration.

    # This is further complicated by the many options available:
    # - The environment may not have a directory, the code comes from one appointed 'manifest' (site.pp)
    # - The environment may have a directory and also point to a 'manifest'
    # - The code to run may be set in settings (code)

    # Further complication is that there is nothing specifying what the visibility is into
    # available modules. (3x is everyone sees everything).
    # Puppet binder currently reads confdir/bindings - that is bad, it should be using the new environment support.

    current_environment = Puppet.lookup(:current_environment)
    # The environment is not a namespace, so give it a nil "module_name"
    module_name = nil
    loader_name = "environment:#{current_environment.name}"
    env_dir = Puppet[:environmentdir]
    if env_dir.nil?
      loader = Puppet::Pops::Loader::NullLoader.new(puppet_system_loader, loader_name)
    else
      envdir_path = File.join(env_dir, current_environment.name.to_s)
      # TODO: Representing Environment as a Module - needs something different (not all types are supported),
      # and it must be able to import .pp code from 3x manifest setting, or from code setting as well as from
      # a manifests directory under the environment's root. The below is cheating...
      #
      loader = Puppet::Pops::Loader::ModuleLoaders::FileBased(puppet_system_loader, module_name, envdir_path, loader_name)
    end
    # An environment has a module path even if it has a null loader
    configure_loaders_for_modulepath(loader, current_environment.modulepath)
    loader
  end

  def configure_loaders_for_modulepath(loader, modulepath)
    # TODO: For each module on the modulepath, create a lazy loader
    # TODO: Register the module's external and internal loaders (the loader for the module itself, and the loader
    #       for its dependencies.
  end
end