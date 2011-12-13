class Puppet::Parser::AST
  # The base class for all of the leaves of the parse trees.  These
  # basically just have types and values.  Both of these parameters
  # are simple values, not AST objects.
  class Leaf < AST
    attr_accessor :value, :type

    # Return our value.
    def evaluate(scope)
      @value
    end

    def match(value)
      @value == value
    end

    def to_s
      @value.to_s unless @value.nil?
    end
  end

  # The boolean class.  True or false.  Converts the string it receives
  # to a Ruby boolean.
  class Boolean < AST::Leaf

    # Use the parent method, but then convert to a real boolean.
    def initialize(hash)
      super

      unless @value == true or @value == false
        raise Puppet::DevError,
          "'#{@value}' is not a boolean"
      end
      @value
    end

    def to_s
      @value ? "true" : "false"
    end
  end

  # The base string class.
  class String < AST::Leaf
    def evaluate(scope)
      @value.dup
    end

    def to_s
      "\"#{@value}\""
    end
  end

  # An uninterpreted string.
  class FlatString < AST::Leaf
    def evaluate(scope)
      @value
    end

    def to_s
      "\"#{@value}\""
    end
  end

  class Concat < AST::Leaf
    def evaluate(scope)
      @value.collect { |x| x.evaluate(scope) }.collect{ |x| x == :undef ? '' : x }.join
    end

    def to_s
      "#{@value.map { |s| s.to_s.gsub(/^"(.*)"$/, '\1') }.join}"
    end
  end

  # The 'default' option on case statements and selectors.
  class Default < AST::Leaf; end

  # Capitalized words; used mostly for type-defaults, but also
  # get returned by the lexer any other time an unquoted capitalized
  # word is found.
  class Type < AST::Leaf; end

  # Lower-case words.
  class Name < AST::Leaf; end

  # double-colon separated class names
  class ClassName < AST::Leaf; end

  # undef values; equiv to nil
  class Undef < AST::Leaf; end

  # Host names, either fully qualified or just the short name, or even a regex
  class HostName < AST::Leaf
    def initialize(hash)
      super

      # Note that this is an AST::Regex, not a Regexp
      @value = @value.to_s.downcase unless @value.is_a?(Regex)
      if @value =~ /[^-\w.]/
        raise Puppet::DevError,
          "'#{@value}' is not a valid hostname"
      end
    end

    # implementing eql? and hash so that when an HostName is stored
    # in a hash it has the same hashing properties as the underlying value
    def eql?(value)
      value = value.value if value.is_a?(HostName)
      @value.eql?(value)
    end

    def hash
      @value.hash
    end

    def to_s
      @value.to_s
    end
  end

  # A simple variable.  This object is only used during interpolation;
  # the VarDef class is used for assignment.
  class Variable < Name
    # Looks up the value of the object in the scope tree (does
    # not include syntactical constructs, like '$' and '{}').
    def evaluate(scope)
      parsewrap do
        if (var = scope.lookupvar(@value, :file => file, :line => line)) == :undefined
          var = :undef
        end
        var
      end
    end

    def to_s
      "\$#{value}"
    end
  end

  class HashOrArrayAccess < AST::Leaf
    attr_accessor :variable, :key

    def evaluate_container(scope)
      container = variable.respond_to?(:evaluate) ? variable.safeevaluate(scope) : variable
      (container.is_a?(Hash) or container.is_a?(Array)) ? container : scope.lookupvar(container, :file => file, :line => line)
    end

    def evaluate_key(scope)
      key.respond_to?(:evaluate) ? key.safeevaluate(scope) : key
    end

    def array_index_or_key(object, key)
      if object.is_a?(Array)
        raise Puppet::ParserError, "#{key} is not an integer, but is used as an index of an array" unless key = Puppet::Parser::Scope.number?(key)
      end
      key
    end

    def evaluate(scope)
      object = evaluate_container(scope)
      accesskey = evaluate_key(scope)

      raise Puppet::ParseError, "#{variable} is not an hash or array when accessing it with #{accesskey}" unless object.is_a?(Hash) or object.is_a?(Array)

      object[array_index_or_key(object, accesskey)] || :undef
    end

    # Assign value to this hashkey or array index
    def assign(scope, value)
      object = evaluate_container(scope)
      accesskey = evaluate_key(scope)

      if object.is_a?(Hash) and object.include?(accesskey)
        raise Puppet::ParseError, "Assigning to the hash '#{variable}' with an existing key '#{accesskey}' is forbidden"
      end

      # assign to hash or array
      object[array_index_or_key(object, accesskey)] = value
    end

    def to_s
      "\$#{variable.to_s}[#{key.to_s}]"
    end
  end

  class Regex < AST::Leaf
    def initialize(hash)
      super
      @value = Regexp.new(@value) unless @value.is_a?(Regexp)
    end

    # we're returning self here to wrap the regexp and to be used in places
    # where a string would have been used, without modifying any client code.
    # For instance, in many places we have the following code snippet:
    #  val = @val.safeevaluate(@scope)
    #  if val.match(otherval)
    #      ...
    #  end
    # this way, we don't have to modify this test specifically for handling
    # regexes.
    def evaluate(scope)
      self
    end

    def evaluate_match(value, scope, options = {})
      value = value.is_a?(String) ? value : value.to_s

      if matched = @value.match(value)
        scope.ephemeral_from(matched, options[:file], options[:line])
      end
      matched
    end

    def match(value)
      @value.match(value)
    end

    def to_s
      "/#{@value.source}/"
    end
  end
end
