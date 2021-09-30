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
    expect { versioncmp('a,b') }.to raise_error(/expects between 2 and 3 arguments, got 1/)
  end

  it 'should raise an Error if there is more than 3 arguments' do
    expect { versioncmp('a,b','foo', false, 'bar') }.to raise_error(/expects between 2 and 3 arguments, got 4/)
  end

  it "should call Puppet::Util::Package.versioncmp (included in scope)" do
    expect(Puppet::Util::Package).to receive(:versioncmp).with('1.2', '1.3', false).and_return(-1)

    expect(versioncmp('1.2', '1.3')).to eq(-1)
  end

  context "when ignore_trailing_zeroes is true" do
    it "should equate versions with 2 elements and dots but with unnecessary zero" do
      expect(versioncmp("10.1.0", "10.1", true)).to eq(0)
    end

    it "should equate versions with 1 element and dot but with unnecessary zero" do
      expect(versioncmp("11.0", "11", true)).to eq(0)
    end

    it "should equate versions with 1 element and dot but with unnecessary zeros" do
      expect(versioncmp("11.00", "11", true)).to eq(0)
    end

    it "should equate versions with dots and iregular zeroes" do
      expect(versioncmp("11.0.00", "11", true)).to eq(0)
    end

    it "should equate versions with dashes" do
      expect(versioncmp("10.1-0", "10.1.0-0", true)).to eq(0)
    end

    it "should compare versions with dashes after normalization" do
      expect(versioncmp("10.1-1", "10.1.0-0", true)).to eq(1)
    end

    it "should not normalize versions if zeros are not trailing" do
      expect(versioncmp("1.1", "1.0.1", true)).to eq(1)
    end
  end

  context "when ignore_trailing_zeroes is false" do
    it "should not equate versions if zeros are not trailing" do
      expect(versioncmp("1.1", "1.0.1")).to eq(1)
    end
  end
end
