# The Binder is responsible for processing layered bindings that can be used to setup an Injector.
#
# An instance should be created, and calls should then be made to #define_categories to define the available categories, and
# their precedence. This should be followed by a call to #define_layers which will match the layered bindings against the
# effective categories (filtering out everything that does not apply, handle overrides, abstract entries etc.).
# The constructed hash with key => InjectorEntry mappings is obtained as #injector_entries, and is used to initialize an Injector.
#
# @api public
#
class Puppet::Pops::Binder::Binder
  # This limits the number of available categorizations, including "common".
  # @api private
  PRECEDENCE_MAX = 1000

  # @api private
  attr_reader :category_precedences

  # @api private
  attr_reader :category_values

  # @api private
  attr_reader :injector_entries

  # @api private
  attr_reader :key_factory

  # Whether the binder is fully configured or not
  # @api public
  #
  attr_reader :configured

  # @api public
  def initialize
    @category_precedences = {}
    @category_values = {}
    @key_factory = Puppet::Pops::Binder::KeyFactory.new()

    # Resulting hash of all key -> binding
    @injector_entries = {}

    # Not configured until the fat lady sings
    @configured = false

    @next_anonymous_key = 0
  end

  # Answers the question 'is this binder configured?' to the point it can be used to instantiate an Injector
  # @api public
  def configured?()
    configured()
  end

  # Defines the effective categories in precedence order (highest precedence first).
  # The 'common' (lowest precedence) category should not be included in the list.
  # A sanity check is made that there are no more than 1000 categorizations (which is pretty wild).
  #
  # The term 'effective categories' refers to the evaluated list of tuples (categorization, category-value) represented with
  # an instance of Puppet::Pops::Binder::Bindings::EffectiveCategories.
  #
  # @param effective_categories [Puppet::Pops::Binder::Bindings::EffectiveCategories] effective categories (i.e. with evaluated values)
  # @raises ArgumentError if this binder is already configured
  # @raises ArgumentError if the argument is not an EffectiveCategories
  # @raises ArgumentError if there is an attempt to redefine a category (non unique, or 'common').
  # @return [Puppet::Pops::Binder::Binder] self
  # @api public
  #
  def define_categories(effective_categories)
    raise ArgumentError, "This categories are already defined. Cannot redefine." unless @category_precedences.empty?

    # Note: a model instance is used since a Hash does not have a defined order in all Rubies.
    unless effective_categories.is_a?(Puppet::Pops::Binder::Bindings::EffectiveCategories)
      raise ArgumentError, "Expected Puppet::Pops::Binder::Bindings::EffectiveCategories, but got a: #{effective_categories.class}"
    end
    categories = effective_categories.categories
    raise ArgumentError, "Category limit (#{PRECEDENCE_MAX}) exceeded" unless categories.size <= PRECEDENCE_MAX

    # Automatically add the 'common' category with lowest precedence
    @category_precedences['common'] = 0

    # if categories contains "common", it should be last - simply drop it if present
    if last = categories[-1]
      if last.categorization == 'common'
        categories.delete_at(-1)
      end
    end
    # Process the given categories (highest precedence is first in the list)
    categories.each_with_index do |c, index|
      cname = c.categorization
      raise ArgumentError, "Attempt to redefine categorization: #{cname}" if @category_precedences[cname]
      @category_precedences[cname] = PRECEDENCE_MAX - index
      @category_values[cname] = c.value
    end
    self
  end

  # Binds layers from highest to lowest as defined by the given LayeredBindings.
  # @note
  #   Categories must be set with #define_categories before calling this method. The model should have been
  #   validated to get better error messages if the model is invalid. This implementation expects the model
  #   to be valid, and any errors raised will be more technical runtime errors.
  #
  # @param layered_bindings [Puppet::Pops::Binder::Bindings::LayeredBindings] the named and ordered layers
  # @raises ArgumentError if categories have not been defined
  # @raises ArgumentError if this binder is already configured
  # @raises ArgumentError if bindings with unresolved 'override' surfaces as an effective binding
  # @raises ArgumentError if the given argument has the wrong type, or if model is invalid in some way
  # @return [Puppet::Pops::Binder::Binder] self
  # @api public
  #
  def define_layers(layered_bindings)
    raise ArgumentError, "This binder is already configured. Cannot redefine its content." if configured?()

    raise ArgumentError, "Categories must be defined first" if @category_precedences.empty?
    LayerProcessor.new(self, key_factory).bind(layered_bindings)
    injector_entries.each  do |k,v|
      unless key_factory.is_contributions_key?(k) || v.is_resolved?()
        raise ArgumentError, "Binding with unresolved 'override' detected: #{k}"
      end
    end
    # and the fat lady has sung
    @configured = true
    self
  end

  # @api private
  def next_anonymous_key
    tmp = @next_anonymous_key
    @next_anonymous_key += 1
    tmp
  end

  # Processes the information in a layer, aggregating it to the injector_entries hash in its parent binder.
  # A LayerProcessor holds the intermediate state required while processing one layer.
  #
  # @api private
  #
  class LayerProcessor
    attr :effective_prec
    attr :prec_stack
    attr :bindings
    attr :binder
    attr :key_factory
    attr :contributions

    def initialize(binder, key_factory)
      @binder = binder
      @key_factory = key_factory
      @prec_stack = []
      @effective_prec = nil
      @bindings = []
      @contributions = []
      @@bind_visitor ||= Puppet::Pops::Visitor.new(nil,"bind",0,0)
    end

    # Add the binding to the list of potentially effective bindings from this layer
    # @api private
    #
    def add(b)
      bindings << Puppet::Pops::Binder::InjectorEntry.new(effective_prec, b)
    end

    # Add a multibind contribution
    # @api private
    #
    def add_contribution(b)
      contributions << Puppet::Pops::Binder::InjectorEntry.new(effective_prec, b)
    end

    # Bind given abstract binding
    # @api private
    #
    def bind(binding)
      @@bind_visitor.visit_this(self, binding)
    end

    # @returns [Puppet::Pops::Binder::InjectorEntry] the entry with the highest (category) precedence
    # @api private
    def highest(b1, b2)
      case b1.precedence <=> b2.precedence
      when 1
        b1
      when -1
        b2
      when 0
        # TODO: This is too crude for conflict errors
        raise ArgumentError, "Conflicting binding (TODO: report this with rich information)"
      end
    end

    # Produces the key for the given Binding.
    # @param binding [Puppet::Pops::Binder::Bindings::Binding] they binding to get a key for
    # @returns [Object] an opaque key
    # @api private
    #
    def key(binding)
      k = unless binding.is_a?(Puppet::Pops::Binder::Bindings::MultibindContribution)
        key_factory.binding_key(binding)
      else
        # contributions get a unique (sequencial) key
        binder.next_anonymous_key()
      end
    end

    # @api private
    def push_precedences(precedences)
      prec_stack.push(precedences)
      @effective_prec = nil # clear cache
    end

    # @api private
    def pop_precedences()
      prec_stack.pop()
      @effective_prec = nil # clear cache
    end

    # Returns the effective precedence as an array with highest precedence first.
    # Internally the precedence is an array with the highest precedence first.
    #
    # @api private
    #
    def effective_prec()
      unless @effective_prec
        @effective_prec = prec_stack.flatten.uniq.sort.reverse
        if @effective_prec.size == 0
          @effective_prec = [ 0 ] # i.e. "common"
        end
      end
      @effective_prec
    end

    # @api private
    def bind_Binding(o)
      add(o)
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

    # Process CategorizedBindings by calculating precedence, and then if satisfying the predicates, process the contained
    # bindings.
    # @api private
    #
    def bind_CategorizedBindings(o)
      precedences = o.predicates.collect do |p|
        prec = binder.category_precedences[p.categorization]

        # Skip bindings if the categorization is not present, or
        # if the category value is not the effective value for the categorization
        # Ignore the value for the common category (it is not possible to state common 'false' etc.)
        #
        return unless prec
        return unless binder.category_values[p.categorization] == p.value || p.categorization == 'common'
        prec
      end

      push_precedences(precedences)
      o.bindings.each {|b| bind(b) }
      pop_precedences()
    end

    # Process layered bindings from highest to lowest layer
    # @api private
    #
    def bind_LayeredBindings(o)
      o.layers.each do |layer|
        processor = LayerProcessor.new(binder, key_factory)
        # All except abstract (==error) are transfered to injector_entries

        processor.bind(layer).each do |k, v|
          entry = binder.injector_entries[k]
          unless key_factory.is_contributions_key?(k)
            raise ArgumentError, "The abstract binding TODO: was not overridden" unless !v.is_abstract?()
            raise ArgumentError, "Internal Error - redefinition of key: #{k}, (should never happen)" if entry
            binder.injector_entries[k] = v
          else
            entry ? entry << v : binder.injector_entries[k] = v
          end
        end
      end
    end

    # @api private
    #
    def bind_MultibindContribution(o)
      add_contribution(o)
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

        # ignore if a higher layer defined it, but ensure override gets resolved
        if x = binder.injector_entries[bkey]
          x.mark_override_resolved()
          next
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
        end
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
