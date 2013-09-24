Puppet::Parser::Functions.newfunction(:lookup, :type => :rvalue, :arity => -2, :doc => <<-'ENDHEREDOC') do |args|
Looks up data defined using Puppet Bindings.
The function is callable with one to  three arguments and optionally with a code block to further process the result.

The lookup function can be called in one of these ways:

    lookup(name)
    lookup(name, type)
    lookup(name, type, default)
    lookup(options_hash)
    lookup(name, options_hash)

The function may optionally be called with a code block / lambda with the following signatures:

    lookup(...) |$result| { ... }
    lookup(...) |$name, $result| { ... }
    lookup(...) |$name, $result, $default| { ... }

The longer signatures are useful when the block needs to raise an error (it can report the name), or
if it needs to know if the given default value was selected.
The `$name` is the last name that was looked up.
The `$result` is the looked up value (or the default value if not found). 
The `$default` is the given default value (`undef` if not given).

The block, if present, is called with the result from the lookup. The value produced by the block is also what is produced by the `lookup` function.
When a block is used, it is the users responsibility to call `error` if the result does not meet additional criteria, or if an undef value is not acceptable. If a value
is not found, and a default has been specified, the default value is given to the block.

The content of the options hash is:

* `name` - The name to lookup.args. (Mutually exclusive with `first_found`)
* `type` - The type to assert (a type specification in string form)
* `default` - The default value if there was no value found (must comply with the data type)
* `first_found` - An array of names to search, the value of the first found is used. (Mutually 
  exclusive with `name`).
* `accept_undef` - (default `false`) An `undef` result is accepted if this options is set to `true`.

When the call is on the form `lookup(name, options_hash)`, the given name argument wins over the
`options_hash['name']`.

The type specification is one of:

  * The basic types; 'Integer', 'String', 'Float', 'Boolean', or 'Pattern' (regular expression)
  * An Array with an optional element type given in '[]', that when not given defaults to '[Data]'
  * A Hash with optional key and value types given in '[]', where key type defaults to 'Literal' and value to 'Data', if
    only one type is given, the key defaults to 'Literal'
  * The abstract type 'Literal' which is one of the basic types
  * The abstract type 'Data' which is 'Literal', or type compatible with Array[Data], or Hash[Literal, Data]
  * The abstract type 'Collection' which is Array or Hash of any element type.
  * The abstract type 'Object' which is any kind of type

If the function is called without specifying a default value, and nothing is bound to the given name 
an error is raised unless the option `accept_undef` is true. If a block is given it must produce an acceptable value (or call `error`). If the block does not produce an acceptable value an error is
raised.

Examples:

When called with one argument; the name, it
returns the bound value with the given name after having  asserted it has the default datatype 'Data':

    lookup('the_name')

When called with two arguments; the name, and the expected type, it
returns the the bound value with the given name after having asserted it has the given data
type ('String' in the example):

    lookup('the_name', 'String')

When called with three arguments, the name, the expected type, and a default, it
returns the the bound value with the given name, or the default after having asserted the value
has the given data type ('String' in the example):

    lookup('the_name', 'String', 'Fred')

Using a lambda to process the looked up result - asserting that it starts with an upper case letter:

    lookup('the_name') |$result| {
      unless $result =~ /^[A-Z].*/
        { error 'Must start with an upper case letter'}
      $result
    }

Including the name in the error

    lookup('the_name') |$name, $result| {
      unless $result =~ /^[A-Z].*/
        { error "The bound value for '${name}' must start with an upper case letter"}
      $result
    }

When using a block, the value it produces is also asserted against the given type, and it may not be 
`undef` unless the option `'accept_undef'` is `true`.

All options work as the corresponding (direct) argument. The `first_found` option and
`accept_undef` are however only available as options.

Using the `first_found` option to return the first name that has a bound value:

    lookup({ first_found => ['apache::port', 'nginx::port'], type => 'Integer', default => 80})

Including the name in the error:

    lookup({ first_found => ['apache::port', 'nginx::port'], type => 'Integer', default => 80}) |$name, $result| {
      unless $result >= 80 and $result < 10000 {
        error("The bound value for '${name}' must be between 80 and 9999")
      }
      $result
    }

If you want to make lookup return undef when no value was found instead of raising an error:

      $are_you_there = lookup('peekaboo', { accept_undef => true} )
      $are_you_there = lookup('peekaboo', { accept_undef => true}) |$result| { $result }

