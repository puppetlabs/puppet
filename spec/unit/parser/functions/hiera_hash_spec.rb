require 'puppet'
require 'hiera'
require 'spec_helper'

describe 'Puppet::Parser::Functions#hiera_hash' do
  it 'should require a key argument' do
    Puppet::Parser::Functions.function(:hiera_hash)
    @scope = Puppet::Parser::Scope.new
    expect { @scope.function_hiera_hash([]) }.should raise_error(Puppet::ParseError)
  end
end
