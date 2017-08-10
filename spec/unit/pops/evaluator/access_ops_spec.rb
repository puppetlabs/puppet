#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet/pops/types/type_factory'
require 'base64'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl/AccessOperator' do
  include EvaluatorRspecHelper

  def range(from, to)
    Puppet::Pops::Types::TypeFactory.range(from, to)
  end

  def float_range(from, to)
    Puppet::Pops::Types::TypeFactory.float_range(from, to)
  end

  def binary(s)
    # Note that the factory is not aware of Binary and cannot operate on a
    # literal binary. Instead, it must create a call to Binary.new() with the base64 encoded
    # string as an argument
    CALL_NAMED(QREF("Binary"), true, [infer(Base64.strict_encode64(s))])
  end

  context 'The evaluator when operating on a String' do
    it 'can get a single character using a single key index to []' do
      expect(evaluate(literal('abc').access_at(1))).to eql('b')
    end

    it 'can get the last character using the key -1 in []' do
      expect(evaluate(literal('abc').access_at(-1))).to eql('c')
    end

    it 'can get a substring by giving two keys' do
      expect(evaluate(literal('abcd').access_at(1,2))).to eql('bc')
      # flattens keys
      expect(evaluate(literal('abcd').access_at([1,2]))).to eql('bc')
    end

    it 'produces empty string for a substring out of range' do
      expect(evaluate(literal('abc').access_at(100))).to eql('')
    end

    it 'raises an error if arity is wrong for []' do
      expect{evaluate(literal('abc').access_at)}.to raise_error(/String supports \[\] with one or two arguments\. Got 0/)
      expect{evaluate(literal('abc').access_at(1,2,3))}.to raise_error(/String supports \[\] with one or two arguments\. Got 3/)
    end
  end

  context 'The evaluator when operating on a Binary' do
    it 'can get a single character using a single key index to []' do
      expect(evaluate(binary('abc').access_at(1)).binary_buffer).to eql('b')
    end

    it 'can get the last character using the key -1 in []' do
      expect(evaluate(binary('abc').access_at(-1)).binary_buffer).to eql('c')
    end

    it 'can get a substring by giving two keys' do
      expect(evaluate(binary('abcd').access_at(1,2)).binary_buffer).to eql('bc')
      # flattens keys
      expect(evaluate(binary('abcd').access_at([1,2])).binary_buffer).to eql('bc')
    end

    it 'produces empty string for a substring out of range' do
      expect(evaluate(binary('abc').access_at(100)).binary_buffer).to eql('')
    end

    it 'raises an error if arity is wrong for []' do
      expect{evaluate(binary('abc').access_at)}.to raise_error(/String supports \[\] with one or two arguments\. Got 0/)
      expect{evaluate(binary('abc').access_at(1,2,3))}.to raise_error(/String supports \[\] with one or two arguments\. Got 3/)
    end
  end

  context 'The evaluator when operating on an Array' do
    it 'is tested with the correct assumptions' do
      expect(literal([1,2,3]).access_at(1).model_class <= Puppet::Pops::Model::AccessExpression).to eql(true)
    end

    it 'can get an element using a single key index to []' do
      expect(evaluate(literal([1,2,3]).access_at(1))).to eql(2)
    end

    it 'can get the last element using the key -1 in []' do
      expect(evaluate(literal([1,2,3]).access_at(-1))).to eql(3)
    end

    it 'can get a slice of elements using two keys' do
      expect(evaluate(literal([1,2,3,4]).access_at(1,2))).to eql([2,3])
      # flattens keys
      expect(evaluate(literal([1,2,3,4]).access_at([1,2]))).to eql([2,3])
    end

    it 'produces nil for a missing entry' do
      expect(evaluate(literal([1,2,3]).access_at(100))).to eql(nil)
    end

    it 'raises an error if arity is wrong for []' do
      expect{evaluate(literal([1,2,3,4]).access_at)}.to raise_error(/Array supports \[\] with one or two arguments\. Got 0/)
      expect{evaluate(literal([1,2,3,4]).access_at(1,2,3))}.to raise_error(/Array supports \[\] with one or two arguments\. Got 3/)
    end
  end

  context 'The evaluator when operating on a Hash' do
    it 'can get a single element giving a single key to []' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3}).access_at('b'))).to eql(2)
    end

    it 'can lookup an array' do
      expect(evaluate(literal({[1]=>10,[2]=>20}).access_at([2]))).to eql(20)
    end

    it 'produces nil for a missing key' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3}).access_at('x'))).to eql(nil)
    end

    it 'can get multiple elements by giving multiple keys to []' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3, 'd'=>4}).access_at('b', 'd'))).to eql([2, 4])
    end

    it 'compacts the result when using multiple keys' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3, 'd'=>4}).access_at('b', 'x'))).to eql([2])
    end

    it 'produces an empty array if none of multiple given keys were missing' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3, 'd'=>4}).access_at('x', 'y'))).to eql([])
    end

    it 'raises an error if arity is wrong for []' do
      expect{evaluate(literal({'a'=>1,'b'=>2,'c'=>3}).access_at)}.to raise_error(/Hash supports \[\] with one or more arguments\. Got 0/)
    end
  end

  context "When applied to a type it" do
    let(:types) { Puppet::Pops::Types::TypeFactory }

    # Integer
    #
    it 'produces an Integer[from, to]' do
      expr = fqr('Integer').access_at(1, 3)
      expect(evaluate(expr)).to eql(range(1,3))

      # arguments are flattened
      expr = fqr('Integer').access_at([1, 3])
      expect(evaluate(expr)).to eql(range(1,3))
    end

    it 'produces an Integer[1]' do
      expr = fqr('Integer').access_at(1)
      expect(evaluate(expr)).to eql(range(1,:default))
    end

    it 'gives an error for Integer[from, <from]' do
      expr = fqr('Integer').access_at(1,0)
      expect{evaluate(expr)}.to raise_error(/'from' must be less or equal to 'to'/)
    end

    it 'produces an error for Integer[] if there are more than 2 keys' do
      expr = fqr('Integer').access_at(1,2,3)
      expect { evaluate(expr)}.to raise_error(/with one or two arguments/)
    end

    # Float
    #
    it 'produces a Float[from, to]' do
      expr = fqr('Float').access_at(1, 3)
      expect(evaluate(expr)).to eql(float_range(1.0,3.0))

      # arguments are flattened
      expr = fqr('Float').access_at([1, 3])
      expect(evaluate(expr)).to eql(float_range(1.0,3.0))
    end

    it 'produces a Float[1.0]' do
      expr = fqr('Float').access_at(1.0)
      expect(evaluate(expr)).to eql(float_range(1.0,:default))
    end

    it 'produces a Float[1]' do
      expr = fqr('Float').access_at(1)
      expect(evaluate(expr)).to eql(float_range(1.0,:default))
    end

    it 'gives an error for Float[from, <from]' do
      expr = fqr('Float').access_at(1.0,0.0)
      expect{evaluate(expr)}.to raise_error(/'from' must be less or equal to 'to'/)
    end

    it 'produces an error for Float[] if there are more than 2 keys' do
      expr = fqr('Float').access_at(1,2,3)
      expect { evaluate(expr)}.to raise_error(/with one or two arguments/)
    end

    # Hash Type
    #
    it 'produces a Hash[0, 0] from the expression Hash[0, 0]' do
      expr = fqr('Hash').access_at(0, 0)
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.default, types.default, types.range(0, 0)))
    end

    it 'produces a Hash[Scalar,String] from the expression Hash[Scalar, String]' do
      expr = fqr('Hash').access_at(fqr('Scalar'), fqr('String'))
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.string, types.scalar))

      # arguments are flattened
      expr = fqr('Hash').access_at([fqr('Scalar'), fqr('String')])
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.string, types.scalar))
    end

    it 'gives an error if only one type is specified ' do
      expr = fqr('Hash').access_at(fqr('String'))
      expect {evaluate(expr)}.to raise_error(/accepts 2 to 4 arguments/)
    end

    it 'produces a Hash[Scalar,String] from the expression Hash[Integer, Array][Integer, String]' do
      expr = fqr('Hash').access_at(fqr('Integer'), fqr('Array')).access_at(fqr('Integer'), fqr('String'))
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.string, types.integer))
    end

    it "gives an error if parameter is not a type" do
      expr = fqr('Hash').access_at('String')
      expect { evaluate(expr)}.to raise_error(/Hash-Type\[\] arguments must be types/)
    end

    # Array Type
    #
    it 'produces an Array[0, 0] from the expression Array[0, 0]' do
      expr = fqr('Array').access_at(0, 0)
      expect(evaluate(expr)).to be_the_type(types.array_of(types.default, types.range(0, 0)))

      # arguments are flattened
      expr = fqr('Array').access_at([fqr('String')])
      expect(evaluate(expr)).to be_the_type(types.array_of(types.string))
    end

    it 'produces an Array[String] from the expression Array[String]' do
      expr = fqr('Array').access_at(fqr('String'))
      expect(evaluate(expr)).to be_the_type(types.array_of(types.string))

      # arguments are flattened
      expr = fqr('Array').access_at([fqr('String')])
      expect(evaluate(expr)).to be_the_type(types.array_of(types.string))
    end

    it 'produces an Array[String] from the expression Array[Integer][String]' do
      expr = fqr('Array').access_at(fqr('Integer')).access_at(fqr('String'))
      expect(evaluate(expr)).to be_the_type(types.array_of(types.string))
    end

    it 'produces a size constrained Array when the last two arguments specify this' do
      expr = fqr('Array').access_at(fqr('String'), 1)
      expected_t = types.array_of(String, types.range(1, :default))
      expect(evaluate(expr)).to be_the_type(expected_t)

      expr = fqr('Array').access_at(fqr('String'), 1, 2)
      expected_t = types.array_of(String, types.range(1, 2))
      expect(evaluate(expr)).to be_the_type(expected_t)
    end

    it "Array parameterization gives an error if parameter is not a type" do
      expr = fqr('Array').access_at('String')
      expect { evaluate(expr)}.to raise_error(/Array-Type\[\] arguments must be types/)
    end

    # Timespan Type
    #
    it 'produdes a Timespan type with a lower bound' do
      expr = fqr('Timespan').access_at({fqn('hours') => literal(3)})
      expect(evaluate(expr)).to be_the_type(types.timespan({'hours' => 3}))
    end

    it 'produdes a Timespan type with an upper bound' do
      expr = fqr('Timespan').access_at(literal(:default), {fqn('hours') => literal(9)})
      expect(evaluate(expr)).to be_the_type(types.timespan(nil, {'hours' => 9}))
    end

    it 'produdes a Timespan type with both lower and upper bounds' do
      expr = fqr('Timespan').access_at({fqn('hours') => literal(3)}, {fqn('hours') => literal(9)})
      expect(evaluate(expr)).to be_the_type(types.timespan({'hours' => 3}, {'hours' => 9}))
    end

    # Timestamp Type
    #
    it 'produdes a Timestamp type with a lower bound' do
      expr = fqr('Timestamp').access_at(literal('2014-12-12T13:14:15 CET'))
      expect(evaluate(expr)).to be_the_type(types.timestamp('2014-12-12T13:14:15 CET'))
    end

    it 'produdes a Timestamp type with an upper bound' do
      expr = fqr('Timestamp').access_at(literal(:default), literal('2016-08-23T17:50:00 CET'))
      expect(evaluate(expr)).to be_the_type(types.timestamp(nil, '2016-08-23T17:50:00 CET'))
    end

    it 'produdes a Timestamp type with both lower and upper bounds' do
      expr = fqr('Timestamp').access_at(literal('2014-12-12T13:14:15 CET'), literal('2016-08-23T17:50:00 CET'))
      expect(evaluate(expr)).to be_the_type(types.timestamp('2014-12-12T13:14:15 CET', '2016-08-23T17:50:00 CET'))
    end

    # Tuple Type
    #
    it 'produces a Tuple[String] from the expression Tuple[String]' do
      expr = fqr('Tuple').access_at(fqr('String'))
      expect(evaluate(expr)).to be_the_type(types.tuple([String]))

      # arguments are flattened
      expr = fqr('Tuple').access_at([fqr('String')])
      expect(evaluate(expr)).to be_the_type(types.tuple([String]))
    end

    it "Tuple parameterization gives an error if parameter is not a type" do
      expr = fqr('Tuple').access_at('String')
      expect { evaluate(expr)}.to raise_error(/Tuple-Type, Cannot use String where Any-Type is expected/)
    end

    it 'produces a varargs Tuple when the last two arguments specify size constraint' do
      expr = fqr('Tuple').access_at(fqr('String'), 1)
      expected_t = types.tuple([String], types.range(1, :default))
      expect(evaluate(expr)).to be_the_type(expected_t)

      expr = fqr('Tuple').access_at(fqr('String'), 1, 2)
      expected_t = types.tuple([String], types.range(1, 2))
      expect(evaluate(expr)).to be_the_type(expected_t)
    end

    # Pattern Type
    #
    it 'creates a PPatternType instance when applied to a Pattern' do
      regexp_expr = fqr('Pattern').access_at('foo')
      expect(evaluate(regexp_expr)).to eql(Puppet::Pops::Types::TypeFactory.pattern('foo'))
    end

    # Regexp Type
    #
    it 'creates a Regexp instance when applied to a Pattern' do
      regexp_expr = fqr('Regexp').access_at('foo')
      expect(evaluate(regexp_expr)).to eql(Puppet::Pops::Types::TypeFactory.regexp('foo'))

      # arguments are flattened
      regexp_expr = fqr('Regexp').access_at(['foo'])
      expect(evaluate(regexp_expr)).to eql(Puppet::Pops::Types::TypeFactory.regexp('foo'))
    end

    # Class
    #
    it 'produces a specific class from Class[classname]' do
      expr = fqr('Class').access_at(fqn('apache'))
      expect(evaluate(expr)).to be_the_type(types.host_class('apache'))
      expr = fqr('Class').access_at(literal('apache'))
      expect(evaluate(expr)).to be_the_type(types.host_class('apache'))
    end

    it 'produces an array of Class when args are in an array' do
      # arguments are flattened
      expr = fqr('Class').access_at([fqn('apache')])
      expect(evaluate(expr)[0]).to be_the_type(types.host_class('apache'))
    end

    it 'produces undef for Class if arg is undef' do
      # arguments are flattened
      expr = fqr('Class').access_at(nil)
      expect(evaluate(expr)).to be_nil
    end

    it 'produces empty array for Class if arg is [undef]' do
      # arguments are flattened
      expr = fqr('Class').access_at([])
      expect(evaluate(expr)).to be_eql([])
      expr = fqr('Class').access_at([nil])
      expect(evaluate(expr)).to be_eql([])
    end

    it 'raises error if access is to no keys' do
      expr = fqr('Class').access_at(fqn('apache')).access_at
      expect { evaluate(expr) }.to raise_error(/Evaluation Error: Class\[apache\]\[\] accepts 1 or more arguments\. Got 0/)
    end

    it 'produces a collection of classes when multiple class names are given' do
      expr = fqr('Class').access_at(fqn('apache'), literal('nginx'))
      result = evaluate(expr)
      expect(result[0]).to be_the_type(types.host_class('apache'))
      expect(result[1]).to be_the_type(types.host_class('nginx'))
    end

    it 'removes leading :: in class name' do
      expr = fqr('Class').access_at('::evoe')
      expect(evaluate(expr)).to be_the_type(types.host_class('evoe'))
    end

    it 'raises error if the name is not a valid name' do
      expr = fqr('Class').access_at('fail-whale')
      expect { evaluate(expr) }.to raise_error(/Illegal name/)
    end

    it 'downcases capitalized class names' do
      expr = fqr('Class').access_at('My::Class')

      expect(evaluate(expr)).to be_the_type(types.host_class('my::class'))
    end

    it 'gives an error if no keys are given as argument' do
      expr = fqr('Class').access_at
      expect {evaluate(expr)}.to raise_error(/Evaluation Error: Class\[\] accepts 1 or more arguments. Got 0/)
    end

    it 'produces an empty array if the keys reduce to empty array' do
      expr = fqr('Class').access_at(literal([[],[]]))
      expect(evaluate(expr)).to be_eql([])
    end

    # Resource
    it 'produces a specific resource type from Resource[type]' do
      expr = fqr('Resource').access_at(fqr('File'))
      expect(evaluate(expr)).to be_the_type(types.resource('File'))
      expr = fqr('Resource').access_at(literal('File'))
      expect(evaluate(expr)).to be_the_type(types.resource('File'))
    end

    it 'does not allow the type to be specified in an array' do
      # arguments are flattened
      expr = fqr('Resource').access_at([fqr('File')])
      expect{evaluate(expr)}.to raise_error(Puppet::ParseError, /must be a resource type or a String/)
    end

    it 'produces a specific resource reference type from File[title]' do
      expr = fqr('File').access_at(literal('/tmp/x'))
      expect(evaluate(expr)).to be_the_type(types.resource('File', '/tmp/x'))
    end

    it 'produces a collection of specific resource references when multiple titles are used' do
      # Using a resource type
      expr = fqr('File').access_at(literal('x'),literal('y'))
      result = evaluate(expr)
      expect(result[0]).to be_the_type(types.resource('File', 'x'))
      expect(result[1]).to be_the_type(types.resource('File', 'y'))

      # Using generic resource
      expr = fqr('Resource').access_at(fqr('File'), literal('x'),literal('y'))
      result = evaluate(expr)
      expect(result[0]).to be_the_type(types.resource('File', 'x'))
      expect(result[1]).to be_the_type(types.resource('File', 'y'))
    end

    it 'produces undef for Resource if arg is undef' do
      # arguments are flattened
      expr = fqr('File').access_at(nil)
      expect(evaluate(expr)).to be_nil
    end

    it 'gives an error if no keys are given as argument to Resource' do
      expr = fqr('Resource').access_at
      expect {evaluate(expr)}.to raise_error(/Evaluation Error: Resource\[\] accepts 1 or more arguments. Got 0/)
    end

    it 'produces an empty array if the type is given, and keys reduce to empty array for Resource' do
      expr = fqr('Resource').access_at(fqr('File'),literal([[],[]]))
      expect(evaluate(expr)).to be_eql([])
    end

    it 'gives an error i no keys are given as argument to a specific Resource type' do
      expr = fqr('File').access_at
      expect {evaluate(expr)}.to raise_error(/Evaluation Error: File\[\] accepts 1 or more arguments. Got 0/)
    end

    it 'produces an empty array if the keys reduce to empty array for a specific Resource tyoe' do
      expr = fqr('File').access_at(literal([[],[]]))
      expect(evaluate(expr)).to be_eql([])
    end

    it 'gives an error if resource is not found' do
      expr = fqr('File').access_at(fqn('x')).access_at(fqn('y'))
      expect {evaluate(expr)}.to raise_error(/Resource not found: File\['x'\]/)
    end

    # NotUndef Type
    #
    it 'produces a NotUndef instance' do
      type_expr = fqr('NotUndef')
      expect(evaluate(type_expr)).to eql(Puppet::Pops::Types::TypeFactory.not_undef())
    end

    it 'produces a NotUndef instance with contained type' do
      type_expr = fqr('NotUndef').access_at(fqr('Integer'))
      tf = Puppet::Pops::Types::TypeFactory
      expect(evaluate(type_expr)).to eql(tf.not_undef(tf.integer))
    end

    it 'produces a NotUndef instance with String type when given a literal String' do
      type_expr = fqr('NotUndef').access_at(literal('hey'))
      tf = Puppet::Pops::Types::TypeFactory
      expect(evaluate(type_expr)).to be_the_type(tf.not_undef(tf.string('hey')))
    end

    it 'Produces Optional instance with String type when using a String argument' do
      type_expr = fqr('Optional').access_at(literal('hey'))
      tf = Puppet::Pops::Types::TypeFactory
      expect(evaluate(type_expr)).to be_the_type(tf.optional(tf.string('hey')))
    end

    # Type Type
    #
    it 'creates a Type instance when applied to a Type' do
      type_expr = fqr('Type').access_at(fqr('Integer'))
      tf = Puppet::Pops::Types::TypeFactory
      expect(evaluate(type_expr)).to eql(tf.type_type(tf.integer))

      # arguments are flattened
      type_expr = fqr('Type').access_at([fqr('Integer')])
      expect(evaluate(type_expr)).to eql(tf.type_type(tf.integer))
    end

    # Ruby Type
    #
    it 'creates a Ruby Type instance when applied to a Ruby Type' do
      type_expr = fqr('Runtime').access_at('ruby','String')
      tf = Puppet::Pops::Types::TypeFactory
      expect(evaluate(type_expr)).to eql(tf.ruby_type('String'))

      # arguments are flattened
      type_expr = fqr('Runtime').access_at(['ruby', 'String'])
      expect(evaluate(type_expr)).to eql(tf.ruby_type('String'))
    end

    # Callable Type
    #
    it 'produces Callable instance without return type' do
      type_expr = fqr('Callable').access_at(fqr('String'))
      tf = Puppet::Pops::Types::TypeFactory
      expect(evaluate(type_expr)).to eql(tf.callable(String))
    end

    it 'produces Callable instance with parameters and return type' do
      type_expr = fqr('Callable').access_at([fqr('String')], fqr('Integer'))
      tf = Puppet::Pops::Types::TypeFactory
      expect(evaluate(type_expr)).to eql(tf.callable([String], Integer))
    end

    # Variant Type
    it 'does not allow Variant declarations with non-type arguments' do
      type_expr = fqr('Variant').access_at(fqr('Integer'), 'not a type')
      expect { evaluate(type_expr) }.to raise_error(/Cannot use String where Any-Type is expected/)
    end
  end

  matcher :be_the_type do |type|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |actual|
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end

    failure_message do |actual|
      "expected #{type.to_s}, but was #{actual.to_s}"
    end
  end

end
