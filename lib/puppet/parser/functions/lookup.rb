Puppet::Parser::Functions.newfunction(:lookup, :type => :rvalue, :arity => -2, :doc => <<-'ENDHEREDOC') do |args|
Looks up data defined using Puppet Bindings and Hiera.
The function is callable with one to three arguments and optionally with a code block to further process the result.

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

The code block receives the following three arguments:

* The `$name` is the last name that was looked up (*the* name if only one name was looked up)
* The `$result` is the looked up value (or the default value if not found).
* The `$default` is the given default value (`undef` if not given).

The block, if present, is called with the result from the lookup. The value produced by the block is also what is
produced by the `lookup` function.
When a block is used, it is the users responsibility to call `error` if the result does not meet additional
criteria, or if an undef value is not acceptable. If a value is not found, and a default has been
specified, the default value is given to the block.

The content of the options hash is:

* `name` - The name to lookup. (Mutually exclusive with `first_found`)
* `type` - The type to assert (a Type or a type specification in string form)
* `default` - The default value if there was no value found (must comply with the data type)
* `first_found` - An array of names to search, the value of the first found is used. (Mutually 
  exclusive with `name`).
* `accept_undef` - (default `false`) An `undef` result is accepted if this options is set to `true`.
* `override` - a hash with map from names to values that are used instead of the underlying bindings. If the name
  is found here it wins. Defaults to an empty hash.
* `extra` - a hash with map from names to values that are used as a last resort to obtain a value. Defaults to an
  empty hash.

When the call is on the form `lookup(name, options_hash)`, or `lookup(name, type, options_hash)`, the given name
argument wins over the `options_hash['name']`.

The search order is `override` (if given), then `binder`, then `hiera` and finally `extra` (if given). The first to produce
a value other than undef for a given name wins.

The type specification is one of:

  * A type in the Puppet Type System, e.g.:
    * `Integer`, an integral value with optional range e.g.:
      * `Integer[0, default]` - 0 or positive
      * `Integer[default, -1]` - negative, 
      * `Integer[1,100]` - value between 1 and 100 inclusive
    * `String`- any string
    * `Float` - floating point number (same signature as for Integer for `Integer` ranges)
    * `Boolean` - true of false (strict)
    * `Array` - an array (of Data by default), or parameterized as `Array[<element_type>]`, where
      `<element_type>` is the expected type of elements
    * `Hash`,  - a hash (of default `Literal` keys and `Data` values), or parameterized as
      `Hash[<value_type>]`, `Hash[<key_type>, <value_type>]`, where `<key_type>`, and
      `<value_type>` are the types of the keys and values respectively
      (key is `Literal` by default).
    * `Data` - abstract type representing any `Literal`, `Array[Data]`, or `Hash[Literal, Data]`
    * `Pattern[<p1>, <p2>, ..., <pn>]` - an enumeration of valid patterns (one or more) where
       a pattern is a regular expression string or regular expression,
       e.g. `Pattern['.com$', '.net$']`, `Pattern[/[a-z]+[0-9]+/]` 
    * `Enum[<s1>, <s2>, ..., <sn>]`, - an enumeration of exact string values (one or more)
       e.g. `Enum[blue, red, green]`.
    * `Variant[<t1>, <t2>,...<tn>]` - matches one of the listed types (at least one must be given)
      e.g. `Variant[Integer[8000,8999], Integer[20000, 99999]]` to accept a value in either range
    * `Regexp`- a regular expression (i.e. the result is a regular expression, not a string
       matching a regular expression).
  * A string containing a type description - one of the types as shown above but in string form.

If the function is called without specifying a default value, and nothing is bound to the given name 
an error is raised unless the option `accept_undef` is true. If a block is given it must produce an acceptable
value (or call `error`). If the block does not produce an acceptable value an error is
raised.

Examples:

When called with one argument; **the name**, it
returns the bound value with the given name after having  asserted it has the default datatype `Data`:

    lookup('the_name')

