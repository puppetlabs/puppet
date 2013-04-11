require 'spec_helper'

describe 'Puppet::Parser::Functions#hiera' do
  let :scope do Puppet::Parser::Scope.new_for_test_harness('foo') end

  it 'should require a key argument' do
    expect { scope.function_hiera([]) }.to raise_error(ArgumentError)
  end

  it 'should raise a useful error when nil is returned' do
    Hiera.any_instance.expects(:lookup).returns(nil)
    expect { scope.function_hiera(["badkey"]) }.to raise_error(Puppet::ParseError, /Could not find data item badkey/ )
  end

  it 'should use the priority resolution_type' do
    Hiera.any_instance.expects(:lookup).with() { |*args| args[4].should be :priority }.returns('foo_result')
    scope.function_hiera(['key']).should == 'foo_result'
  end
end
