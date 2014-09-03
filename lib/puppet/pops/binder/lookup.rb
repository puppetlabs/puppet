# This class is the backing implementation of the Puppet function 'lookup'.
# See puppet/parser/functions/lookup.rb for documentation.
#
class Puppet::Pops::Binder::Lookup

  def self.parse_lookup_args(args)
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
      raise Puppet::ParseError, "The lookup function accepts 1-3 arguments, got #{args.size}"
    end
    options[:pblock] = pblock
    options
  end

  def self.to_symbolic_hash(input)
    names = [:name, :type, :default, :accept_undef, :extra, :override]
    options = {}
    names.each {|n| options[n] = undef_as_nil(input[n.to_s] || input[n]) }
    options
  end

  def self.type_mismatch(type_calculator, expected, got)
    "has wrong type, expected #{type_calculator.string(expected)}, got #{type_calculator.string(got)}"
  end

  def self.fail(msg)
    raise Puppet::ParseError, "Function lookup() " + msg
  end

  def self.fail_lookup(names)
    name_part = if names.size == 1
      "the name '#{names[0]}'"
    else
      "any of the names ['" + names.join(', ') + "']"
    end
    fail("did not find a value for #{name_part}")
  end

  def self.validate_options(options, type_calculator)
    type_parser = Puppet::Pops::Types::TypeParser.new
    name_type = type_parser.parse('Variant[Array[String], String]')

    if is_nil_or_undef?(options[:name]) || options[:name].is_a?(Array) && options[:name].empty?
      fail ("requires a name, or array of names. Got nothing to lookup.")
    end

    t = type_calculator.infer(options[:name])
    if ! type_calculator.assignable?(name_type, t)
      fail("given 'name' argument, #{type_mismatch(type_calculator, options[:name], t)}")
    end

    # unless a type is already given (future case), parse the type (or default 'Data'), fails if invalid type is given
    unless options[:type].is_a?(Puppet::Pops::Types::PAnyType)
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

  def self.nil_as_undef(x)
    x.nil? ? :undef : x
  end

  def self.undef_as_nil(x)
    is_nil_or_undef?(x) ? nil : x
  end

  def self.is_nil_or_undef?(x)
    x.nil? || x == :undef
  end

  # This is used as a marker - a value that cannot (at least not easily) by mistake be found in
  # hiera data.
  #
  class PrivateNotFoundMarker; end

  def self.search_for(scope, type, name, options)
    # search in order, override, injector, hiera, then extra
    if !(result = options[:override][name]).nil?
      result
    elsif !(result = scope.compiler.injector.lookup(scope, type, name)).nil?
      result
   else
     result = scope.function_hiera([name, PrivateNotFoundMarker])
     if !result.nil? && result != PrivateNotFoundMarker
       result
     else
       options[:extra][name]
     end
   end
  end

  # This is the method called from the puppet/parser/functions/lookup.rb
  # @param args [Array] array following the puppet function call conventions
  def self.lookup(scope, args)
    type_calculator = Puppet::Pops::Types::TypeCalculator.new
    options = parse_lookup_args(args)
    validate_options(options, type_calculator)
    names = [options[:name]].flatten
    type = options[:type]

    result_with_name = names.reduce([]) do |memo, name|
      break memo if !memo[1].nil?
      [name, search_for(scope, type, name, options)]
    end

    result = if result_with_name[1].nil?
      # not found, use default (which may be nil), the default is already type checked
      options[:default]
    else
      # injector.lookup is type-safe already do no need to type check the result
      result_with_name[1]
    end

    # If a block is given it is called with :undef passed as 'nil' since the lookup function
    # is available from 3x with --binder turned on, and the evaluation is always 4x.
    # TODO PUPPET4: Simply pass the value
    #
    result = if pblock = options[:pblock]
      result2 = case pblock.parameter_count
      when 1
        pblock.call(scope, undef_as_nil(result))
      when 2
        pblock.call(scope, result_with_name[ 0 ], undef_as_nil(result))
      else
        pblock.call(scope, result_with_name[ 0 ], undef_as_nil(result), undef_as_nil(options[ :default ]))
      end

      # if the given result was returned, there is no need to type-check it again
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
      # Since the function may be used without future parser being in effect, nil is not handled in a good
      # way, and should instead be turned into :undef.
      # TODO PUPPET4: Simply return the result
      #
      Puppet[:parser] == 'future' ? result : nil_as_undef(result)
    end
  end
end
