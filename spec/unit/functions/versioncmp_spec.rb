require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe "the versioncmp function" do
  before(:each) do
    loaders = Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))
    Puppet.push_context({:loaders => loaders}, "test-examples")
  end

  after(:each) do
    Puppet::pop_context()
  end

  def versioncmp(*args)
    Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'versioncmp').call({}, *args)
  end

  let(:type_parser) { Puppet::Pops::Types::TypeParser.singleton }

  it 'should raise an Error if there is less than 2 arguments' do
    expect { versioncmp('a,b') }.to raise_error(/expects 2 arguments, got 1/)
  end

  it 'should raise an Error if there is more than 2 arguments' do
    expect { versioncmp('a,b','foo', 'bar') }.to raise_error(/expects 2 arguments, got 3/)
  end

  it "should call Puppet::Util::Package.versioncmp (included in scope)" do
    expect(Puppet::Util::Package).to receive(:versioncmp).with('1.2', '1.3').and_return(-1)

    expect(versioncmp('1.2', '1.3')).to eq(-1)
  end
end