When called with two arguments; **the name**, and **the expected type**, it
returns the the bound value with the given name after having asserted it has the given data
type ('String' in the example):

    lookup('the_name', 'String') # 3.x
    lookup('the_name', String)   # parser future

When called with three arguments, **the name**, the **expected type**, and a **default**, it
returns the the bound value with the given name, or the default after having asserted the value
has the given data type (`String` in the example above):

    lookup('the_name', 'String', 'Fred') # 3x
    lookup('the_name', String, 'Fred')   # parser future

Using a lambda to process the looked up result - asserting that it starts with an upper case letter:

    # only with parser future
    lookup('the_size', Integer[1,100) |$result| {
      if $large_value_allowed and $result > 10
        { error 'Values larger than 10 are not allowed'}
      $result
    }

Including the name in the error

    # only with parser future
    lookup('the_size', Integer[1,100) |$name, $result| {
      if $large_value_allowed and $result > 10
        { error 'The bound value for '${name}' can not be larger than 10 in this configuration'}
      $result
    }

When using a block, the value it produces is also asserted against the given type, and it may not be 
`undef` unless the option `'accept_undef'` is `true`.

All options work as the corresponding (direct) argument. The `first_found` option and
`accept_undef` are however only available as options.

Using the `first_found` option to return the first name that has a bound value:

    lookup({ first_found => ['apache::port', 'nginx::port'], type => 'Integer', default => 80})

If you want to make lookup return undef when no value was found instead of raising an error:

     $are_you_there = lookup('peekaboo', { accept_undef => true} )
     $are_you_there = lookup('peekaboo', { accept_undef => true}) |$result| { $result }

ENDHEREDOC

  unless Puppet[:binder] || Puppet[:parser] == 'future'
    raise Puppet::ParseError, "The lookup function is only available with settings --binder true, or --parser future" 
  end

  def parse_lookup_args(args)
    options = {}
    pblock = if args[-1].respond_to?(:puppet_lambda)
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
    names = [:name, :type, :first_found, :default, :accept_undef, :extra, :override]
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

    # unless a type is already given (future case), parse the type (or default 'Data'), fails if invalid type is given
    unless options[:type].is_a?(Puppet::Pops::Types::PAbstractType)
      options[:type] = type_parser.parse(options[:type] || 'Data')
    end

    # default value must comply with the given type
    if options[:default]
      t = type_calculator.infer(options[:default])
      if ! type_calculator.assignable?(options[:type], t)
        fail("'default' value #{type_mismatch(type_calculator, options[:type], t)}")
      end
    end

    if options[:extra] && !options[:extra].is_a?(Hash)
      # do not perform inference here, it is enough to know that it is not a hash
      fail("'extra' value must be a Hash, got #{options[:extra].class}")
    end
    options[:extra] = {} unless options[:extra]

    if options[:override] && !options[:override].is_a?(Hash)
      # do not perform inference here, it is enough to know that it is not a hash
      fail("'override' value must be a Hash, got #{options[:extra].class}")
    end
    options[:override] = {} unless options[:override]

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

  # This is used as a marker - a value that cannot (at least not easily) by mistake be found in
  # hiera data.
  #
  class PrivateNotFoundMarker; end

  def search_for(type, name, options)
    # search in order, override, injector, hiera, then extra
    if !(result = options[:override][name]).nil?
      result
    elsif !(result = compiler.injector.lookup(self, type, name)).nil?
      result
   else
     result = self.function_hiera([name, PrivateNotFoundMarker])
     if !result.nil? && result != PrivateNotFoundMarker
       result
     else
       options[:extra][name]
     end
   end
  end

  # THE FUNCTION STARTS HERE

  type_calculator = Puppet::Pops::Types::TypeCalculator.new
  options = parse_lookup_args(args)
  validate_options(options, type_calculator)
  names = options[:name] ? [options[:name]] : options[:first_found]
  type = options[:type]

  result_with_name = names.reduce([]) do |memo, name|
    break memo if !memo[1].nil?
    [name, search_for(type, name, options)]
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
