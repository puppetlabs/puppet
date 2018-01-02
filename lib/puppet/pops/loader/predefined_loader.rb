module Puppet::Pops::Loader

# A PredefinedLoader is a loader that is manually populated with loaded elements
# before being used. It never loads anything on its own.
#
class PredefinedLoader < BaseLoader
  def find(typed_name)
    nil
  end

  def to_s()
    "(PredefinedLoader '#{loader_name}')"
  end

  # Allows shadowing since this loader is used internally for things like function local types
  # And they should win as there is otherwise a risk that the local types clash with built in types
  # that were added after the function was written, or by resource types loaded by the 3x auto loader.
  #
  def allow_shadowing?
    true
  end
end

end
