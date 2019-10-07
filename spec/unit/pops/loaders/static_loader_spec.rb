require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'the static loader' do
  let(:loader) do
    loader = Puppet::Pops::Loader::StaticLoader.new()
    loader.runtime_3_init
    loader
  end

  it 'has no parent' do
    expect(loader.parent).to be(nil)
  end

  it 'identifies itself in string form' do
    expect(loader.to_s).to be_eql('(StaticLoader)')
  end

  it 'support the Loader API' do
    # it may produce things later, this is just to test that calls work as they should - now all lookups are nil.
    a_typed_name = typed_name(:function, 'foo')
    expect(loader[a_typed_name]).to be(nil)
    expect(loader.load_typed(a_typed_name)).to be(nil)
    expect(loader.find(a_typed_name)).to be(nil)
  end

  context 'provides access to resource types built into puppet' do
    %w{
      Component
      Exec
      File
      Filebucket
      Group
      Notify
      Package
      Resources
      Schedule
      Service
      Stage
      Tidy
      User
      Whit
    }.each do |name |
      it "such that #{name} is available" do
        expect(loader.load(:type, name.downcase)).to be_the_type(resource_type(name))
      end
    end
  end

  context 'provides access to app-management specific resource types built into puppet' do
    it "such that Node is available" do
      expect(loader.load(:type, 'node')).to be_the_type(resource_type('Node'))
    end
  end

  context 'without init_runtime3 initialization' do
    let(:loader) { Puppet::Pops::Loader::StaticLoader.new() }

    it 'does not provide access to resource types built into puppet' do
      expect(loader.load(:type, 'file')).to be_nil
    end
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::TypedName.new(type, name)
  end

  def resource_type(name)
    Puppet::Pops::Types::TypeFactory.resource(name)
  end

  matcher :be_the_type do |type|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |actual|
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end

    failure_message do |actual|
      "expected #{type.to_s}, but was #{actual.to_s}"
    end
  end

end
