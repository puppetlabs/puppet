require 'rgen/instantiator/resolution_helper'

module RGen

module Instantiator

# The ReferenceResolver can be used to resolve unresolved references, i.e. instances
# of class UnresolvedReference
#
# There are two ways how this can be used:
#  1. the identifiers and associated model elements are added upfront using +add_identifier+
#  2. register an :identifier_resolver with the constructor, which will be invoked 
#     for every unresolved identifier
#
class ReferenceResolver
 
  # Instances of this class represent information about not yet resolved references.
  # This consists of the +element+ and metamodel +feature_name+ which hold/is to hold the 
  # reference and the +proxy+ object which is the placeholder for the reference.
  # If the reference could not be resolved because the target type does not match the
  # feature type, the flag +target_type_error+ will be set.
  #
  class UnresolvedReference 
    attr_reader :feature_name, :proxy
    attr_accessor :element, :target_type_error
    def initialize(element, feature_name, proxy)
      @element = element
      @feature_name = feature_name
      @proxy = proxy
    end
  end

  # Create a reference resolver, options:
  #
  #  :identifier_resolver:
  #    a proc which is called with an identifier and which should return the associated element
  #    in case the identifier is not uniq, the proc may return multiple values
  #    default: lookup element in internal map
  #
  def initialize(options={})
    @identifier_resolver = options[:identifier_resolver]
    @identifier_map = {}
  end

  # Add an +identifer+ / +element+ pair which will be used for looking up unresolved identifers
  def add_identifier(ident, element)
    map_entry = @identifier_map[ident]
    if map_entry 
      if map_entry.is_a?(Array)
        map_entry << element
      else
        @identifier_map[ident] = [map_entry, element]
      end
    else 
      @identifier_map[ident] = element
    end
  end

  # Tries to resolve the given +unresolved_refs+. If resolution is successful, the proxy object
  # will be removed, otherwise there will be an error description in the problems array.
  # In case the resolved target element's type is not valid for the given feature, the 
  # +target_type_error+ flag will be set on the unresolved reference.
  # Returns an array of the references which are still unresolved. Options:
  # 
  #  :problems
  #    an array to which problems will be appended
  #
  #  :on_resolve
  #    a proc which will be called for every sucessful resolution, receives the unresolved
  #    reference as well as to new target element
  #
  #  :use_target_type
  #    use the expected target type to narrow the set of possible targets 
  #    (i.e. ignore targets with wrong type)
  #
  #  :failed_resolutions
  #    a Hash which will receive an entry for each failed resolution for which at least one
  #    target element was found (wrong target type, or target not unique).
  #    hash key is the uref, hash value is the target element or the Array of target elements
  #
  def resolve(unresolved_refs, options={})
    problems = options[:problems] || []
    still_unresolved_refs = []
    failed_resolutions = options[:failed_resolutions] || {}
    unresolved_refs.each do |ur|
      if @identifier_resolver
        target = @identifier_resolver.call(ur.proxy.targetIdentifier)
      else
        target = @identifier_map[ur.proxy.targetIdentifier]
      end
      target = [target].compact unless target.is_a?(Array)
      if options[:use_target_type] 
        feature = ur.element.class.ecore.eAllReferences.find{|r| r.name == ur.feature_name}
        target = target.select{|e| e.is_a?(feature.eType.instanceClass)}
      end
      if target.size == 1
        status = ResolutionHelper.set_uref_target(ur, target[0])
        if status == :success
          options[:on_resolve] && options[:on_resolve].call(ur, target[0])
        elsif status == :type_error
          ur.target_type_error = true
          problems << type_error_message(target[0])
          still_unresolved_refs << ur
          failed_resolutions[ur] = target[0]
        end
      elsif target.size > 1
        problems << "identifier #{ur.proxy.targetIdentifier} not uniq"
        still_unresolved_refs << ur
        failed_resolutions[ur] = target
      else
        problems << "identifier #{ur.proxy.targetIdentifier} not found"
        still_unresolved_refs << ur
      end
    end
    still_unresolved_refs
  end   

  private

  def type_error_message(target)
    "invalid target type #{target.class}"
  end

end

end

end
