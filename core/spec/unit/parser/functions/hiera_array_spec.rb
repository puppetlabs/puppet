require 'spec_helper'

describe 'Puppet::Parser::Functions#hiera_array' do
  before :each do
    Puppet[:hiera_config] = PuppetSpec::Files.tmpfile('hiera_config')
  end

  let :scope do Puppet::Parser::Scope.new_for_test_harness('foo') end

  it 'should require a key argument' do
    expect { scope.function_hiera_array([]) }.to raise_error(ArgumentError)
  end

  it 'should raise a useful error when nil is returned' do
    Hiera.any_instance.expects(:lookup).returns(nil)
    expect { scope.function_hiera_array(["badkey"]) }.to raise_error(Puppet::ParseError, /Could not find data item badkey/ )
  end

  it 'should use the array resolution_type' do
    Hiera.any_instance.expects(:lookup).with() { |*args| args[4].should be :array }.returns([])
    scope.function_hiera_array(['key'])
  end
end
