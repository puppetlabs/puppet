# Setting variables is allowed, but these are never propagated outside of this scope
# (They can not be referenced from the outside). All other types settings are propagated to the
# parent scope.
#
class Puppet::Pops::Impl::LocalScope < Puppet::Pops::Impl::BaseScope
  include Puppet::Pops::API::Utils
  Utils = Puppet::Pops::API::Utils
  def is_local_scope?
    true
  end

  # Sets variables in this scope, all other in parent scope
  def set_data(type, name, value, origin = nil)
    parent_scope.set(type, name, value, origin)
  end

  # All data is set in parent scope
  def get_data_entry(type, name)
    parent_scope.get_variable_entry(type, name)
  end

  # Variables are looked up, first in this scope, then in parent if no entry found here
  # If a name is absolute the lookup is always done in the parent
  def get_variable_entry(name)
    if !Utils.is_absolute?(name) && entry = super
      entry
    else
      parent_scope.get_variable_entry(name)
    end
  end
end