ENDHEREDOC

  unless Puppet[:binder] || Puppet[:parser] == 'future'
    raise Puppet::ParseError, "The lookup function is only available with settings --binder true, or --parser future" 
  end

  def parse_lookup_args(args)
    options = {}
    pblock = if args[-1].is_a?(Puppet::Parser::AST::Lambda)
      args.pop
    end

    case args.size
    when 1
      # name, or all options
      if args[ 0 ].is_a?(Hash)
        options = to_symbolic_hash(args[ 0 ])
      else
        options[ :name ] = args[ 0 ]
      end

    when 2
      # name and type, or name and options
      if args[ 1 ].is_a?(Hash)
        options = to_symbolic_hash(args[ 1 ])
        options[:name] = args[ 0 ] # silently overwrite option with given name
      else
        options[:name] = args[ 0 ]
        options[:type] = args[ 1 ]
      end

    when 3
      # name, type, default (no options)
      options[ :name ] = args[ 0 ]
      options[ :type ] = args[ 1 ]
      options[ :default ] = args[ 2 ]
    else
      raise Puppet::PareError, "The lookup function accepts 1-3 arguments, got #{args.size}"
    end
    options[:pblock] = pblock
    options
  end

  def to_symbolic_hash(input)
    names = [:name, :type, :first_found, :default, :accept_undef]
    options = {}
    names.each {|n| options[n] = undef_as_nil(input[n.to_s] || input[n]) }
    options
  end

  def type_mismatch(type_calculator, expected, got)
    "has wrong type, expected #{type_calculator.string(expected)}, got #{type_calculator.string(got)}"
  end

  def fail(msg)
    raise Puppet::ParseError, "Function lookup() " + msg
  end

  def fail_lookup(names)
    name_part = if names.size == 1
      "the name '#{names[0]}'"
    else 
      "any of the names ['" + names.join(', ') + "']"
    end
    fail("did not find a value for #{name_part}")
  end

  def validate_options(options, type_calculator)
    type_parser = Puppet::Pops::Types::TypeParser.new
    first_found_type = type_parser.parse('Array[String]')

    if options[:name].nil? && options[:first_found].nil?
      fail ("requires a name, or sequence of names in first_found. Neither was given.")
    end

    if options[:name] && options[:first_found]
      fail("requires either a single name, or a sequence of names in first_found. Both were specified.")
    end

    if options[:name] && ! options[:name].is_a?(String)
      t = type_calculator.infer(options[:name])
      fail("name, expected String, got #{type_calculator.string(t)}")
    end

    if options[:first_found]
      t = type_calculator.infer(options[:first_found])
      if !type_calculator.assignable?(first_found_type, t)
        fail("first_found #{type_mismatch(type_calculator, first_found_type, t)}")
      end
    end

    # parse the type (or default 'Data'), fails if invalid type is given
    options[:type] = type_parser.parse(options[:type] || 'Data')

    # default value must comply with the given type
    if options[:default]
      t = type_calculator.infer(options[:default])
      if ! type_calculator.assignable?(options[:type], t)
        fail("default value #{type_mismatch(type_calculator, options[:type], t)}")
      end
    end
  end

  def nil_as_undef(x)
    x.nil? ? :undef : x
  end

  def undef_as_nil(x)
    is_nil_or_undef?(x) ? nil : x
  end

  def is_nil_or_undef?(x)
    x.nil? || x == :undef
  end

  # THE FUNCTION STARTS HERE

  type_calculator = Puppet::Pops::Types::TypeCalculator.new
  options = parse_lookup_args(args)
  validate_options(options, type_calculator)
  names = options[:name] ? [options[:name]] : options[:first_found]
  type = options[:type]

  result_with_name = names.reduce([]) do |memo, name|
    break memo if !memo[1].nil?
    [name, compiler.injector.lookup(self, type, name)]
  end

  result = if result_with_name[1].nil?
    # not found, use default (which may be nil), the default is already type checked
    options[:default]
  else
    # injector.lookup is type-safe already do no need to type check the result
    result_with_name[1]
  end

  result = if pblock = options[:pblock]
    result2 = case pblock.parameter_count
    when 1
      pblock.call(self, nil_as_undef(result))
    when 2
      pblock.call(self, result_with_name[ 0 ], nil_as_undef(result))
    else
      pblock.call(self, result_with_name[ 0 ], nil_as_undef(result), nil_as_undef(options[ :default ]))
    end

    # if the given result was returned, there is not need to type-check it again
    if !result2.equal?(result)
      t = type_calculator.infer(undef_as_nil(result2))
      if !type_calculator.assignable?(type, t)
        fail "the value produced by the given code block #{type_mismatch(type_calculator, type, t)}"
      end
    end
    result2
  else
    result
  end

  # Finally, the result if nil must be acceptable or an error is raised
  if is_nil_or_undef?(result) && !options[:accept_undef]
    fail_lookup(names)
  else
    nil_as_undef(result)
  end
end
