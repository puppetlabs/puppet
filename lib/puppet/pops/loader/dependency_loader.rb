# =DependencyLoader
# This loader provides visibility into a set of other loaders. It is used as a child of a ModuleLoader (or other
# loader) to make its direct dependencies visible for loading from contexts that have access to this dependency loader.
# Access is typically given to logic that resides inside of the module, but not to those that just depend on the module.
#
# It is instantiated with a name, and with a set of dependency_loaders.
#
# @api private
#
class Puppet::Pops::Loader::DependencyLoader < Puppet::Pops::Loader::BaseLoader

  # An index of module_name to module loader used to speed up lookup of qualified names
  attr_reader :index

  # Creates a DependencyLoader for one parent loader
  #
  # @param parent_loader [Puppet::Pops::Loader] typically a module loader for the root
  # @param name [String] the name of the dependency-loader (used for debugging and tracing only)
  # @param dependency_loaders [Array<Puppet::Pops::Loader>] array of loaders for modules this module depends on
  #
  def initialize(parent_loader, name, dependency_loaders)
    super parent_loader, name
    @dependency_loaders = dependency_loaders
  end

  def discover(type, error_collector = nil, name_authority = Puppet::Pops::Pcore::RUNTIME_NAME_AUTHORITY, &block)
    result = []
    @dependency_loaders.each { |loader| result.concat(loader.discover(type, error_collector, name_authority, &block)) }
    result.concat(super)
    result
  end

  # Finds name in a loader this loader depends on / can see
  #
  def find(typed_name)
    if typed_name.qualified?
      if l = index()[typed_name.name_parts[0]]
        l.load_typed(typed_name)
      else
        # no module entered as dependency with name matching first segment of wanted name
        nil
      end
    else
      # a non name-spaced name, have to search since it can be anywhere.
      # (Note: superclass caches the result in this loader as it would have to repeat this search for every
      # lookup otherwise).
      loaded = @dependency_loaders.reduce(nil) do |previous, loader|
        break previous if !previous.nil?
        loader.load_typed(typed_name)
      end
      if loaded
        promote_entry(loaded)
      end
      loaded
    end
  end

  # @api public
  #
  def loaded_entry(typed_name, check_dependencies = false)
    super || (check_dependencies ? loaded_entry_in_dependency(typed_name, check_dependencies) : nil)
  end

  def to_s
    "(DependencyLoader '#{@loader_name}' [" + @dependency_loaders.map {|loader| loader.to_s }.join(' ,') + "])"
  end

  private

  def loaded_entry_in_dependency(typed_name, check_dependencies)
    if typed_name.qualified?
      if l = index[typed_name.name_parts[0]]
        l.loaded_entry(typed_name)
      else
        # no module entered as dependency with name matching first segment of wanted name
        nil
      end
    else
      # a non name-spaced name, have to search since it can be anywhere.
      # (Note: superclass caches the result in this loader as it would have to repeat this search for every
      # lookup otherwise).
      @dependency_loaders.reduce(nil) do |previous, loader|
        break previous if !previous.nil?
        loader.loaded_entry(typed_name, check_dependencies)
      end
    end
  end

  def index
    @index ||= @dependency_loaders.reduce({}) { |index, loader| index[loader.module_name] = loader; index }
  end
end
