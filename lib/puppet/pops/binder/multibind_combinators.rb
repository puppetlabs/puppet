# This module defines classes that are used to combine the contributions to a multibind.
# The base classes are used if no custom combinators have been defined in the model.
#
module Puppet::Pops::Binder::MultibindCombinators

  # This is the default Array Multibind combinator. It concatenates a type compatible array
  # value, or a single value of compatible element type.
  # @api public
  #
  class ArrayCombinator
    # Combines existing result (`memo`) with given `value` in multibinding `binding`.
    # A type calculator is passed to allow type checking using the same type calculator as the injector.
    #
    # @param scope [Puppet::Parser::Scope] the scope the combination is evaluated in
    # @param binding [Puppet::Pops::Binder::Bindings::Multibinding] the multibinding
    # @param tc {Puppet::Pops::Types::TypeCalculator] the type calculator to use for type checks
    # @param memo [Array<?>] result to combine value with, should have compatible element type
    # @param value [Object] an object to combine with memo
    #
    # @api public
    #
    def combine(scope, binding, tc, memo, value)
      assert_type(binding, tc, value)
      memo + (value.is_a?(Array) ? value : [ value ])
    end

    def assert_type(binding, tc, value)
      unless tc.instance?(binding.type.element_type, value) || type_calculator.instance?(binding.type, value)
        raise ArgumentError, "Type Error: contribution #{binding.name} does not match type of multibind #{tc.label(binding.type)}"
      end
    end
  end

  # An array combinator that calls a Puppet Lambda Expression to return the resulting array.
  # Type conformance is checked before the call (as this is awkward to achieve in Puppet DSL language). The
  # value is thus either an array of T, or a single value of type T, where T is a compatible type.
  # The value produced by the lambda is also type checked.
  #
  class ArrayPuppetLambdaCombinator < ArrayCombinator
    def initialize(puppet_lambda)
      @the_lambda = puppet_lambda
    end
    def combine(scope, binding, tc, memo, value)
      assert_type(binding, tc, value)
      result = @the_lambda.call(scope, memo, value)
      unless tc.instance?(binding.type, result)
        raise ArgumentError, "Type Error: combinator lambda for #{binding.name} produced result incompatible with #{tc.label(binding.type)}"
      end
      result
    end
  end

  # This is the default Hash Multibind combinator. It does not allow redefinition of an existing
  # entry for the given key. It checks type compatibility of entries.
  #
  # @api public
  #
  class HashCombinator
    # Combines the result of one key in the resulting hash.
    # @param scope [Puppet::Parser::Scope] the scope the combination is evaluated in
    # @param binding [Puppet::Pops::Binder::Bindings::Multibinding] the multibinding
    # @param tc {Puppet::Pops::Types::TypeCalculator] the type calculator to use for type checks
    #
    # @api public
    #
    def combine(scope, binding, tc, key, current, value)
      assert_type(binding, tc, key, value)

      unless current.nil?
        raise ArgumentError, "Duplicate key contributed to Hash Multibinding '#{binding.name}', key: #{key}"
      end

      value
    end

    def assert_type(binding, tc, key, value)
      unless tc.instance?(binding.type.key_type, key)
        raise ArgumentError, "Type Error: key contribution to #{binding.name}['#{key}'] is incompatible with key type: #{tc.label(binding.type)}"
      end

      if key.nil? || !key.is_a?(String) || key.empty?
        raise ArgumentError, "Entry contributing to multibind hash with id '#{binding.id}' must have a name."
      end

      unless tc.instance?(binding.type.element_type, value)
        raise ArgumentError, "Type Error: value contribution to #{binding.name}['#{key}'] is incompatible with value type: #{tc.label(binding.type)}"
      end
    end
  end

  # A hash combinator that calls a Puppet Lambda Expression to return the resulting entry for the given key.
  # Type conformance is checked before the call (as this is awkward to achieve in Puppet DSL language). The
  # value must have a compatible type.
  #
  class HashPuppetLambdaCombinator < HashCombinator
    def initialize(puppet_lambda)
      @the_lambda = puppet_lambda
    end

    def combine(scope, binding, tc, key, current, value)
      assert_type(binding, tc, key, value)
      result = @the_lambda.call(scope, memo, value)
      unless tc.instance?(binding.type.element_type, result)
        raise ArgumentError, "Type Error: combinator lambda for #{binding.name} produced result incompatible with #{tc.label(binding.type)}"
      end
      result
    end
  end
end