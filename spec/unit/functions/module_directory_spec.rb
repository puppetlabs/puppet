require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'puppet_spec/files'

describe 'the module_directory function' do
  include PuppetSpec::Compiler
  include Matchers::Resource
  include PuppetSpec::Files

  it 'returns first found module from one or more given names' do
    mod = double('module')
    allow(mod).to receive(:path).and_return('expected_path')
    Puppet.push_context({code: "notify { module_directory('one', 'two'):}"})
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    allow(compiler.environment).to receive(:module).with('one').and_return(nil)
    allow(compiler.environment).to receive(:module).with('two').and_return(mod)
    expect(compiler.compile()).to have_resource("Notify[expected_path]")
  end

  it 'returns first found module from one or more given names in an array' do
    mod = double('module')
    allow(mod).to receive(:path).and_return('expected_path')
    Puppet.push_context({code: "notify { module_directory(['one', 'two']):}"})
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    allow(compiler.environment).to receive(:module).with('one').and_return(nil)
    allow(compiler.environment).to receive(:module).with('two').and_return(mod)
    expect(compiler.compile()).to have_resource("Notify[expected_path]")
  end

  it 'returns undef when none of the modules were found' do
    mod = double('module')
    allow(mod).to receive(:path).and_return('expected_path')
    Puppet.push_context({code: "notify { String(type(module_directory('one', 'two'))):}"})
    node = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    allow(compiler.environment).to receive(:module).with('one').and_return(nil)
    allow(compiler.environment).to receive(:module).with('two').and_return(nil)
    expect(compiler.compile()).to have_resource("Notify[Undef]")
  end
end
