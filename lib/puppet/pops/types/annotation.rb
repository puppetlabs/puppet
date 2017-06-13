module Puppet::Pops
module Types
  # Pcore variant of the Adaptable::Adapter. Uses a Pcore Object type instead of a Class
  class Annotation < Adaptable::Adapter
    include Types::PuppetObject

    CLEAR = 'clear'.freeze

    # Register the Annotation type. This is the type that all custom Annotations will inherit from.
    def self.register_ptype(loader, ir)
      @type = Pcore::create_object_type(loader, ir, self, 'Annotation', nil, EMPTY_HASH)
    end

    def self._pcore_type
      @type
    end

    # Finds an existing annotation for the given object and returns it.
    # If no annotation was found, and a block is given, a new annotation is created from the
    # initializer hash that must be returned from the block.
    # If no annotation was found and no block is given, this method returns `nil`
    #
    # @param o [Object] object to annotate
    # @param block [Proc] optional, evaluated when a new annotation must be created. Should return the init hash
    # @return [Annotation<self>] an annotation of the same class as the receiver of the call
    #
    def self.annotate(o)
      adapter = get(o)
      if adapter.nil?
        if o.is_a?(Annotatable)
          init_hash = o.annotations[_pcore_type]
          init_hash = yield if init_hash.nil? && block_given?
        else
          init_hash = yield if block_given?
        end
        adapter = associate_adapter(_pcore_type.from_hash(init_hash), o) unless init_hash.nil?
      end
      adapter
    end

    # Forces the creation or removal of an annotation of this type.
    # If `init_hash` is a hash, a new annotation is created and returned
    # If `init_hash` is `nil`, then the annotation is cleared and the previous annotation is returned.
    #
    # @param o [Object] object to annotate
    # @param init_hash [Hash{String,Object},nil] the initializer for the annotation or `nil` to clear the annotation
    # @return [Annotation<self>] an annotation of the same class as the receiver of the call
    #
    def self.annotate_new(o, init_hash)
      if o.is_a?(Annotatable) && o.annotations.include?(_pcore_type)
        # Prevent clear or redefine of annotations declared on type
        action = init_hash == CLEAR ? 'clear' : 'redefine'
        raise ArgumentError, "attempt to #{action} #{type_name} annotation declared on #{o.label}"
      end

      if init_hash == CLEAR
        clear(o)
      else
        associate_adapter(_pcore_type.from_hash(init_hash), o)
      end
    end

    # Uses name of type instead of name of the class (the class is likely dynamically generated and as such,
    # has no name)
    # @return [String] the name of the type
    def self.type_name
      _pcore_type.name
    end
  end
end
end
