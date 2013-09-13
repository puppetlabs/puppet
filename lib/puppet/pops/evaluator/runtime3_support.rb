module Puppet::Pops::Evaluator::Runtime3Support
  # Fails the evaluation of _o_ in the given scope with the given message
  #
  # @status may need an extra parameter for error code
  # @param message [String] the error message
  # @param o [Object] the object for which evaluation failed in some way. Used to determine origin.
  # @param scope [Puppet::Parser::Scope] the runtime specific scope in which evaluation failed
  # @return [!] this method does not return
  # @raise [Puppet::ParseError] an evaluation error initialized from the arguments (TODO: Change to EvaluationError)
  # @todo fail evaluation with message, failure evaluating o, in scope
  # @todo This just fails with the message, should include a label for the expression
  #       and any origin set in an adapter for o. Scope could be passed for debugging
  #       purposes / stackdump
  #
  def fail(message, o, scope)
    raise Puppet::ParseError.new(message)
  end

  # Binds the given variable name to the given value in the given scope.
  # The reference object `o` is used for origin information.
  # @todo yardoc this, and pass on origin
  #
  def set_variable(name, value, o, scope)
    scope.setvar(name, value)
  end

  # Returns the value of the variable (nil is returned if variable has no value, or if variable does not exist)
  #
  def get_variable_value(name, o, scope)
    # Puppet 3x stores all variables as strings (then converts them back to numeric with a regexp... to see if it is a match variable)
    # Not ideal, scope should support numeric lookup directly instead.
    # TODO: consider fixing scope
    scope.lookupvar(name.to_s)
  end

  # Returns true if the variable of the given name is set in the given most nested scope. True is returned even if
  # variable is bound to nil.
  #
  def variable_bound?(name, scope)
    scope.bound?(name.to_s)
  end

  # Returns true of the variable is bound to a value or nil, in the scope or it's parent scopes.
  #
  def variable_exists?(name, scope)
    scope.exist?(name.to_s)
  end

  def set_match_data(match_data, o, scope)
    # TODO: Get file, line from semantic o and pass as options to scope since it tracks where these values
    # came from.
    # NOTE: The 3x scope adds one ephemeral(match) to its internal stack per match that succeeds ! It never
    # clears anything. Thus a context that performs many matches will get very deep (there simply is no way to
    # clear the match variables without rolling back the ephemeral stack.)
    # This implementation does not attempt to fix this, it behaves the same bad way.
    unless match_data.nil?
      scope.ephemeral_from(match_data)
    end
  end

  def get_scope_nesting_level(scope)
    scope.ephemeral_level
  end

  def set_scope_nesting_level(scope, level)
    # Yup, 3x uses this method to reset the level, it also supports passing :all to destroy all 
    # ephemeral/local scopes - which is a sure way to create havoc.
    #
    scope.unset_ephemeral_var(level)
  end

  # Adds a relationship between the given `source` and `target` of the given `relationship_type`
  # @param source [Puppet:Pops::Types::PCatalogEntryType] the source end of the relationship (from)
  # @param target [Puppet:Pops::Types::PCatalogEntryType] the target end of the relationship (to)
  # @param relationship_type [:relationship, :subscription] the type of the relationship
  #
  def add_relationship(source, target, relationship_type, scope)
    # The 3x way is to record a Puppet::Parser::Relationship that is evaluated at the end of the compilation.
    # This means it is not possible to detect any duplicates at this point (and signal where an attempt is made to
    # add a duplicate. There is also no location information to signal the original place in the logic. The user will have
    # to go fish.
    # The 3.x implementation is based on Strings :-o, so the source and target must be transformed. The resolution is
    # done by Catalog#resource(type, title). To do that, it creates a Puppet::Resource since it is responsible for
    # translating the name/type/title and create index-keys used by the catalog. The Puppet::Resource has bizarre parsing of
    # the type and title (scan for [] that is interpreted as type/title (but it gets it wrong).
    # Moreover if the type is "" or "component", the type is Class, and if the type is :main, it is :main, all other cases
    # undergo capitalization of name-segments (foo::bar becomes Foo::Bar). (This was earlier done in the reverse by the parser).
    # Further, the title undergoes the same munging !!!
    #
    # That bug infested nest of messy logic needs serious Exorcism!
    #
    # Unfortunately it is not easy to simply call more intelligent methods at a lower level as the compiler evaluates the recorded
    # Relationship object at a much later point, and it is responsible for invoking all the messy logic.
    #
    # TODO: Revisit the below logic when there is a sane implementation of the catalog, compiler and resource. For now
    # concentrate on transforming the type references to what is expected by the wacky logic.
    #
    # HOWEVER, the Compiler only records the Relationships, and the only method it calls is @relationships.each{|x| x.evaluate(catalog) }
    # Which means a smarter Relationship class could do this right. Instead of obtaining the resource from the catalog using
    # the borked resource(type, title) which creates a resource for the purpose of looking it up, it needs to instead
    # scan the catalog's resources
    #
    # GAAAH, it is even worse!
    # It starts in the parser, which parses "File['foo']" into an AST::ResourceReference with type = File, and title = foo
    # This AST is evaluated by looking up the type/title in the scope - causing it to be loaded if it exists, and if not, the given
    # type name/title is used. It does not search for resource instances, only classes and types. It returns symbolic information
    # [type, [title, title]]. From this, instances of Puppet::Resource are created and returned. These only have type/title information
    # filled out. One or an array of resources are returned.
    # This set of evaluated (empty reference) Resource instances are then passed to the relationship operator. It creates a
    # Puppet::Parser::Relationship giving it a source and a target that are (empty reference) Resource instances. These are then remembered
    # until the relationship is evaluated by the compiler (at the end). When evaluation takes place, the (empty reference) Resource instances
    # are converted to String (!?! WTF) on the simple format "#{type}[#{title}]", and the catalog is told to find a resource, by giving
    # it this string. If it cannot find the resource it fails, else the before/notify parameter is appended with the target.
    # The search for the resource being with (you guessed it) again creating an (empty reference) resource from type and title (WTF?!?!).
    # The catalog now uses the reference resource to compute a key [r.type, r.title.to_s] and also gets a uniqueness key from the
    # resource (This is only a reference type created from title and type). If it cannot find it with the first key, it uses the
    # uniqueness key to lookup.
    #
    # This is probably done to allow a resource type to munge/translate the title in some way (but it is quite unclear from the long
    # and convoluted path of evaluation.
    # In order to do this in a way that is similar to 3.x two resources are created to be used as keys.
    #
    #
    # TODO: logic that creates a PCatalogEntryType should resolve it to ensure it is loaded (to the best of known_resource_types knowledge).
    # If this is not done, the order in which things are done may be different? OTOH, it probably works anyway :-)
    #
    type, title = catalog_type_to_split_type_title(source)
    source_resource = Puppet::Resource.new(type, title)
    type, title = catalog_type_to_split_type_title(target)
    target_resource = Puppet::Resource.new(type, title)
    scope.compiler.add_relationship(Puppet::Parser::Relationship.new(source_resource, target_resource, type))
  end

  # Box value `v` to numeric or fails.
  # The given value `v` is converted to Numeric, and if that fails the operation
  # calls {#fail}.
  # @param v [Object] the value to convert
  # @param o [Object] originating instruction
  # @param scope [Object] the (runtime specific) scope where evaluation of o takes place
  # @return [Numeric] value `v` converted to Numeric.
  #
  def box_numeric(v, o, scope)
    unless n = Puppet::Pops::Utils.to_n(v)
      fail("Value '#{v}' can not be converted to Numeric.", o, scope)
    end
    n
  end

  # This is the same type of "truth" as used in the current Puppet DSL.
  #
  def is_true? o
    # Is the value true?  This allows us to control the definition of truth
    # in one place.
    case o
    when ''
      false
    when :undef
      false
    else
      !!o
    end
  end

  # Utility method for TrueClass || FalseClass
  # @param x [Object] the object to test if it is instance of TrueClass or FalseClass
  def is_boolean? x
    x.is_a?(TrueClass) || x.is_a?(FalseClass)
  end

  private

  # Produces an array with [type, title] from a PCatalogEntryType
  # Only used to produce the reference resource instances that are used to form a relationship.
  #
  def catalog_type_to_split_type_title(catalog_type)
    case catalog_type
    when Puppet::Pops::Types::PHostClassType
      return ['Class', catalog_type.class_name]
    when Puppet::Pops::Types::PResourceType
      return [catalog_type.type_name, catalog_type.title]
    else
      raise ArgumentError, "Cannot split the type #{catalog_type.class}, it is neither a PHostClassType, nor a PResourceClass."
    end
  end

end