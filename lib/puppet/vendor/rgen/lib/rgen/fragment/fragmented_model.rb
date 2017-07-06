require 'rgen/instantiator/reference_resolver'

module RGen

module Fragment

# A FragmentedModel represents a model which consists of fragments (ModelFragment).
# 
# The main purpose of this class is to resolve references across fragments and
# to keep the references consistent while fragments are added or removed.
# This way it also plays an important role in keeping the model fragments consistent
# and thus ModelFragment objects should only be accessed via this interface.
# Overall unresolved references after the resolution step are also maintained.
#
# A FragmentedModel can also  keep an RGen::Environment object up to date while fragments
# are added or removed. The environment must be registered with the constructor.
#
# Reference resolution is based on arbitrary identifiers. The identifiers must be
# provided in the fragments' indices. The FragmentedModel takes care to maintain
# the overall index.
#
class FragmentedModel
  attr_reader :fragments
  attr_reader :environment

  # Creates a fragmented model. Options:
  #
  #  :env 
  #    environment which will be updated as model elements are added and removed
  #
  def initialize(options={})
    @environment = options[:env]
    @fragments = []
    @index = nil
    @fragment_change_listeners = []
    @fragment_index = {}
  end

  # Adds a proc which is called when a fragment is added or removed
  # The proc receives the fragment and one of :added, :removed
  #
  def add_fragment_change_listener(listener)
    @fragment_change_listeners << listener
  end

  def remove_fragment_change_listener(listener)
    @fragment_change_listeners.delete(listener)
  end

  # Add a fragment.
  #
  def add_fragment(fragment)
    invalidate_cache
    @fragments << fragment
    fragment.elements.each{|e| @environment << e} if @environment
    @fragment_change_listeners.each{|l| l.call(fragment, :added)}
  end

  # Removes the fragment. The fragment will be unresolved using unresolve_fragment.
  #
  def remove_fragment(fragment)
    raise "fragment not part of model" unless @fragments.include?(fragment)
    invalidate_cache
    @fragments.delete(fragment)
    @fragment_index.delete(fragment)
    unresolve_fragment(fragment)
    fragment.elements.each{|e| @environment.delete(e)} if @environment
    @fragment_change_listeners.each{|l| l.call(fragment, :removed)}
  end

  # Resolve references between fragments. 
  # It is assumed that references within fragments have already been resolved.
  # This method can be called several times. It will update the overall unresolved references.
  #
  # Options:
  #
  #  :fragment_provider:
  #    Only if a +fragment_provider+ is given, the resolve step can be reverted later on
  #    by a call to unresolve_fragment. The fragment provider is a proc which receives a model
  #    element and must return the fragment in which the element is contained.
  #
  #  :use_target_type:
  #    reference resolver uses the expected target type to narrow the set of possible targets 
  #
  def resolve(options={})
    local_index = index
    @fragments.each do |f|
      f.resolve_external(local_index, options)
    end
  end

  # Remove all references between this fragment and all other fragments.
  # The references will be replaced with unresolved references (MMProxy objects).
  #
  def unresolve_fragment(fragment)
    fragment.unresolve_external
    @fragments.each do |f|
      if f != fragment
        f.unresolve_external_fragment(fragment)
      end
    end
  end

  # Returns the overall unresolved references.
  #
  def unresolved_refs
    @fragments.collect{|f| f.unresolved_refs}.flatten
  end

  # Returns the overall index. 
  # This is a Hash mapping identifiers to model elements accessible via the identifier. 
  #
  def index
    fragments.each do |f|
      if !@fragment_index[f] || (@fragment_index[f].object_id != f.index.object_id)
        @fragment_index[f] = f.index
        invalidate_cache
      end
    end
    return @index if @index
    @index = {}
    fragments.each do |f|
      f.index.each do |i| 
        (@index[i[0]] ||= []) << i[1]
      end
    end
    @index
  end

  private

  def invalidate_cache
    @index = nil
  end

end

end

end
