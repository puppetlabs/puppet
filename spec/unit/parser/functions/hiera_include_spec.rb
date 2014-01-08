require 'spec_helper'
require 'puppet_spec/scope'

describe 'Puppet::Parser::Functions#hiera_include' do
  include PuppetSpec::Scope

  let :scope do create_test_scope_for_node('foo') end

  before :each do
    Puppet[:hiera_config] = PuppetSpec::Files.tmpfile('hiera_config')
  end

  it 'should require a key argument' do
    expect { scope.function_hiera_include([]) }.to raise_error(ArgumentError)
  end

  it 'should raise a useful error when nil is returned' do
    HieraPuppet.expects(:lookup).returns(nil)
    expect { scope.function_hiera_include(["badkey"]) }.
      to raise_error(Puppet::ParseError, /Could not find data item badkey/ )
  end

  it 'should use the array resolution_type' do
    HieraPuppet.expects(:lookup).with() { |*args| args[4].should be(:array) }.returns(['someclass'])
    expect { scope.function_hiera_include(['key']) }.to raise_error(Puppet::Error, /Could not find class someclass/)
  end

  it 'should call the `include` function with the classes' do
    HieraPuppet.expects(:lookup).returns %w[foo bar baz]

    scope.expects(:function_include).with([%w[foo bar baz]])
    scope.function_hiera_include(['key'])
  end

  it 'should not raise an error if the resulting hiera lookup returns an empty array' do
    HieraPuppet.expects(:lookup).returns []
    expect { scope.function_hiera_include(['key']) }.to_not raise_error
  end
end
