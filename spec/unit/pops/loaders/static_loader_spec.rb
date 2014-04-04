require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'static loader' do
  it 'has no parent' do
    expect(Puppet::Pops::Loader::StaticLoader.new.parent).to be(nil)
  end

  it 'identifies itself in string form' do
    expect(Puppet::Pops::Loader::StaticLoader.new.to_s).to be_eql('(StaticLoader)')
  end

  it 'support the Loader API' do
    # it may produce things later, this is just to test that calls work as they should - now all lookups are nil.
    loader = Puppet::Pops::Loader::StaticLoader.new()
    a_typed_name = typed_name(:function, 'foo')
    expect(loader[a_typed_name]).to be(nil)
    expect(loader.load_typed(a_typed_name)).to be(nil)
    expect(loader.find(a_typed_name)).to be(nil)
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end