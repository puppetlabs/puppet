  # Static Loader contains constants, basic data types and other types required for the system
  # to boot.
  #
class Puppet::Pops::Loader::StaticLoader < Puppet::Pops::Loader::Loader

  def load_typed(typed_name)
    load_constant(typed_name)
  end

  def get_entry(typed_name)
    load_constant(typed_name)
  end

  def find(name)
    # There is nothing to search for, everything this loader knows about is already available
    nil
  end

  def parent
    nil # at top of the hierarchy
  end

  def to_s()
    "(StaticLoader)"
  end
  private

  def load_constant(typed_name)
    # Move along, nothing to see here a.t.m...
    nil
  end
end
