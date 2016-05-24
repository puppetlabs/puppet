# The null loader is empty and delegates everything to its parent if it has one.
#
class Puppet::Pops::Loader::NullLoader < Puppet::Pops::Loader::Loader
  attr_reader :loader_name

  # Construct a NullLoader, optionally with a parent loader
  #
  def initialize(parent_loader=nil, loader_name = "null-loader")
    @loader_name = loader_name
    @parent = parent_loader
  end

  # Has parent if one was set when constructed
  def parent
    @parent
  end

  def find(typed_name)
    if @parent.nil?
      nil
    else
      @parent.find(typed_name)
    end
  end

  def load_typed(typed_name)
    if @parent.nil?
      nil
    else
      @parent.load_typed(typed_name)
    end
  end

  def loaded_entry(typed_name, check_dependencies = false)
    if @parent.nil?
      nil
    else
      @parent.loaded_entry(typed_name, check_dependencies)
    end
  end

  # Has no entries on its own - always nil
  def get_entry(typed_name)
    nil
  end

  # Finds nothing, there are no entries
  def find(name)
    nil
  end

  # Cannot store anything
  def set_entry(typed_name, value, origin = nil)
    nil
  end

  def to_s()
    "(NullLoader '#{loader_name}')"
  end
end