# The Binder is responsible for processing layered bindings.
#
# An instance should be created, and calls should then be made to #set_categories to define the available categories, and
# their precedence. This should be followed by a call to #set_layers which will match the layered bindings against the
# effective categories (filtering out everything that does not apply, handle overrides, abstract entries etc.)
#
class Puppet::Pops::Binder::Binder
  # @api private
  PRECEDENCE_MAX = 1000

  # @api private
  attr_reader :category_precedences

  # @api private
  attr_reader :category_values

  # @api private
  attr_reader :all_layers

  def initialize
    @category_precedences = {}
    @category_values = {}
    @key_factory = Puppet::Pops::Binder::KeyFactory.new()

    # Resulting hash of all key -> binding
    @all_layers = {}
  end


  # Sets the effective categories in precedence order (highest precedence first).
  # The 'common' (lowest precedence) category should not be included in the list.
  # A sanity check is made that there are no more than 1000 categorizations (which is pretty wild).
  #
  # @param effective_categories [Puppet::Pops::Binder::Bindings::EffectiveCategories] effective categories (i.e. with evaluated values)
  # @api public
  #
  def set_categories(effective_categories)
    categories = effective_categories.categories
    raise ArgumentError, "Category limit (#{PRECEDENCE_MAX}) exceeded" unless categories.size <= PRECEDENCE_MAX

    @category_precedences['common'] = 0
    prec = PRECEDENCE_MAX
    categories.each do |c|
      cname = c.categorization
      raise ArgumentError, "Attempt to redefine categorization: #{cname}" if @category_precedences[cname]
      @category_precedences[cname] = prec
      @category_values[cname] = c.value
      prec -= 1
    end
  end

  # Binds layers from highest to lowest as defined by the given LayeredBindings.
  # @param layered_bindings [Puppet::Pops::Binder::Bindings::LayeredBindings] the named and ordered layers
  # @api public
  #
  def set_layers(layered_bindings)
    raise ArgumentError, "Categories must be set first" if @category_precedences.empty?
    LayerProcessor.new(self, key_factory).bind(layered_bindings)
  end

  # Represents a Binding with calculated effective precedence
  #
  class PrecedentedBinding
    attr :precedence
    attr :binding
    attr :resolved

    def initialize(precedence, binding)
      @precedence = precedence
      @binding = binding
    end

    def mark_override_resolved()
      @resolved = true
    end

    # The binding is resolved if it is non-override, or if the override has been resolved
    def is_resoved?()
      !binding.override || resolved
    end
  end

  # Processes the information in layerers, aggregating it to the all_layers hash in its parent binder.
  # @api private
  #
  class LayerProcessor
    attr :effective_prec
    attr :prec_stack
    attr :bindings
    attr :binder
    attr :key_factory

    def initialize(binder, key_factory)
      @binder = binder
      @key_factory = key_factory
      @prec_stack = []
      @effective_prec = nil
      @bindings = []
      @@bind_visitor ||= Puppet::Pops::Visitor.new(nil,"bind",0,0)
    end

    def add(b)
      bindings << PrecedentedBinding.new(effective_prec, b)
    end

    # Bind given abstract binding
    def bind(binding)
      @@bind_visitor.visit_this(self, o)
    end

    def highest(b1, b2)
      case b1.precedence <=> b2.precendece
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
    #
    def key(binding)
      key_factory.binding_key(binding)
    end

    def push_precedences(precedences)
      prec.stack.push(precedences)
      @effective_prec = nil # clear cache
    end

    def pop_precedences()
      prec_stack.pop()
      @effective_prec = nil # clear cache
    end

    # Returns the effective precedence as an array with highest precedence first
    def effective_prec()
      unless @effective_prec
        @effective_prec = prec_stack.flatten.uniq.sort.reverse
        if @effective_prec.size == 0
          @effective_prec = [ 0 ]
        end
      end
      @effective_prec
    end

    def bind_Binding(o)
      add(o)
    end

    def bind_Bindings(o)
      o.bindings.each {|b| bind(b) }
    end

    def bind_NamedBindings(o)
      o.bindings.each {|b| bind(b) }
    end

    def bind_CategorizedBindings(o)
      precedences = o.predicates.collect do |p|
        prec = binder.category_precedences[p.categorization]

        # Skip bindings if the categorization is not present, or
        # if the category value is not the effective value for the categorization
        #
        return unless prec
        return unless binder.category_values[p.categorization] == p.value
        prec
      end

      push_precendeces(precedences)
      o.bindings.each {|b| bind(b) }
      pop_precedences()
    end

    def bind_LayeredBindings(o)
      o.layers.each do |layer|
        processor = LayerProcessor.new(binder, key_factory)
        # All except abstract (==error) are transfered to all_layers

        processor.bind(layer).each do |k, v|
          raise ArgumentError, "The abstract binding TODO: was not overridden" unless !v.is_abstract?()
          raise ArgumentError, "Internal Error - redefinition of key (should never happen)" if binder.all_layers[k]
          binder.all_layers[k] = v
        end
      end
    end

    def bind_NamedLayer(o)
      o.bindings.each {|b| bind(b) }
      this_layer = {}
      bindings.each do |b|
        bkey = key(b)

        # ignore if a higher layer defined it, but ensure override gets resolved
        if x = binder.all_layers[bkey]
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
      this_layer
    end
  end
end
