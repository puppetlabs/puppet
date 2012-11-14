require 'puppet/pops/impl/loader/base_loader'
require 'dir'
require 'file'

# =ModuleLoader
# A ModuleLoader loads items from a single module. 
# It is instantiated with a name, a path to its root, and with a set of dependency_loaders.
# A ModuleLoader does not directly support gem: URI scheme as it is expected that the configuration
# of all module loaders is performed by a ModuleLoaderConfigurator (which is aware of different schemes).
#
class ModuleLoader < Pupet::Pops::Impl::Loader::BaseLoader
  Subpaths = '{types,functions,manifests}'
  Extensions = '.{pp}'
  
  # Create a ModuleLoader for one module
  # The parameters are:
  # * parent_loader - typically the loader for the root
  # * name - the name of the module (non qualified name)
  # * path - the path to the root of the module (the directory where ./manifests are).
  # * depedency_loaders - array of loaders for modules this module depends on
  #
  def initialize parent_loader, name, path, dependency_loaders
    super parent_loader
    @name = name
    @path = path
    @dependency_loaders = dependency_loaders
    @loaded_files = Set.new
  end

  # Finds name in this module, or in a module this module depends on
  # Produces nil, if not found.
  # Loaded files are not loaded again
  #
  def find(name, executor)
    # relativize
    name = name[2..-1] if name.start_with?("::")
    # All potential files 
    matching_files = files_for_name(name)
    # Run the first existing file unless it has already been executed
    if found_index = matching_files.index {|f| File.file? f }
      f = matching_files[found_index]
      unless @loaded_files.include? f
        executor.run_file(f, self)
        @loaded_files.add(f)
        # do not give up here if not found, in the future there may be fragments/extensions to search
      end
    end
    # was it loaded ?
    found = self[name]
    # if not, find among dependencies (first non nil produced value)
    found ||= @dependency_loaders.reduce(nil) do |v, loader|
      break v if v
      loader.load(name, executor)
    end
  end  
  
  protected
  
  # Produces a directory listing of all matching file-names (different possible locations and extensions)
  # 
  def files_for_name name
    if name == @name
      Dir[File.join(@path, '/manifests/init.'+Extensions)]
    else
      Dir[File.join(@path, Subpaths, name_to_ls(name))]
    end
  end
  
  # Produces a name that can be used in a Dir[#name_to_ls] to produce an array of matching
  # filenames (having one of the supported extensions).
  #
  def name_to_ls name
    File.join(name.split("::"))+Extensions
  end
end