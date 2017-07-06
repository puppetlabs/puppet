# The Binder is responsible for processing layered bindings that can be used to setup an Injector.
#
# An instance should be created and a call to {#define_layers} should be made which will process the layered bindings
# (handle overrides, abstract entries etc.).
# The constructed hash with `key => InjectorEntry` mappings is obtained as {#injector_entries}, and is used to initialize an
# {Injector Injector}.
#
# @api public
#
module Puppet::Pops
module Binder
class Binder

  # @api private
  attr_reader :injector_entries

  # @api private
  attr :id_index

  # @api private
  attr_reader :key_factory

  # A parent Binder or nil
  # @api private
  attr_reader :parent

  # The next anonymous key to use
  # @api private
  attr_reader :anonymous_key

  # This binder's precedence
  # @api private
  attr_reader :binder_precedence

  # @api public
  def initialize(layered_bindings, parent_binder=nil)
    @parent = parent_binder
    @id_index = Hash.new() { |k, v| [] }

    @key_factory = KeyFactory.new()

    # Resulting hash of all key -> binding
    @injector_entries = {}

    if @parent.nil?
      @anonymous_key = 0
      @binder_precedence = 0
    else
      # First anonymous key is the parent's next (non incremented key). (The parent can not change, it is
      # the final, free key).
      @anonymous_key = @parent.anonymous_key
      @binder_precedence = @parent.binder_precedence + 1
    end
    define_layers(layered_bindings)
  end

  # Binds layers from highest to lowest as defined by the given LayeredBindings.
  # @note
  #   The model should have been
  #   validated to get better error messages if the model is invalid. This implementation expects the model
  #   to be valid, and any errors raised will be more technical runtime errors.
  #
  # @param layered_bindings [Bindings::LayeredBindings] the named and ordered layers
  # @raise ArgumentError if this binder is already configured
  # @raise ArgumentError if bindings with unresolved 'override' surfaces as an effective binding
  # @raise ArgumentError if the given argument has the wrong type, or if model is invalid in some way
  # @return [Binder] self
  # @api public
  #
  def define_layers(layered_bindings)

    LayerProcessor.new(self, key_factory).bind(layered_bindings)
    contribution_keys = []
    # make one pass over entries to collect contributions, and check overrides
    injector_entries.each do |k,v|
      if key_factory.is_contributions_key?(k)
        contribution_keys << [k,v]
      elsif !v.is_resolved?()
        raise ArgumentError, "Binding with unresolved 'override' detected: #{self.class.format_binding(v.binding)}}"
      else
        # if binding has an id, add it to the index
        add_id_to_index(v.binding)
      end
    end

    # If a lower level binder has contributions for a key also contributed to in this binder
    # they must included in the higher shadowing contribution.
    # If a contribution is made to an id that is defined in a parent
    # contribute to an id that is defined in a lower binder, it must be promoted to this binder (copied) or
    # there is risk of making the lower level injector dirty.
    #
    contribution_keys.each do |kv|
      parent_contribution = lookup_in_parent(kv[0])
      next unless parent_contribution
      injector_entries[kv[0]] = kv[1] + parent_contributions

      # key the multibind_id from the contribution key
      multibind_id = key_factory.multibind_contribution_key_to_id(kv[0])
      promote_matching_bindings(self, @parent, multibind_id)
    end
  end
  private :define_layers

  # @api private
  def next_anonymous_key
    tmp = @anonymous_key
    @anonymous_key += 1
    tmp
  end

  def add_id_to_index(binding)
    return unless binding.is_a?(Bindings::Multibinding) && !(id = binding.id).nil?
    @id_index[id] = @id_index[id] << binding
  end

  def promote_matching_bindings(to_binder, from_binder, multibind_id)
    return if from_binder.nil?
    from_binder.id_index[ multibind_id ].each do |binding|
      key = key_factory.binding_key(binding)
      entry = lookup(key)
      unless entry.precedence == @binder_precedence
        # it is from a lower layer it must be promoted
        injector_entries[ key ] = InjectorEntry.new(binding, binder_precedence)
      end
    end
    # recursive "up the parent chain" to promote all
    promote_matching_bindings(to_binder, from_binder.parent, multibind_id)
  end

  def lookup_in_parent(key)
    @parent.nil? ? nil : @parent.lookup(key)
  end

  def lookup(key)
    if x = injector_entries[key]
      return x
    end
    @parent ?  @parent.lookup(key) :  nil
  end

  # @api private
  def self.format_binding(b)
    type_name = b.type.to_s
    layer_name, bindings_name = get_named_binding_layer_and_name(b)
    "binding: '#{type_name}/#{b.name}' in: '#{bindings_name}' in layer: '#{layer_name}'"
  end

  # @api private
  def self.format_contribution_source(b) 
    layer_name, bindings_name = get_named_binding_layer_and_name(b)
    "(layer: #{layer_name}, bindings: #{bindings_name})"
  end

  # @api private
  def self.get_named_binding_layer_and_name(b)
    return ['<unknown>', '<unknown>'] if b.nil?
    return [get_named_layer(b), b.name] if b.is_a?(Bindings::NamedBindings)
    get_named_binding_layer_and_name(b.eContainer)
  end

  # @api private
  def self.get_named_layer(b)
    return '<unknown>' if b.nil?
    return b.name if b.is_a?(Bindings::NamedLayer)
    get_named_layer(b.eContainer)
  end

  # Processes the information in a layer, aggregating it to the injector_entries hash in its parent binder.
  # A LayerProcessor holds the intermediate state required while processing one layer.
  #
  # @api private
  #
  class LayerProcessor
    attr :bindings
    attr :binder
    attr :key_factory
    attr :contributions
    attr :binder_precedence

    def initialize(binder, key_factory)
      @binder = binder
      @binder_precedence = binder.binder_precedence
      @key_factory = key_factory
      @bindings = []
      @contributions = []
      @@bind_visitor ||= Visitor.new(nil,"bind",0,0)
    end

    # Add the binding to the list of potentially effective bindings from this layer
    # @api private
    #
    def add(b)
      bindings << InjectorEntry.new(b, binder_precedence)
    end

    # Add a multibind contribution
    # @api private
    #
    def add_contribution(b)
      contributions << InjectorEntry.new(b, binder_precedence)
    end

    # Bind given abstract binding
    # @api private
    #
    def bind(binding)
      @@bind_visitor.visit_this_0(self, binding)
    end

    # @return [InjectorEntry] the entry with the highest precedence
    # @api private
    def highest(b1, b2)
      if b1.is_abstract? != b2.is_abstract?
        # if one is abstract and the other is not, the non abstract wins
        b1.is_abstract? ? b2 : b1
      else
        case b1.precedence <=> b2.precedence
        when 1
          b1
        when -1
          b2
        when 0
          raise_conflicting_binding(b1, b2)
        end
      end
    end

    # Raises a conflicting bindings error given two InjectorEntry's with same precedence in the same layer
    # (if they are in different layers, something is seriously wrong)
    def raise_conflicting_binding(b1, b2)
      b1_layer_name, b1_bindings_name = binder.class.get_named_binding_layer_and_name(b1.binding)
      b2_layer_name, b2_bindings_name = binder.class.get_named_binding_layer_and_name(b2.binding)

      finality_msg = (b1.is_final? || b2.is_final?) ? ". Override of final binding not allowed" : ''

      # TODO: Use of layer_name is not very good, it is not guaranteed to be unique
      unless b1_layer_name == b2_layer_name
        raise ArgumentError, [
          'Conflicting binding for',
          "'#{b1.binding.name}'",
          'being resolved across layers',
          "'#{b1_layer_name}' and",
          "'#{b2_layer_name}'"
          ].join(' ')+finality_msg
      end

      # Conflicting bindings made from the same source
      if b1_bindings_name == b2_bindings_name
        raise ArgumentError, [
          'Conflicting binding for name:',
          "'#{b1.binding.name}'",
          'in layer:',
          "'#{b1_layer_name}', ",
          'both from:',
          "'#{b1_bindings_name}'"
          ].join(' ')+finality_msg
      end

      # Conflicting bindings from different sources
      raise ArgumentError, [
        'Conflicting binding for name:',
        "'#{b1.binding.name}'",
        'in layer:',
        "'#{b1_layer_name}',",
        'from:',
        "'#{b1_bindings_name}', and",
        "'#{b2_bindings_name}'"
        ].join(' ')+finality_msg
    end


    # Produces the key for the given Binding.
    # @param binding [Bindings::Binding] the binding to get a key for
    # @return [Object] an opaque key
    # @api private
    #
    def key(binding)
      k = if is_contribution?(binding)
        # contributions get a unique (sequential) key
        binder.next_anonymous_key()
      else
        key_factory.binding_key(binding)
      end
    end

    # @api private
    def is_contribution?(binding)
      ! binding.multibind_id.nil?
    end

    # @api private
    def bind_Binding(o)
      if is_contribution?(o)
        add_contribution(o)
      else
        add(o)
      end
    end

    # @api private
    def bind_Bindings(o)
      o.bindings.each {|b| bind(b) }
    end

    # @api private
    def bind_NamedBindings(o)
      # Name is ignored here, it should be introspected when needed (in case of errors)
      o.bindings.each {|b| bind(b) }
    end

    # Process layered bindings from highest to lowest layer
    # @api private
    #
    def bind_LayeredBindings(o)
      o.layers.each do |layer|
        processor = LayerProcessor.new(binder, key_factory)
        # All except abstract (==error) are transferred to injector_entries

        processor.bind(layer).each do |k, v|
          entry = binder.injector_entries[k]
          unless key_factory.is_contributions_key?(k)
            if v.is_abstract?()
              layer_name, bindings_name = Binder.get_named_binding_layer_and_name(v.binding)
              type_name = v.binding.type.to_s
              raise ArgumentError, "The abstract binding '#{type_name}/#{v.binding.name}' in '#{bindings_name}' in layer '#{layer_name}' was not overridden"
            end
            raise ArgumentError, "Internal Error - redefinition of key: #{k}, (should never happen)" if entry
            binder.injector_entries[k] = v
          else
            # add contributions to existing contributions, else set them
            binder.injector_entries[k] = entry ? entry + v : v
          end
        end
      end
    end

    # Processes one named ("top level") layer consisting of a list of NamedBindings
    # @api private
    #
    def bind_NamedLayer(o)
      o.bindings.each {|b| bind(b) }
      this_layer = {}

      # process regular bindings
      bindings.each do |b|
        bkey = key(b.binding)

        # ignore if a higher layer defined it (unless the lower is final), but ensure override gets resolved
        # (override is not resolved across binders)
        if x = binder.injector_entries[bkey]
          if b.is_final?
            raise_conflicting_binding(x, b)
          end
          x.mark_override_resolved()
          next
        end

        # If a lower (parent) binder exposes a final binding it may not be overridden
        #
        if (x = binder.lookup_in_parent(bkey)) && x.is_final?
          raise_conflicting_binding(x, b)
        end

        # if already found in this layer, one wins (and resolves override), or it is an error
        existing = this_layer[bkey]
        winner = existing ? highest(existing, b) : b
        this_layer[bkey] = winner
        if existing
          winner.mark_override_resolved()
        end
      end

      # Process contributions
      # - organize map multibind_id to bindings with this id
      # - for each id, create an array with the unique anonymous keys to the contributed bindings
      # - bind the index to a special multibind contributions key (these are aggregated)
      #
      c_hash = Hash.new {|hash, key| hash[ key ] = [] }
      contributions.each {|b| c_hash[ b.binding.multibind_id ] << b }
      # - for each id
      c_hash.each do |k, v|
        index = v.collect do |b|
          bkey = key(b.binding)
          this_layer[bkey] = b
          bkey
        end.flatten
        contributions_key = key_factory.multibind_contributions(k)
        unless this_layer[contributions_key]
          this_layer[contributions_key] = []
        end
        this_layer[contributions_key] += index
      end
      this_layer
    end
  end
end
end
end
