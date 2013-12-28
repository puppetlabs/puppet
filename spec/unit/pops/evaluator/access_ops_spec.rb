#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet/pops/types/type_factory'


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

  context 'The evaluator when operating on a String' do
    it 'can get a single character using a single key index to []' do
      expect(evaluate(literal('abc')[1])).to eql('b')
    end

    it 'can get the last character using the key -1 in []' do
      expect(evaluate(literal('abc')[-1])).to eql('c')
    end

    it 'can get a substring by giving two keys' do
      expect(evaluate(literal('abcd')[1,2])).to eql('bc')
      # flattens keys
      expect(evaluate(literal('abcd')[[1,2]])).to eql('bc')
    end

    it 'produces empty string for a substring out of range' do
      expect(evaluate(literal('abc')[100])).to eql('')
    end

    it 'raises an error if arity is wrong for []' do
      expect{evaluate(literal('abc')[])}.to raise_error(/String supports \[\] with one or two arguments\. Got 0/)
      expect{evaluate(literal('abc')[1,2,3])}.to raise_error(/String supports \[\] with one or two arguments\. Got 3/)
    end
  end

  context 'The evaluator when operating on an Array' do
    it 'is tested with the correct assumptions' do
      expect(literal([1,2,3])[1].current.is_a?(Puppet::Pops::Model::AccessExpression)).to eql(true)
    end

    it 'can get an element using a single key index to []' do
      expect(evaluate(literal([1,2,3])[1])).to eql(2)
    end

    it 'can get the last element using the key -1 in []' do
      expect(evaluate(literal([1,2,3])[-1])).to eql(3)
    end

    it 'can get a slice of elements using two keys' do
      expect(evaluate(literal([1,2,3,4])[1,2])).to eql([2,3])
      # flattens keys
      expect(evaluate(literal([1,2,3,4])[[1,2]])).to eql([2,3])
    end

    it 'produces nil for a missing entry' do
      expect(evaluate(literal([1,2,3])[100])).to eql(nil)
    end

    it 'raises an error if arity is wrong for []' do
      expect{evaluate(literal([1,2,3,4])[])}.to raise_error(/Array supports \[\] with one or two arguments\. Got 0/)
      expect{evaluate(literal([1,2,3,4])[1,2,3])}.to raise_error(/Array supports \[\] with one or two arguments\. Got 3/)
    end
  end

  context 'The evaluator when operating on a Hash' do
    it 'can get a single element giving a single key to []' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3})['b'])).to eql(2)
    end

    it 'can lookup an array' do
      expect(evaluate(literal({[1]=>10,[2]=>20})[[2]])).to eql(20)
    end

    it 'produces nil for a missing key' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3})['x'])).to eql(nil)
    end

    it 'can get multiple elements by giving multiple keys to []' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3, 'd'=>4})['b', 'd'])).to eql([2, 4])
    end

    it 'compacts the result when using multiple keys' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3, 'd'=>4})['b', 'x'])).to eql([2])
    end

    it 'produces an empty array if none of multiple given keys were missing' do
      expect(evaluate(literal({'a'=>1,'b'=>2,'c'=>3, 'd'=>4})['x', 'y'])).to eql([])
    end

    it 'raises an error if arity is wrong for []' do
      expect{evaluate(literal({'a'=>1,'b'=>2,'c'=>3})[])}.to raise_error(/Hash supports \[\] with one or more arguments\. Got 0/)
    end
  end

  context "When applied to a type it" do
    let(:types) { Puppet::Pops::Types::TypeFactory }

    # Integer
    #
    it 'produces an Integer[from, to]' do
      expr = fqr('Integer')[1, 3]
      expect(evaluate(expr)).to eql(range(1,3))

      # arguments are flattened
      expr = fqr('Integer')[[1, 3]]
      expect(evaluate(expr)).to eql(range(1,3))
    end

    it 'produces an Integer[1]' do
      expr = fqr('Integer')[1]
      expect(evaluate(expr)).to eql(range(1,1))
    end

    it 'produces an Integer[from, <from]' do
      expr = fqr('Integer')[1,0]
      expect(evaluate(expr)).to eql(range(1,0))
    end

    it 'produces an error for Integer[] if there are more than 2 keys' do
      expr = fqr('Integer')[1,2,3]
      expect { evaluate(expr)}.to raise_error(/with one or two arguments/)
    end

    # Float
    #
    it 'produces a Float[from, to]' do
      expr = fqr('Float')[1, 3]
      expect(evaluate(expr)).to eql(float_range(1.0,3.0))

      # arguments are flattened
      expr = fqr('Float')[[1, 3]]
      expect(evaluate(expr)).to eql(float_range(1.0,3.0))
    end

    it 'produces a Float[1.0]' do
      expr = fqr('Float')[1.0]
      expect(evaluate(expr)).to eql(float_range(1.0,1.0))
    end

    it 'produces a Float[1]' do
      expr = fqr('Float')[1]
      expect(evaluate(expr)).to eql(float_range(1.0,1.0))
    end

    it 'produces a Float[from, <from]' do
      expr = fqr('Float')[1.0,0.0]
      expect(evaluate(expr)).to eql(float_range(1.0,0.0))
    end

    it 'produces an error for Float[] if there are more than 2 keys' do
      expr = fqr('Float')[1,2,3]
      expect { evaluate(expr)}.to raise_error(/with one or two arguments/)
    end

    # Hash Type
    #
    it 'produces a Hash[Literal,String] from the expression Hash[String]' do
      expr = fqr('Hash')[fqr('String')]
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.string, types.literal))

      # arguments are flattened
      expr = fqr('Hash')[[fqr('String')]]
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.string, types.literal))
    end

    it 'produces a Hash[String,String] from the expression Hash[String, String]' do
      expr = fqr('Hash')[fqr('String'), fqr('String')]
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.string, types.string))
    end

    it 'produces a Hash[Literal,String] from the expression Hash[Integer][String]' do
      expr = fqr('Hash')[fqr('Integer')][fqr('String')]
      expect(evaluate(expr)).to be_the_type(types.hash_of(types.string, types.literal))
    end

    it "gives an error if parameter is not a type" do
      expr = fqr('Hash')['String']
      expect { evaluate(expr)}.to raise_error(/Hash-Type\[\] arguments must be types/)
    end

    # Array Type
    #
    it 'produces an Array[String] from the expression Array[String]' do
      expr = fqr('Array')[fqr('String')]
      expect(evaluate(expr)).to be_the_type(types.array_of(types.string))

      # arguments are flattened
      expr = fqr('Array')[[fqr('String')]]
      expect(evaluate(expr)).to be_the_type(types.array_of(types.string))
    end

    it 'produces an Array[String] from the expression Array[Integer][String]' do
      expr = fqr('Array')[fqr('Integer')][fqr('String')]
      expect(evaluate(expr)).to be_the_type(types.array_of(types.string))
    end

    it "gives an error if parameter is not a type" do
      expr = fqr('Array')['String']
      expect { evaluate(expr)}.to raise_error(/Array-Type\[\] arguments must be types/)
    end

    # Pattern Type
    #
    it 'creates a PPatternType instance when applied to a Pattern' do
      regexp_expr = fqr('Pattern')['foo']
      expect(evaluate(regexp_expr)).to eql(Puppet::Pops::Types::TypeFactory.pattern('foo'))
    end

    # Regexp Type
    #
    it 'creates a Regexp instance when applied to a Pattern' do
      regexp_expr = fqr('Regexp')['foo']
      expect(evaluate(regexp_expr)).to eql(Puppet::Pops::Types::TypeFactory.regexp('foo'))

      # arguments are flattened
      regexp_expr = fqr('Regexp')[['foo']]
      expect(evaluate(regexp_expr)).to eql(Puppet::Pops::Types::TypeFactory.regexp('foo'))
    end

    # Class
    #
    it 'produces a specific class from Class[classname]' do
      expr = fqr('Class')[fqn('apache')]
      expect(evaluate(expr)).to be_the_type(types.host_class('apache'))
      expr = fqr('Class')[literal('apache')]
      expect(evaluate(expr)).to be_the_type(types.host_class('apache'))

      # arguments are flattened
      expr = fqr('Class')[[fqn('apache')]]
      expect(evaluate(expr)).to be_the_type(types.host_class('apache'))
      end

    it 'produces same class if no class name is given' do
      expr = fqr('Class')[fqn('apache')][]
      expect { evaluate(expr) }.to raise_error(/Evaluation Error: Class\[apache\]\[\] accepts 1 argument\. Got 0/)
    end

    it 'produces a collection of classes when multiple class names are given' do
      expr = fqr('Class')[fqn('apache'), literal('nginx')]
      result = evaluate(expr)
      expect(result[0]).to be_the_type(types.host_class('apache'))
      expect(result[1]).to be_the_type(types.host_class('nginx'))
    end

    it 'raises error if the name is not a valid name' do
      expr = fqr('Class')['fail-whale']
      expect { evaluate(expr) }.to raise_error(/Illegal name/)
    end

    # Resource
    it 'produces a specific resource type from Resource[type]' do
      expr = fqr('Resource')[fqr('File')]
      expect(evaluate(expr)).to be_the_type(types.resource('File'))
      expr = fqr('Resource')[literal('File')]
      expect(evaluate(expr)).to be_the_type(types.resource('File'))

      # arguments are flattened
      expr = fqr('Resource')[[fqr('File')]]
      expect(evaluate(expr)).to be_the_type(types.resource('File'))
    end

    it 'produces a specific resource reference type from File[title]' do
      expr = fqr('File')[literal('/tmp/x')]
      expect(evaluate(expr)).to be_the_type(types.resource('File', '/tmp/x'))
    end

    it 'produces a collection of specific resource references when multiple titles are used' do
      # Using a resource type
      expr = fqr('File')[literal('x'),literal('y')]
      result = evaluate(expr)
      expect(result[0]).to be_the_type(types.resource('File', 'x'))
      expect(result[1]).to be_the_type(types.resource('File', 'y'))

      # Using generic resource
      expr = fqr('Resource')[fqr('File'), literal('x'),literal('y')]
      result = evaluate(expr)
      expect(result[0]).to be_the_type(types.resource('File', 'x'))
      expect(result[1]).to be_the_type(types.resource('File', 'y'))
    end

    it 'gives an error if resource is not found' do
      expr = fqr('File')[fqn('x')][fqn('y')]
      expect {evaluate(expr)}.to raise_error(/Resource not found: File\['x'\]/)
    end

  end

  matcher :be_the_type do |type|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |actual|
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end

    failure_message_for_should do |actual|
      "expected #{calc.string(type)}, but was #{calc.string(actual)}"
    end
  end

end
