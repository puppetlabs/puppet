require 'spec_helper'

describe 'Puppet::Parser::Functions#hiera_array' do
  let(:scope) { PuppetlabsSpec::PuppetInternals.scope }

  it 'should require a key argument' do
    expect { scope.function_hiera_array([]) }.to raise_error(Puppet::ParseError)
  end

  it 'should raise a useful error when nil is returned' do
    Hiera.any_instance.expects(:lookup).returns(nil)
    expect { scope.function_hiera_array("badkey") }.to raise_error(Puppet::ParseError, /Could not find data item badkey/ )
  end

  it 'should use the array resolution_type' do
    Hiera.any_instance.expects(:lookup).with() { |*args| args[4].should be :array }.returns([])
    scope.function_hiera_array(['key'])
  end
end
