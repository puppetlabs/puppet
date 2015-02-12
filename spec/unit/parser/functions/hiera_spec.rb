require 'spec_helper'
require 'puppet_spec/scope'

describe 'Puppet::Parser::Functions#hiera' do
  include PuppetSpec::Scope

  let :scope do create_test_scope_for_node('foo') end

  it 'should require a key argument' do
    expect { scope.function_hiera([]) }.to raise_error(ArgumentError)
  end

  it 'should raise a useful error when nil is returned' do
    Hiera.any_instance.expects(:lookup).returns(nil)
    expect { scope.function_hiera(["badkey"]) }.to raise_error(Puppet::ParseError, /Could not find data item badkey/ )
  end

  it 'should use the priority resolution_type' do
    Hiera.any_instance.expects(:lookup).with() { |*args| args[4].should be(:priority) }.returns('foo_result')
    scope.function_hiera(['key']).should == 'foo_result'
  end
end
