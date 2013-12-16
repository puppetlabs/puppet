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
    def initialize(hash)
      super

      unless @value == true or @value == false
        raise Puppet::DevError, "'#{@value}' is not a boolean"
      end
      @value
    end
  end

  # The base string class.
  class String < AST::Leaf
    def evaluate(scope)
      @value.dup
    end

    def to_s
      @value.inspect
    end
  end

  # An uninterpreted string.
  class FlatString < AST::Leaf
    def evaluate(scope)
      @value
    end

    def to_s
      @value.inspect
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
      unless @value.is_a?(Regex)
        @value = @value.to_s.downcase
        @value =~ /[^-\w.]/ and
          raise Puppet::DevError, "'#{@value}' is not a valid hostname"
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
  end

  # A simple variable.  This object is only used during interpolation;
  # the VarDef class is used for assignment.
  class Variable < Name
    # Looks up the value of the object in the scope tree (does
    # not include syntactical constructs, like '$' and '{}').
    def evaluate(scope)
      parsewrap do
        if scope.include?(@value)
          scope[@value, {:file => file, :line => line}]
        else
          :undef
        end
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
      if container.is_a?(Hash) || container.is_a?(Array)
        container
      elsif container.is_a?(::String)
        scope[container, {:file => file, :line => line}]
      else
        raise Puppet::ParseError, "#{variable} is #{container.inspect}, not a hash or array"
      end
    end

    def evaluate_key(scope)
      key.respond_to?(:evaluate) ? key.safeevaluate(scope) : key
    end

    def array_index_or_key(object, key)
      if object.is_a?(Array)
        raise Puppet::ParseError, "#{key} is not an integer, but is used as an index of an array" unless key = Puppet::Parser::Scope.number?(key)
      end
      key
    end

    def evaluate(scope)
      object = evaluate_container(scope)
      accesskey = evaluate_key(scope)
      raise Puppet::ParseError, "#{variable} is not a hash or array when accessing it with #{accesskey}" unless object.is_a?(Hash) or object.is_a?(Array)

      result = object[array_index_or_key(object, accesskey)]
      result.nil? ? :undef : result
    end

    # Assign value to this hashkey or array index
    def assign(scope, value)
      object = evaluate_container(scope)
      accesskey = evaluate_key(scope)

      if object.is_a?(Hash) and object.include?(accesskey)
        raise Puppet::ParseError, "Assigning to the hash '#{variable}' with an existing key '#{accesskey}' is forbidden"
      end

      mutation_deprecation()

      # assign to hash or array
      object[array_index_or_key(object, accesskey)] = value
    end

    def to_s
      "\$#{variable.to_s}[#{key.to_s}]"
    end

    def mutation_deprecation
      deprecation_location_text =
      if file && line
        " at #{file}:#{line}"
      elsif file
        " in file #{file}"
      elsif line
        " at #{line}"
      end
      Puppet.warning(["The use of mutating operations on Array/Hash is deprecated#{deprecation_location_text}.",
         " See http://links.puppetlabs.com/puppet-mutation-deprecation"].join(''))
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
      value = value == :undef ? '' : value.to_s

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
