require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the unique function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'produces the unique set of chars from a String such that' do
    it 'same case is considered unique' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, "abc")
          notify{ 'test': message => 'abcbbcc'.unique }
        SOURCE
    end

    it 'different case is not considered unique' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, "abcABC")
          notify{ 'test': message => 'abcAbbBccC'.unique }
        SOURCE
    end

    it 'case independent matching can be performed with a lambda' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, "abc")
          notify{ 'test': message => 'abcAbbBccC'.unique |$x| { String($x, '%d') } }
        SOURCE
    end

    it 'the first found value in the unique set is used' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, "AbC")
          notify{ 'test': message => 'AbCAbbBccC'.unique |$x| { String($x, '%d') } }
        SOURCE
    end
  end

  context 'produces the unique set of values from an Array such that' do
    it 'ruby equality is used to compute uniqueness by default' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, ['a', 'b', 'c', 'B', 'C'])
          notify{ 'test': message => [a, b, c, a, 'B', 'C'].unique }
        SOURCE
    end

    it 'accepts a lambda to perform the value to use for uniqueness' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, ['a', 'b', 'c'])
          notify{ 'test': message => [a, b, c, a, 'B', 'C'].unique |$x| { String($x, '%d') }}
        SOURCE
    end

    it 'the first found value in the unique set is used' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, ['A', 'b', 'C'])
          notify{ 'test': message => ['A', b, 'C', a, 'B', 'c'].unique |$x| { String($x, '%d') }}
        SOURCE
    end
  end

  context 'produces the unique set of values from an Hash such that' do
    it 'resulting keys and values in hash are arrays' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, {['a'] => [10], ['b']=>[20]})
          notify{ 'test': message => {a => 10, b => 20}.unique }
        SOURCE
    end

    it 'resulting keys contain all keys with same value' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, {['a', 'b'] => [10], ['c']=>[20]})
          notify{ 'test': message => {a => 10, b => 10, c => 20}.unique }
        SOURCE
    end

    it 'resulting values contain Ruby == unique set of values' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, {['a'] => [10], ['b', 'c']=>[11, 20]})
          notify{ 'test': message => {a => 10, b => 11, c => 20}.unique |$x| { if $x > 10 {bigly} else { $x }}}
        SOURCE
    end
  end

  context 'produces the unique set of values from an Iterable' do
    it 'such as reverse_each - in reverse order' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, ['B','b','a'])
          notify{ 'test': message => ['a', 'b', 'B'].reverse_each.unique }
        SOURCE
    end

    it 'such as Integer[1,5]' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, [1,2,3,4,5])
          notify{ 'test': message => Integer[1,5].unique }
        SOURCE
    end

    it 'such as the Integer 3' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, [0,1,2])
          notify{ 'test': message => 3.unique }
        SOURCE
    end

    it 'allows lambda to be used with Iterable' do
      expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test]').with_parameter(:message, ['B','a'])
          notify{ 'test': message => ['a', 'b', 'B'].reverse_each.unique |$x| { String($x, '%d') }}
        SOURCE
    end
  end

  it 'errors when given unsupported data type as input' do
    expect do
      compile_to_catalog(<<-SOURCE)
        undef.unique
      SOURCE
    end.to raise_error(/expects an Iterable value, got Undef/)
  end


end
