require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'
require 'puppet_spec/compiler'

describe 'the assert_type function' do
  include PuppetSpec::Compiler

  after(:all) { Puppet::Pops::Loaders.clear }

  let(:loaders) { Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, [])) }
  let(:func) { loaders.puppet_system_loader.load(:function, 'assert_type') }

  it 'asserts compliant type by returning the value' do
    expect(func.call({}, type(String), 'hello world')).to eql('hello world')
  end

  it 'accepts type given as a String' do
    expect(func.call({}, 'String', 'hello world')).to eql('hello world')
  end

  it 'asserts non compliant type by raising an error' do
    expect do
      func.call({}, type(Integer), 'hello world')
    end.to raise_error(Puppet::Pops::Types::TypeAssertionError, /expected an Integer value, got String/)
  end

  it 'checks that first argument is a type' do
    expect do
      func.call({}, 10, 10)
    end.to raise_error(ArgumentError, "'assert_type' expects one of:
  (Type type, Any value, Callable[Type, Type] block?)
    rejected: parameter 'type' expects a Type value, got Integer
  (String type_string, Any value, Callable[Type, Type] block?)
    rejected: parameter 'type_string' expects a String value, got Integer")
  end

  it 'allows the second arg to be undef/nil)' do
    expect do
      func.call({}, optional(String), nil)
    end.to_not raise_error
  end

  it 'can be called with a callable that receives a specific type' do
    expected, actual, actual2 = func.call({}, 'Optional[String]', 1) { |expected, actual| [expected, actual, actual] }
    expect(expected.to_s).to eql('Optional[String]')
    expect(actual.to_s).to eql('Integer[1, 1]')
    expect(actual2.to_s).to eql('Integer[1, 1]')
  end

  def optional(type_ref)
    Puppet::Pops::Types::TypeFactory.optional(type(type_ref))
  end

  def type(type_ref)
    Puppet::Pops::Types::TypeFactory.type_of(type_ref)
  end

  it 'can validate a resource type' do
    expect(eval_and_collect_notices("assert_type(Type[Resource], File['/tmp/test']) notice('ok')")).to eq(['ok'])
  end

  it 'can validate a type alias' do
    code = <<-CODE
      type UnprivilegedPort = Integer[1024,65537]
      assert_type(UnprivilegedPort, 5432)
      notice('ok')
    CODE
    expect(eval_and_collect_notices(code)).to eq(['ok'])
  end

  it 'can validate a type alias passed as a String' do
    code = <<-CODE
      type UnprivilegedPort = Integer[1024,65537]
      assert_type('UnprivilegedPort', 5432)
      notice('ok')
    CODE
    expect(eval_and_collect_notices(code)).to eq(['ok'])
  end

  it 'can validate and fail using a type alias' do
    code = <<-CODE
      type UnprivilegedPort = Integer[1024,65537]
      assert_type(UnprivilegedPort, 345)
      notice('ok')
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expected an UnprivilegedPort = Integer\[1024, 65537\] value, got Integer\[345, 345\]/)
  end

  it 'will use infer_set to report detailed information about complex mismatches' do
    code = <<-CODE
      assert_type(Struct[{a=>Integer,b=>Boolean}], {a=>hej,x=>s})
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error,
      /entry 'a' expected an Integer value, got String.*expected a value for key 'b'.*unrecognized key 'x'/m)
  end
end
