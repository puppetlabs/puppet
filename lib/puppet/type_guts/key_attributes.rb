module Puppet
  class Type
    # @return [Symbol, Boolean] Returns the name of the namevar if there is only one or false otherwise.
    # @comment This is really convoluted and part of the support for multiple namevars (?).
    #   If there is only one namevar, the produced value is naturally this namevar, but if there are several?
    #   The logic caches the name of the namevar if it is a single name, but otherwise always
    #   calls key_attributes, and then caches the first if there was only one, otherwise it returns
    #   false and caches this (which is then subsequently returned as a cache hit).
    #
    def name_var
      return @name_var_cache unless @name_var_cache.nil?
      key_attributes = self.class.key_attributes
      @name_var_cache = (key_attributes.length == 1) && key_attributes.first
    end

    # Returns a mapping from the title string to setting of attribute value(s).
    # This default implementation provides a mapping of title to the one and only _namevar_ present
    # in the type's definition.
    # @note Advanced: some logic requires this mapping to be done differently, using a different
    #   validation/pattern, breaking up the title
    #   into several parts assigning each to an individual attribute, or even use a composite identity where
    #   all namevars are seen as part of the unique identity (such computation is done by the {#uniqueness} method.
    #   These advanced options are rarely used (only one of the built in puppet types use this, and then only
    #   a small part of the available functionality), and the support for these advanced mappings is not
    #   implemented in a straight forward way. For these reasons, this method has been marked as private).
    #
    # @raise [Puppet::DevError] if there is no title pattern and there are two or more key attributes
    # @return [Array<Array<Regexp, Array<Array <Symbol, Proc>>>>, nil] a structure with a regexp and the first key_attribute ???
    # @comment This wonderful piece of logic creates a structure used by Resource.parse_title which
    #   has the capability to assign parts of the title to one or more attributes; It looks like an implementation
    #   of a composite identity key (all parts of the key_attributes array are in the key). This can also
    #   be seen in the method uniqueness_key.
    #   The implementation in this method simply assigns the title to the one and only namevar (which is name
    #   or a variable marked as namevar).
    #   If there are multiple namevars (any in addition to :name?) then this method MUST be implemented
    #   as it raises an exception if there is more than 1. Note that in puppet, it is only File that uses this
    #   to create a different pattern for assigning to the :path attribute
    #   This requires further digging.
    #   The entire construct is somewhat strange, since resource checks if the method "title_patterns" is
    #   implemented (it seems it always is) - why take this more expensive regexp mathching route for all
    #   other types?
    # @api private
    #
    def self.title_patterns
      case key_attributes.length
        when 0; []
        when 1;
          [ [ /(.*)/m, [ [key_attributes.first] ] ] ]
        else
          raise Puppet::DevError,"you must specify title patterns when there are two or more key attributes"
      end
    end

    # Produces a resource's _uniqueness_key_ (or composite key).
    # This key is an array of all key attributes' values. Each distinct tuple must be unique for each resource type.
    # @see key_attributes
    # @return [Object] an object that is a _uniqueness_key_ for this object
    #
    def uniqueness_key
      self.class.key_attributes.sort_by { |attribute_name| attribute_name.to_s }.map{ |attribute_name| self[attribute_name] }
    end

    # Returns the list of parameters that comprise the composite key / "uniqueness key".
    # All parameters that return true from #isnamevar? or is named `:name` are included in the returned result.
    # @see uniqueness_key
    # @return [Array<Puppet::Parameter>] WARNING: this return type is uncertain
    def self.key_attribute_parameters
      @key_attribute_parameters ||= (
      @parameters.find_all { |param|
        param.isnamevar? or param.name == :name
      }
      )
    end

    # Returns cached {key_attribute_parameters} names.
    # Key attributes are properties and parameters that comprise a composite key
    # or "uniqueness key".
    # @return [Array<String>] cached key_attribute names
    def self.key_attributes
      # This is a cache miss around 0.05 percent of the time. --daniel 2012-07-17
      @key_attributes_cache ||= key_attribute_parameters.collect { |p| p.name }
    end
  end
end
