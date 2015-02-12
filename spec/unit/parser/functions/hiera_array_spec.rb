require 'spec_helper'
require 'puppet_spec/scope'

describe 'Puppet::Parser::Functions#hiera_array' do
  include PuppetSpec::Scope

  before :each do
    Puppet[:hiera_config] = PuppetSpec::Files.tmpfile('hiera_config')
  end

  let :scope do create_test_scope_for_node('foo') end

  it 'should require a key argument' do
    expect { scope.function_hiera_array([]) }.to raise_error(ArgumentError)
  end

  it 'should raise a useful error when nil is returned' do
    Hiera.any_instance.expects(:lookup).returns(nil)
    expect { scope.function_hiera_array(["badkey"]) }.to raise_error(Puppet::ParseError, /Could not find data item badkey/ )
  end

  it 'should use the array resolution_type' do
    Hiera.any_instance.expects(:lookup).with() { |*args| args[4].should be(:array) }.returns([])
    scope.function_hiera_array(['key'])
  end
end
