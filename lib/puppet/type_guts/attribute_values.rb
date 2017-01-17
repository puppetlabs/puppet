# -*- coding: utf-8 -*-

module Puppet
  class Type
    # Gets the 'should' (wanted state) value of a parameter or property by name.
    # To explicitly get the 'is' (current state) value use `o.is(:name)`, and to explicitly get the 'should' value
    # use `o.should(:name)`
    # @param name [String] the name of the attribute to obtain the 'should' value for.
    # @return [Object] 'should'/wanted value of the given attribute
    def [](name)
      name = name.intern
      fail("Invalid parameter #{name}(#{name.inspect})") unless self.class.validattr?(name)

      if name == :name && nv = name_var
        name = nv
      end

      if obj = @parameters[name]
        # Note that if this is a property, then the value is the "should" value,
        # not the current value.
        obj.value
      else
        return nil
      end
    end

    # Sets the 'should' (wanted state) value of a property, or the value of a parameter.
    # @return
    # @raise [Puppet::Error] if the setting of the value fails, or if the given name is nil.
    # @raise [Puppet::ResourceError] when the parameter validation raises Puppet::Error or
    #   ArgumentError
    def []=(name,value)
      name = name.intern

      fail("no parameter named '#{name}'") unless self.class.validattr?(name)

      if name == :name && nv = name_var
        name = nv
      end
      raise Puppet::Error.new("Got nil value for #{name}") if value.nil?

      property = self.newattr(name)

      if property
        begin
          # make sure the parameter doesn't have any errors
          property.value = value
        rescue Puppet::Error, ArgumentError => detail
          error = Puppet::ResourceError.new("Parameter #{name} failed on #{ref}: #{detail}")
          adderrorcontext(error, detail)
          raise error
        end
      end

      nil
    end

    # @return [Object, nil] Returns the 'should' (wanted state) value for a specified property, or nil if the
    #   given attribute name is not a property (i.e. if it is a parameter, meta-parameter, or does not exist).
    def should(name)
      name = name.intern
      (prop = @parameters[name] and prop.is_a?(Puppet::Property)) ? prop.should : nil
    end

    # @todo Comment says "Return a specific value for an attribute.", as opposed to what "An unspecific value"???
    # @todo is this the 'is' or the 'should' value?
    # @todo why is the return restricted to things that respond to :value? (Only non structural basic data types
    #   supported?
    #
    # @return [Object, nil] the value of the attribute having the given name, or nil if the given name is not
    #   an attribute, or the referenced attribute does not respond to `:value`.
    def value(name)
      name = name.intern

      (obj = @parameters[name] and obj.respond_to?(:value)) ? obj.value : nil
    end

    # @todo comment says "For any parameters or properties that have defaults and have not yet been
    #   set, set them now.  This method can be handed a list of attributes,
    #   and if so it will only set defaults for those attributes."
    # @todo Needs a better explanation, and investigation about the claim an array can be passed (it is passed
    #   to self.class.attrclass to produce a class on which a check is made if it has a method class :default (does
    #   not seem to support an array...
    # @return [void]
    #
    def set_default(attr)
      return unless klass = self.class.attrclass(attr)
      return unless klass.method_defined?(:default)
      return if @parameters.include?(klass.name)

      return unless parameter = newattr(klass.name)

      if value = parameter.default and ! value.nil?
        parameter.value = value
      else
        @parameters.delete(parameter.name)
      end
    end
  end
end
