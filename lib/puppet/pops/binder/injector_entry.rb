# Represents an entry in the injectors internal data.
#
# @api private
#
class Puppet::Pops::Binder::InjectorEntry
  attr :precedence
  attr :binding
  attr :resolved
  attr :cached
  attr :cached_producer

  # @api private
  def initialize(precedence, binding)
    @precedence = precedence
    @binding = binding
    @cached = nil
    @cached_producer = nil
  end

  # Marks an overriding entry as resolved (if not an overriding entry, the marking has no effect).
  # @api private
  #
  def mark_override_resolved()
    @resolved = true
  end

  # The binding is resolved if it is non-override, or if the override has been resolved
  # @api private
  #
  def is_resoved?()
    !binding.override || resolved
  end
end
