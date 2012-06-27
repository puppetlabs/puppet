require 'puppet'
require 'hiera'
require 'spec_helper'

describe 'Puppet::Parser::Functions#hiera_hash' do
  before do
    Puppet::Parser::Functions.function(:hiera_hash)
    @scope = Puppet::Parser::Scope.new
    configfile = File.join(File.dirname(Puppet.settings[:config]), "hiera.yaml")
    File.stubs(:exist?).with(configfile).returns true
    YAML.stubs(:load_file).with(configfile).returns(Hash.new)
  end

  it 'should require a key argument' do
    expect { @scope.function_hiera_hash([]) }.should raise_error(Puppet::ParseError)
  end

  it 'should raise a useful error when nil is returned' do
    Hiera.any_instance.expects(:lookup).returns(nil)
    expect { @scope.function_hiera_hash("badkey") }.should raise_error(Puppet::ParseError, /Could not find data item badkey/ )
  end

  it 'should use the hash resolution_type' do
    scope = hacked_scope
    Hiera.any_instance.expects(:lookup).with('key', nil, scope, nil, :hash).returns({})
    scope.function_hiera_hash(['key'])
  end
end

