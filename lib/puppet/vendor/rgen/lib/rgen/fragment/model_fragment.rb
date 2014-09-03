require 'rgen/instantiator/reference_resolver'

module RGen

module Fragment

# A model fragment is a list of root model elements associated with a location (e.g. a file).
# It also stores a list of unresolved references as well as a list of unresolved references
# which have been resolved. Using the latter, a fragment can undo reference resolution.
#
# Optionally, an arbitrary data object may be associated with the fragment. The data object
# will also be stored in the cache.
#
# If an element within the fragment changes this must be indicated to the fragment by calling
# +mark_changed+. 
#
# Note: the fragment knows how to resolve references (+resolve_local+, +resolve_external+).
# However considering a fragment a data structure, this functionality might be removed in the
# future. Instead the fragment should be told about each resolution taking place. Use 
# method +mark_resolved+ for this purpose.
#
class ModelFragment
  attr_reader :root_elements
  attr_accessor :location, :fragment_ref, :data
  
  # A FragmentRef serves as a single target object for elements which need to reference the
  # fragment they are contained in. The FragmentRef references the fragment it is contained in.
  # The FragmentRef is separate from the fragment itself to allow storing it in a marshal dump
  # independently of the fragment.
  #
  class FragmentRef
    attr_accessor :fragment
  end

  # A ResolvedReference wraps an unresolved reference after it has been resolved.
  # It also holds the target element to which it has been resolved, i.e. with which the proxy
  # object has been replaced.
  #
  class ResolvedReference
    attr_reader :uref, :target
    def initialize(uref, target)
      @uref, @target = uref, target
    end
  end

  # Create a model fragment
  #
  #  :data
  #    data object associated with this fragment
  #
  #  :identifier_provider
  #    identifier provider to be used when resolving references
  #    it must be a proc which receives a model element and must return 
  #    that element's identifier or nil if the element has no identifier
  #
  def initialize(location, options={})
    @location = location
    @fragment_ref = FragmentRef.new
    @fragment_ref.fragment = self
    @data = options[:data]
    @resolved_refs = nil 
    @changed = false
    @identifier_provider = options[:identifier_provider]
  end

  # Set the root elements, normally done by an instantiator.
  #
  # For optimization reasons the instantiator of the fragment may provide data explicitly which
  # is normally derived by the fragment itself. In this case it is essential that this
  # data is consistent with the fragment.
  #
  def set_root_elements(root_elements, options={})
    @root_elements = root_elements 
    @elements = options[:elements]
    @index = options[:index]
    @unresolved_refs = options[:unresolved_refs]
    @resolved_refs = nil 
    # new unresolved refs, reset removed_urefs
    @removed_urefs = nil
    @changed = false
  end

  # Must be called when any of the elements in this fragment has been changed
  #
  def mark_changed
    @changed = true
    @elements = nil
    @index = nil
    @unresolved_refs = nil
    # unresolved refs will be recalculated, no need to keep removed_urefs
    @removed_urefs = nil
    @resolved_refs = :dirty 
  end

  # Can be used to reset the change status to unchanged.
  #
  def mark_unchanged
    @changed = false
  end

  # Indicates whether the fragment has been changed or not
  #
  def changed?
    @changed
  end

  # Returns all elements within this fragment
  #
  def elements
    return @elements if @elements
    @elements = []
    @root_elements.each do |e|
      @elements << e
      @elements.concat(e.eAllContents)
    end
    @elements
  end
  
  # Returns the index of the element contained in this fragment.
  #
  def index
    build_index unless @index
    @index
  end

  # Returns all unresolved references within this fragment, i.e. references to MMProxy objects
  #
  def unresolved_refs
    @unresolved_refs ||= collect_unresolved_refs
    if @removed_urefs
      @unresolved_refs -= @removed_urefs
      @removed_urefs = nil
    end
    @unresolved_refs
  end

  # Builds the index of all elements within this fragment having an identifier
  # the index is an array of 2-element arrays holding the identifier and the element
  #
  def build_index
    raise "cannot build index without an identifier provider" unless @identifier_provider
    @index = elements.collect { |e|
      ident = @identifier_provider.call(e, nil)
      ident && !ident.empty? ? [ident, e] : nil 
    }.compact
  end

  # Resolves local references (within this fragment) as far as possible
  #
  # Options:
  #
  #  :use_target_type:
  #    reference resolver uses the expected target type to narrow the set of possible targets 
  #
  def resolve_local(options={})
    resolver = RGen::Instantiator::ReferenceResolver.new
    index.each do |i|
      resolver.add_identifier(i[0], i[1])
    end
    @unresolved_refs = resolver.resolve(unresolved_refs, :use_target_type => options[:use_target_type])
  end

  # Resolves references to external fragments using the external_index provided.
  # The external index must be a Hash mapping identifiers uniquely to model elements.
  #
  # Options:
  #
  #  :fragment_provider:
  #    If a +fragment_provider+ is given, the resolve step can be reverted later on 
  #    by a call to unresolve_external or unresolve_external_fragment. The fragment provider
  #    is a proc which receives a model element and must return the fragment in which it is
  #    contained.
  #
  #  :use_target_type:
  #    reference resolver uses the expected target type to narrow the set of possible targets 
  #
  #
  def resolve_external(external_index, options)
    fragment_provider = options[:fragment_provider]
    resolver = RGen::Instantiator::ReferenceResolver.new(
      :identifier_resolver => proc {|ident| external_index[ident] })
    if fragment_provider
      @resolved_refs = {} if @resolved_refs.nil? || @resolved_refs == :dirty
      on_resolve = proc { |ur, target|
        target_fragment = fragment_provider.call(target)
        target_fragment ||= :unknown
        raise "can not resolve local reference in resolve_external, call resolve_local first" \
          if target_fragment == self
        @resolved_refs[target_fragment] ||= []
        @resolved_refs[target_fragment] << ResolvedReference.new(ur, target)
      } 
      @unresolved_refs = resolver.resolve(unresolved_refs, :on_resolve => on_resolve, :use_target_type => options[:use_target_type])
    else
      @unresolved_refs = resolver.resolve(unresolved_refs, :use_target_type => options[:use_target_type])
    end
  end

  # Marks a particular unresolved reference +uref+ as resolved to +target+ in +target_fragment+.
  #
  def mark_resolved(uref, target_fragment, target)
    @resolved_refs = {} if @resolved_refs.nil? || @resolved_refs == :dirty
    target_fragment ||= :unknown
    if target_fragment != self
      @resolved_refs[target_fragment] ||= []
      @resolved_refs[target_fragment] << ResolvedReference.new(uref, target)
    end
    @removed_urefs ||= []
    @removed_urefs << uref
  end

  # Unresolve outgoing references to all external fragments, i.e. references which used to
  # be represented by an unresolved reference from within this fragment.
  # Note, that there may be more references to external fragments due to references which 
  # were represented by unresolved references from within other fragments.
  # 
  def unresolve_external
    return if @resolved_refs.nil?
    raise "can not unresolve, missing fragment information" if @resolved_refs == :dirty || @resolved_refs[:unknown]
    rrefs = @resolved_refs.values.flatten
    @resolved_refs = {}
    unresolve_refs(rrefs)
  end

  # Like unresolve_external but only unresolve references to external fragment +fragment+
  #
  def unresolve_external_fragment(fragment)
    return if @resolved_refs.nil?
    raise "can not unresolve, missing fragment information" if @resolved_refs == :dirty || @resolved_refs[:unknown]
    rrefs = @resolved_refs[fragment]
    @resolved_refs.delete(fragment)
    unresolve_refs(rrefs) if rrefs
  end

  private

  # Turns resolved references +rrefs+ back into unresolved references
  #
  def unresolve_refs(rrefs)
    # make sure any removed_urefs have been removed, 
    # otherwise they will be removed later even if this method actually re-added them
    unresolved_refs
    rrefs.each do |rr|
      ur = rr.uref
      refs = ur.element.getGeneric(ur.feature_name)
      if refs.is_a?(Array)
        index = refs.index(rr.target)
        ur.element.removeGeneric(ur.feature_name, rr.target)
        ur.element.addGeneric(ur.feature_name, ur.proxy, index)
      else
        ur.element.setGeneric(ur.feature_name, ur.proxy)
      end
      @unresolved_refs << ur
    end
  end

  def collect_unresolved_refs
    unresolved_refs = []
    elements.each do |e|
      each_reference_target(e) do |r, t|
        if t.is_a?(RGen::MetamodelBuilder::MMProxy)
          unresolved_refs << 
            RGen::Instantiator::ReferenceResolver::UnresolvedReference.new(e, r.name, t)
        end
      end
    end
    unresolved_refs
  end

  def each_reference_target(element)
    non_containment_references(element.class).each do |r|
      element.getGenericAsArray(r.name).each do |t|
        yield(r, t)
      end
    end
  end

  def non_containment_references(clazz)
    @@non_containment_references_cache ||= {}
    @@non_containment_references_cache[clazz] ||= 
      clazz.ecore.eAllReferences.select{|r| !r.containment}
  end 

end

end

end


