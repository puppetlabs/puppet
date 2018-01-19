require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'puppet_spec/files'

describe 'the module_directory function' do
  include PuppetSpec::Compiler
  include Matchers::Resource
  include PuppetSpec::Files

  it 'returns first found module from one or more given names' do
    mod = mock 'module'
    mod.stubs(:path).returns('expected_path')
    Puppet[:code] = "notify { module_directory('one', 'two'):}"
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.environment.stubs(:module).with('one').returns(nil)
    compiler.environment.stubs(:module).with('two').returns(mod)
    expect(compiler.compile()).to have_resource("Notify[expected_path]")
  end

  it 'returns first found module from one or more given names in an array' do
    mod = mock 'module'
    mod.stubs(:path).returns('expected_path')
    Puppet[:code] = "notify { module_directory(['one', 'two']):}"
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.environment.stubs(:module).with('one').returns(nil)
    compiler.environment.stubs(:module).with('two').returns(mod)
    expect(compiler.compile()).to have_resource("Notify[expected_path]")
  end

  it 'returns undef when none of the modules were found' do
    mod = mock 'module'
    mod.stubs(:path).returns('expected_path')
    Puppet[:code] = "notify { String(type(module_directory('one', 'two'))):}"
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.environment.stubs(:module).with('one').returns(nil)
    compiler.environment.stubs(:module).with('two').returns(nil)
    expect(compiler.compile()).to have_resource("Notify[Undef]")
  end
end
