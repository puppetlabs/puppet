# SimpleEnvironmentLoader
# ===
# This loader does not load anything and it is populated by the bootstrapping logic that loads
# the site.pp or equivalent for an environment. It does not restrict the names of what it may contain,
# and what is loaded here overrides any child loaders (modules).
#
class Puppet::Pops::Loader::SimpleEnvironmentLoader < Puppet::Pops::Loader::BaseLoader

  attr_accessor :private_loader

  # Never finds anything, everything "loaded" is set externally
  def find(typed_name)
    nil
  end

  def to_s()
    "(SimpleEnvironmentLoader '#{loader_name}')"
  end

end
