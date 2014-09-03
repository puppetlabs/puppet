require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'the static loader' do
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

  context 'provides access to logging functions' do
    let(:loader) { loader = Puppet::Pops::Loader::StaticLoader.new() }
    # Ensure all logging functions produce output
    before(:each) { Puppet::Util::Log.level = :debug }

    Puppet::Util::Log.levels.each do |level|
      it "defines the function #{level.to_s}" do
        expect(loader.load(:function, level).class.name).to eql(level.to_s)
      end

      it 'and #{level.to_s} can be called' do
        expect(loader.load(:function, level).call({}, 'yay').to_s).to eql('yay')
      end

      it "uses the evaluator to format output" do
        expect(loader.load(:function, level).call({}, ['yay', 'surprise']).to_s).to eql('[yay, surprise]')
      end

      it 'outputs name of source (scope) by passing it to the Log utility' do
        the_scope = {}
        Puppet::Util::Log.any_instance.expects(:source=).with(the_scope)
        loader.load(:function, level).call(the_scope, 'x')
      end
    end
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end