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
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /'f' parameter 'h' entry 'b' expects a String value, got Integer/)
  end

  it 'will report a mismatch between a array and tuple with details' do
    code = <<-CODE
      function f(Array[String] $h) {
         $h[0]
      }
      f(['a', 23])
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /'f' parameter 'h' index 1 expects a String value, got Integer/)
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

  it 'will report an array size mismatch' do
    code = <<-CODE
      function f(Array[String,1,default] $h) {
        $h[0]
      }
      f([])
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects size to be at least 1, got 0/)
  end

  it 'will report a hash size mismatch' do
    code = <<-CODE
      function f(Hash[String,String,1,default] $h) {
         $h['a']
      }
      f({})
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects size to be at least 1, got 0/)
  end

  it 'will include the aliased type when reporting a mismatch that involves an alias' do
    code = <<-CODE
      type UnprivilegedPort = Integer[1024,65537]

      function check_port(UnprivilegedPort $port) {}
      check_port(34)
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /parameter 'port' expects an UnprivilegedPort = Integer\[1024, 65537\] value, got Integer\[34, 34\]/)
  end

  it 'will include the aliased type when reporting a mismatch that involves an alias nested in another type' do
    code = <<-CODE
      type UnprivilegedPort = Integer[1024,65537]
      type PortMap = Hash[UnprivilegedPort,String]

      function check_port(PortMap $ports) {}
      check_port({ 34 => 'some service'})
    CODE
    expect { eval_and_collect_notices(code) }.to(raise_error(Puppet::Error,
      /parameter 'ports' expects a PortMap = Hash\[UnprivilegedPort = Integer\[1024, 65537\], String\] value, got Hash\[Integer\[34, 34\], String\[12, 12\]\]/))
  end

  it 'will not include the aliased type more than once when reporting a mismatch that involves an alias that is self recursive' do
    code = <<-CODE
      type Tree = Hash[String,Tree]

      function check_tree(Tree $tree) {}
      check_tree({ 'x' => {'y' => {32 => 'n'}}})
    CODE
    expect { eval_and_collect_notices(code) }.to(raise_error(Puppet::Error,
      /parameter 'tree' entry 'x' entry 'y' expects a Tree = Hash\[String, Tree\] value, got Hash\[Integer\[32, 32\], String\[1, 1\]\]/))
  end

  it 'will use type normalization' do
    code = <<-CODE
      type EVariants = Variant[Enum[a,b],Enum[b,c],Enum[c,d]]

      function check_enums(EVariants $evars) {}
      check_enums('n')
    CODE
    expect { eval_and_collect_notices(code) }.to(raise_error(Puppet::Error,
       /parameter 'evars' expects a match for EVariants = Enum\['a', 'b', 'c', 'd'\], got 'n'/))
  end

  context 'when reporting a mismatch between' do
    let(:parser) { TypeParser.new }
    let(:subject) { TypeMismatchDescriber.singleton }

    context 'hash and struct' do
      it 'reports a size mismatch when hash has unlimited size' do
        expected = parser.parse('Struct[{a=>Integer,b=>Integer}]')
        actual = parser.parse('Hash[String,Integer]')
        expect(subject.describe_mismatch('', expected, actual)).to eq('expected size to be 2, got unlimited')
      end

      it 'reports a size mismatch when hash has specified but incorrect size' do
        expected = parser.parse('Struct[{a=>Integer,b=>Integer}]')
        actual = parser.parse('Hash[String,Integer,1,1]')
        expect(subject.describe_mismatch('', expected, actual)).to eq('expected size to be 2, got 1')
      end

      it 'reports a full type mismatch when size is correct but hash value type is incorrect' do
        expected = parser.parse('Struct[{a=>Integer,b=>String}]')
        actual = parser.parse('Hash[String,Integer,2,2]')
        expect(subject.describe_mismatch('', expected, actual)).to eq("expected a Struct[{'a' => Integer, 'b' => String}] value, got Hash[String, Integer]")
      end
    end
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
