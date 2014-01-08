# Represents an entry in the injectors internal data.
#
# @api public
#
class Puppet::Pops::Binder::InjectorEntry
  # @return [Object] An opaque (comparable) object representing the precedence
  # @api public
  attr_reader :precedence

  # @return [Puppet::Pops::Binder::Bindings::Binding] The binding for this entry
  # @api public
  attr_reader :binding

  # @api private
  attr_accessor :resolved

  # @api private
  attr_accessor :cached_producer

  # @api private
  def initialize(binding, precedence = 0)
    @precedence = precedence.freeze
    @binding = binding
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
  def is_resolved?()
    !binding.override || resolved
  end

  def is_abstract?
    binding.abstract
  end

  def is_final?
    binding.final
  end

  # Compares against another InjectorEntry by comparing precedence.
  # @param injector_entry [InjectorEntry] entry to compare against.
  # @return [Integer] 1, if this entry has higher precedence, 0 if equal, and -1 if given entry has higher precedence.
  # @api public
  #
  def <=> (injector_entry)
    precedence <=> injector_entry.precedence
  end
end
