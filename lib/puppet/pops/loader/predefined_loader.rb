module Puppet::Pops::Loader

# A PredefinedLoader is a loader that is manually populated with loaded elements
# before being used. It never loads anything on its own.
# When searching for a type, it must exist or an error is raised
#
class PredefinedLoader < BaseLoader
  def find(typed_name)
    if typed_name.type == :type
      raise Puppet::Pops::Loaders::LoaderError, "Cannot load undefined type '#{typed_name.name.capitalize}'"
    else
      nil
    end
  end

  def to_s()
    "(PredefinedLoader '#{loader_name}')"
  end

end

end
