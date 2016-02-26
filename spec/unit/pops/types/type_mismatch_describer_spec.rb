require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types

describe 'the type mismatch describer' do
  include PuppetSpec::Compiler

  it 'will report a mismatch between a hash and a struct with details' do
    code = <<-CODE
      function f(Hash[String,String] $h) {
         $h['a']
      }
      f({'a' => 'a', 'b' => 23})
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects a Hash\[String, String\] value, got Struct\[\{'a'=>String, 'b'=>Integer\}\]/)
  end

  it 'will report a mismatch between a array and tuple with details' do
    code = <<-CODE
      function f(Array[String] $h) {
         $h[0]
      }
      f(['a', 23])
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects an Array\[String\] value, got Tuple\[String, Integer\]/)
  end

  it 'will not report details for a mismatch between an array and a struct' do
    code = <<-CODE
      function f(Array[String] $h) {
         $h[0]
      }
      f({'a' => 'a string', 'b' => 23})
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects an Array value, got Struct/)
  end

  it 'will not report details for a mismatch between a hash and a tuple' do
    code = <<-CODE
      function f(Hash[String,String] $h) {
         $h['a']
      }
      f(['a', 23])
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects a Hash value, got Tuple/)
  end

  it 'will report a mismatch against an aliased type correctly' do
    code = <<-CODE
      type UnprivilegedPort = Integer[1024,65537]

      function check_port(UnprivilegedPort $port) {
         $port
      }
      check_port(34)
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /parameter 'port' expects an UnprivilegedPort value, got Integer\[34, 34\]/)
  end

  context 'when using present tense' do
    let(:parser) { TypeParser.new }
    let(:subject) { TypeMismatchDescriber.singleton }
    it 'reports a missing parameter as "has no parameter"' do
      t = parser.parse('Struct[{a=>String}]')
      expect { subject.validate_parameters('v', t, {'a'=>'a','b'=>'b'}, false, :present) }.to raise_error(Puppet::Error, "v: has no parameter named 'b'")
    end

    it 'reports a missing value as "expects a value"' do
      t = parser.parse('Struct[{a=>String,b=>String}]')
      expect { subject.validate_parameters('v', t, {'a'=>'a'}, false, :present) }.to raise_error(Puppet::Error, "v: expects a value for parameter 'b'")
    end

    it 'reports a missing block as "expects a block"' do
      callable = parser.parse('Callable[String,String,Callable]')
      args_tuple = parser.parse('Tuple[String,String]')
      dispatch = Functions::Dispatch.new(callable, 'foo', ['a','b'], 'block', nil, nil, false)
      expect(subject.describe_signatures('function', [dispatch], args_tuple, :present)).to eq("'function' expects a block")
    end

    it 'reports an unexpected block as "does not expect a block"' do
      callable = parser.parse('Callable[String,String]')
      args_tuple = parser.parse('Tuple[String,String,Callable]')
      dispatch = Functions::Dispatch.new(callable, 'foo', ['a','b'], nil, nil, nil, false)
      expect(subject.describe_signatures('function', [dispatch], args_tuple, :present)).to eq("'function' does not expect a block")
    end
  end

  context 'when using past tense' do
    let(:parser) { TypeParser.new }
    let(:subject) { TypeMismatchDescriber.singleton }
    it 'reports a missing parameter as "did not have a parameter"' do
      t = parser.parse('Struct[{a=>String}]')
      expect { subject.validate_parameters('v', t, {'a'=>'a','b'=>'b'}, false, :past) }.to raise_error(Puppet::Error, "v: did not have a parameter named 'b'")
    end

    it 'reports a missing value as "expected a value"' do
      t = parser.parse('Struct[{a=>String,b=>String}]')
      expect { subject.validate_parameters('v', t, {'a'=>'a'}, false, :past) }.to raise_error(Puppet::Error, "v: expected a value for parameter 'b'")
    end

    it 'reports a missing block as "expected a block"' do
      callable = parser.parse('Callable[String,String,Callable]')
      args_tuple = parser.parse('Tuple[String,String]')
      dispatch = Functions::Dispatch.new(callable, 'foo', ['a','b'], 'block', nil, nil, false)
      expect(subject.describe_signatures('function', [dispatch], args_tuple, :past)).to eq("'function' expected a block")
    end

    it 'reports an unexpected block as "did not expect a block"' do
      callable = parser.parse('Callable[String,String]')
      args_tuple = parser.parse('Tuple[String,String,Callable]')
      dispatch = Functions::Dispatch.new(callable, 'foo', ['a','b'], nil, nil, nil, false)
      expect(subject.describe_signatures('function', [dispatch], args_tuple, :past)).to eq("'function' did not expect a block")
    end
  end
end
end
end
