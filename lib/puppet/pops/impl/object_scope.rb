# An ObjectScope wraps an ecore object and makes all structural features
# (i.e. attributes, containments and references) available as variables in the context).
# It is not possible to change these values. New variables can be introduced.
# Locking is performed by thread and object to ensure that an error is given if access to
# a variable reenters lookup of the same variable (i.e. if the value is self referential).
#
class Puppet::Pops::Impl::ObjectScope < Puppet::Pops::Impl::BaseScope
  attr_reader :scoped_object
  def initialize obj, extra_vars_hash = {}, origin = nil
    raise "Internal Error: Object scope can only be used with modeled objects." unless obj.class.respond_to? :ecore
    super.initialize()
    @scoped_object = obj
    @@locks ||= {}
    # Set additional variables
    extra_vars_hash.each {|k,v| set_variable(k, v, origin) }
  end

  # Prevents variables representing an object feature from being set, else behaves as BaseScope
  def set_variable(name, value, origin=nil)
    feature = scoped_object.class.ecore.eAllStructuralFeatures.select {|f| f.name == name }
    raise "TODO: ImmutableError" if feature
    super.set_variable(name, value, origin)
  end

  # If name represents a feature, return its value, else behaves as BaseScope
  def get_variable(name, missing_value = nil)
    feature = scoped_object.class.ecore.eAllStructuralFeatures.select {|f| f.name == name }
    if feature
      # Protected against the potential call out to pops instructions that may recursively
      # attempt to get the same feature value (i.e, while computing the feature value itself).
      #
      begin
        lock(name)
        obj.send :"#{name}"
      ensure
        unlock(name)
      end
    else
      super.get_variable(name, missing_value)
    end
  end

  # TODO: Add to API ? (Starting to get many different types of scopes, do they all matter? or only top
  # NodeScope (which is currently missing)...
  def is_object_scope?
    true
  end

  private

  # Locks the given name for this scope's object for the current thread.
  # The same name can not be locked when already locked; this is the reentrancy detection
  # and an exception is raised.
  # The caller of lock must call #unlock, or there will be memory leakage.
  def lock(name)
    if t = @@locks[Thread.current]
      if o = t[obj]
        if o[name]
          raise "TODO: Recursive computation  of #{obj.class}.#{name}"
        else
          o[name] = true
        end
      else
        t[obj] = {name => true}
      end
    else
      @@locks[Thread.current] = { obj => { name => true }}
    end
  end

  # Unlocks the given name for this scope's object for the current thread.
  # An exception is raised if unlocking something that was not locked.
  #
  def unlock(name)
    if t = @@locks[Thread.current] && o = t[obj] && o[name]
      o.delete(name)
      t.delete(obj) if o.size == 0
      @@locks.delete(Thread.current) if t.size == 0
    else
      raise "TODO: unlock without lock of #{obj.class}.#{name}"
    end
  end
end
