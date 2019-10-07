# Common code for AIX user/group providers.
class Puppet::Provider::AixObject < Puppet::Provider
  desc "Generic AIX resource provider"

  # Class representing a MappedObject, which can either be an
  # AIX attribute or a Puppet property. This class lets us
  # write something like:
  #
  #   attribute = mappings[:aix_attribute][:uid]
  #   attribute.name
  #   attribute.convert_property_value(uid)
  #
  #   property = mappings[:puppet_property][:id]
  #   property.name
  #   property.convert_attribute_value(id)
  #
  # NOTE: This is an internal class specific to AixObject. It is
  # not meant to be used anywhere else. That's why we do not have
  # any validation code in here.
  #
  # NOTE: See the comments in the class-level mappings method to
  # understand what we mean by pure and impure conversion functions.
  #
  # NOTE: The 'mapping' code, including this class, could possibly
  # be moved to a separate module so that it can be re-used in some
  # of our other providers. See PUP-9082.
  class MappedObject
    attr_reader :name

    def initialize(name, conversion_fn, conversion_fn_code)
      @name = name
      @conversion_fn = conversion_fn
      @conversion_fn_code = conversion_fn_code

      return unless pure_conversion_fn?

      # Our conversion function is pure, so we can go ahead
      # and define it. This way, we can use this MappedObject
      # at the class-level as well as at the instance-level.
      define_singleton_method(@conversion_fn) do |value|
        @conversion_fn_code.call(value)
      end
    end

    def pure_conversion_fn?
      @conversion_fn_code.arity == 1
    end

    # Sets our MappedObject's provider. This only makes sense
    # if it has an impure conversion function. We will call this
    # in the instance-level mappings method after the provider
    # instance has been created to define our conversion function.
    # Note that a MappedObject with an impure conversion function
    # cannot be used at the class level.
    def set_provider(provider)
      define_singleton_method(@conversion_fn) do |value|
        @conversion_fn_code.call(provider, value)
      end
    end
  end

  class << self
    #-------------
    # Mappings
    # ------------

    def mappings
      return @mappings if @mappings

      @mappings = {}
      @mappings[:aix_attribute] = {}
      @mappings[:puppet_property] = {}

      @mappings
    end

    # Add a mapping from a Puppet property to an AIX attribute. The info must include:
    #
    #   * :puppet_property       -- The puppet property corresponding to this attribute
    #   * :aix_attribute         -- The AIX attribute corresponding to this attribute. Defaults
    #                            to puppet_property if this is not provided.
    #   * :property_to_attribute -- A lambda that converts a Puppet Property to an AIX attribute
    #                            value. Defaults to the identity function if not provided.
    #   * :attribute_to_property -- A lambda that converts an AIX attribute to a Puppet property.
    #                            Defaults to the identity function if not provided.
    #
    # NOTE: The lambdas for :property_to_attribute or :attribute_to_property can be 'pure'
    # or 'impure'. A 'pure' lambda is one that needs only the value to do the conversion,
    # while an 'impure' lambda is one that requires the provider instance along with the
    # value. 'Pure' lambdas have the interface 'do |value| ...' while 'impure' lambdas have
    # the interface 'do |provider, value| ...'.
    #
    # NOTE: 'Impure' lambdas are useful in case we need to generate more specific error
    # messages or pass-in instance-specific command-line arguments.
    def mapping(info = {})
      identity_fn = lambda { |x| x }
      info[:aix_attribute] ||= info[:puppet_property]
      info[:property_to_attribute] ||= identity_fn
      info[:attribute_to_property] ||= identity_fn

      mappings[:aix_attribute][info[:puppet_property]] = MappedObject.new(
        info[:aix_attribute],
        :convert_property_value,
        info[:property_to_attribute]
      )
      mappings[:puppet_property][info[:aix_attribute]] = MappedObject.new(
        info[:puppet_property],
        :convert_attribute_value,
        info[:attribute_to_property]
      )
    end

    # Creates a mapping from a purely numeric Puppet property to
    # an attribute
    def numeric_mapping(info = {})
      property = info[:puppet_property]

      # We have this validation here b/c not all numeric properties
      # handle this at the property level (e.g. like the UID). Given
      # that, we might as well go ahead and do this validation for all
      # of our numeric properties. Doesn't hurt.
      info[:property_to_attribute] = lambda do |value|
        unless value.is_a?(Integer)
          raise ArgumentError, _("Invalid value %{value}: %{property} must be an Integer!") % { value: value, property: property }
        end

        value.to_s
      end

      # AIX will do the right validation to ensure numeric attributes
      # can't be set to non-numeric values, so no need for the extra clutter.
      info[:attribute_to_property] = lambda do |value|
        value.to_i
      end

      mapping(info)
    end

    #-------------
    # Useful Class Methods
    # ------------

    # Defines the getter and setter methods for each Puppet property that's mapped
    # to an AIX attribute. We define only a getter for the :attributes property.
    #
    # Provider subclasses should call this method after they've defined all of
    # their <puppet_property> => <aix_attribute> mappings.
    def mk_resource_methods
      # Define the Getter methods for each of our properties + the attributes
      # property
      properties = [:attributes]
      properties += mappings[:aix_attribute].keys
      properties.each do |property|
        # Define the getter
        define_method(property) do
          get(property)
        end

        # We have a custom setter for the :attributes property,
        # so no need to define it.
        next if property == :attributes

        # Define the setter
        define_method("#{property}=".to_sym) do |value|
          set(property, value)
        end
      end
    end

    # This helper splits a list separated by sep into its corresponding
    # items. Note that a key precondition here is that none of the items
    # in the list contain sep. 
    #
    # Let A be the return value. Then one of our postconditions is:
    #   A.join(sep) == list
    #
    # NOTE: This function is only used by the parse_colon_separated_list
    # function below. It is meant to be an inner lambda. The reason it isn't
    # here is so we avoid having to create a proc. object for the split_list
    # lambda each time parse_colon_separated_list is invoked. This will happen
    # quite often since it is used at the class level and at the instance level.
    # Since this function is meant to be an inner lambda and thus not exposed
    # anywhere else, we do not have any unit tests for it. These test cases are
    # instead covered by the unit tests for parse_colon_separated_list
    def split_list(list, sep)
      return [""] if list.empty?

      list.split(sep, -1)
    end

    # Parses a colon-separated list. Example includes something like:
    #   <item1>:<item2>:<item3>:<item4>
    #
    # Returns an array of the parsed items, e.g.
    #   [ <item1>, <item2>, <item3>, <item4> ]
    #
    # Note that colons inside items are escaped by #!
    def parse_colon_separated_list(colon_list)
      # ALGORITHM:
      # Treat the colon_list as a list separated by '#!:' We will get
      # something like:
      #     [ <chunk1>, <chunk2>, ... <chunkn> ]
      #
      # Each chunk is now a list separated by ':' and none of the items
      # in each chunk contains an escaped ':'. Now, split each chunk on
      # ':' to get:
      #     [ [<piece11>, ..., <piece1n>], [<piece21>, ..., <piece2n], ... ]
      #
      # Now note that <item1> = <piece11>, <item2> = <piece12> in our original
      # list, and that <itemn> = <piece1n>#!:<piece21>. This is the main idea
      # behind what our inject method is trying to do at the end, except that
      # we replace '#!:' with ':' since the colons are no longer escaped.
      chunks = split_list(colon_list, '#!:')
      chunks.map! { |chunk| split_list(chunk, ':') }

      chunks.inject do |accum, chunk|
        left = accum.pop
        right = chunk.shift

        accum.push("#{left}:#{right}")
        accum += chunk

        accum
      end
    end

    # Parses the AIX objects from the command output, returning an array of
    # hashes with each hash having the following schema:
    #   {
    #     :name       => <object_name>
    #     :attributes => <object_attributes>
    #   }
    #
    # Output should be of the form
    #   #name:<attr1>:<attr2> ...
    #   <name>:<value1>:<value2> ...
    #   #name:<attr1>:<attr2> ...
    #   <name>:<value1>:<value2> ...
    #
    # NOTE: We need to parse the colon-formatted output in case we have
    # space-separated attributes (e.g. 'gecos'). ":" characters are escaped
    # with a "#!".
    def parse_aix_objects(output)
      # Object names cannot begin with '#', so we are safe to
      # split individual users this way. We do not have to worry
      # about an empty list either since there is guaranteed to be
      # at least one instance of an AIX object (e.g. at least one
      # user or one group on the system).
      _, *objects = output.chomp.split(/^#/)

      objects.map! do |object|
        attributes_line, values_line = object.chomp.split("\n")

        attributes = parse_colon_separated_list(attributes_line.chomp)
        attributes.map!(&:to_sym)

        values = parse_colon_separated_list(values_line.chomp)

        attributes_hash = Hash[attributes.zip(values)]

        object_name = attributes_hash.delete(:name)

        Hash[[[:name, object_name.to_s], [:attributes, attributes_hash]]]
      end

      objects
    end

    # Lists all instances of the given object, taking in an optional set
    # of ia_module arguments. Returns an array of hashes, each hash
    # having the schema
    #   {
    #     :name => <object_name>
    #     :id   => <object_id>
    #   }
    def list_all(ia_module_args = [])
      cmd = [command(:list), '-c', *ia_module_args, '-a', 'id', 'ALL']
      parse_aix_objects(execute(cmd)).to_a.map do |object|
        name = object[:name]
        id = object[:attributes].delete(:id)

        Hash[[[:name, name,],[:id, id]]]
      end
    end

    #-------------
    # Provider API
    # ------------

    def instances
      list_all.to_a.map! do |object|
        new({ :name => object[:name] })
      end
    end
  end

  # Instantiate our mappings. These need to be at the instance-level
  # since some of our mapped objects may have impure conversion functions
  # that need our provider instance.
  def mappings
    return @mappings if @mappings
    
    @mappings = {}
    self.class.mappings.each do |type, mapped_objects|
      @mappings[type] = {}
      mapped_objects.each do |input, mapped_object|
        if mapped_object.pure_conversion_fn?
          # Our mapped_object has a pure conversion function so we
          # can go ahead and use it as-is.
          @mappings[type][input] = mapped_object
          next
        end

        # Otherwise, we need to dup it and set its provider to our
        # provider instance. The dup is necessary so that we do not
        # touch the class-level mapped object.
        @mappings[type][input] = mapped_object.dup
        @mappings[type][input].set_provider(self)
      end
    end

    @mappings
  end

  # Converts the given attributes hash to CLI args.
  def attributes_to_args(attributes)
    attributes.map do |attribute, value|
      "#{attribute}=#{value}"
    end
  end

  def ia_module_args
    return [] unless @resource[:ia_load_module]
    ["-R", @resource[:ia_load_module].to_s]
  end

  def lscmd
    [self.class.command(:list), '-c'] + ia_module_args + [@resource[:name]]
  end

  def addcmd(attributes)
    attribute_args = attributes_to_args(attributes)
    [self.class.command(:add)] + ia_module_args + attribute_args + [@resource[:name]]
  end

  def deletecmd
    [self.class.command(:delete)] + ia_module_args + [@resource[:name]]
  end

  def modifycmd(new_attributes)
    attribute_args = attributes_to_args(new_attributes)
    [self.class.command(:modify)] + ia_module_args + attribute_args + [@resource[:name]]
  end

  # Modifies the AIX object by setting its new attributes.
  def modify_object(new_attributes)
    execute(modifycmd(new_attributes))
    object_info(true) 
  end

  # Gets a Puppet property's value from object_info
  def get(property)
    return :absent unless exists?
    object_info[property] || :absent
  end

  # Sets a mapped Puppet property's value.
  def set(property, value)
    aix_attribute = mappings[:aix_attribute][property]
    modify_object(
      { aix_attribute.name => aix_attribute.convert_property_value(value) }
    )
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error, _("Could not set %{property} on %{resource}[%{name}]: %{detail}") % { property: property, resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
  end

  # This routine validates our new attributes property value to ensure
  # that it does not contain any Puppet properties.
  def validate_new_attributes(new_attributes)
    # Gather all of the <puppet property>, <aix attribute> conflicts to print
    # them all out when we create our error message. This makes it easy for the
    # user to update their manifest based on our error message.
    conflicts = {}
    mappings[:aix_attribute].each do |property, aix_attribute|
      next unless new_attributes.key?(aix_attribute.name)

      conflicts[:properties] ||= []
      conflicts[:properties].push(property)

      conflicts[:attributes] ||= []
      conflicts[:attributes].push(aix_attribute.name)
    end

    return if conflicts.empty?

    properties, attributes = conflicts.keys.map do |key|
      conflicts[key].map! { |name| "'#{name}'" }.join(', ')
    end
      
    detail = _("attributes is setting the %{properties} properties via. the %{attributes} attributes, respectively! Please specify these property values in the resource declaration instead.") % { properties: properties, attributes: attributes }

    raise Puppet::Error, _("Could not set attributes on %{resource}[%{name}]: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }
  end

  # Modifies the attribute property. Note we raise an error if the user specified
  # an AIX attribute corresponding to a Puppet property.
  def attributes=(new_attributes)
    validate_new_attributes(new_attributes)
    modify_object(new_attributes)
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error, _("Could not set attributes on %{resource}[%{name}]: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
  end

  # Collects the current property values of all mapped properties +
  # the attributes property.
  def object_info(refresh = false)
    return @object_info if @object_info && ! refresh
    @object_info = nil

    begin
      output = execute(lscmd)
    rescue Puppet::ExecutionFailure
      Puppet.debug(_("aix.object_info(): Could not find %{resource}[%{name}]") % { resource: @resource.class.name, name: @resource.name })

      return @object_info
    end

    # If lscmd succeeds, then output will contain our object's information.
    # Thus, .parse_aix_objects will always return a single element array.
    aix_attributes = self.class.parse_aix_objects(output).first[:attributes]
    aix_attributes.each do |attribute, value|
      @object_info ||= {}

      # If our attribute has a Puppet property, then we store that. Else, we store it as part
      # of our :attributes property hash
      if (property = mappings[:puppet_property][attribute])
        @object_info[property.name] = property.convert_attribute_value(value)
      else
        @object_info[:attributes] ||= {}
        @object_info[:attributes][attribute] = value
      end
    end

    @object_info
  end

  #-------------
  # Methods that manage the ensure property
  # ------------

  # Check that the AIX object exists
  def exists?
    ! object_info.nil?
  end

  # Creates a new instance of the resource
  def create
    attributes = @resource.should(:attributes) || {}
    validate_new_attributes(attributes)

    mappings[:aix_attribute].each do |property, aix_attribute|
      property_should = @resource.should(property)
      next if property_should.nil?
      attributes[aix_attribute.name] = aix_attribute.convert_property_value(property_should)
    end

    execute(addcmd(attributes))
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error, _("Could not create %{resource} %{name}: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
  end

  # Deletes this instance resource
  def delete
    execute(deletecmd)

    # Recollect the object info so that our current properties reflect
    # the actual state of the system. Otherwise, puppet resource reports
    # the wrong info. at the end. Note that this should return nil.
    object_info(true)
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error, _("Could not delete %{resource} %{name}: %{detail}") % { resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
  end
end
