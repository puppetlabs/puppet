require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:group) do
  include PuppetSpec::Files

  let(:path) { tmpfile('mode_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :group => 'users' }
  let(:group) { resource.property(:group) }

  before :each do
    # If the provider was already loaded without root, it won't have the
    # feature, so we have to add it here to test.
    Puppet::Type.type(:file).defaultprovider.has_feature :manages_ownership
  end

  describe "#insync?" do
    before :each do
      resource[:group] = ['foos', 'bars']

      allow(resource.provider).to receive(:name2gid).with('foos').and_return(1001)
      allow(resource.provider).to receive(:name2gid).with('bars').and_return(1002)
    end

    it "should fail if a group's id can't be found by name" do
      allow(resource.provider).to receive(:name2gid).and_return(nil)

      expect { group.insync?(5) }.to raise_error(/Could not find group foos/)
    end

    it "should return false if a group's id can't be found by name in noop" do
      Puppet[:noop] = true
      allow(resource.provider).to receive(:name2gid).and_return(nil)

      expect(group.insync?('notcreatedyet')).to eq(false)
    end

    it "should use the id for comparisons, not the name" do
      expect(group.insync?('foos')).to be_falsey
    end

    it "should return true if the current group is one of the desired group" do
      expect(group.insync?(1001)).to be_truthy
    end

    it "should return false if the current group is not one of the desired group" do
      expect(group.insync?(1003)).to be_falsey
    end
  end

  %w[is_to_s should_to_s].each do |prop_to_s|
    describe "##{prop_to_s}" do
      it "should use the name of the user if it can find it" do
        allow(resource.provider).to receive(:gid2name).with(1001).and_return('foos')

        expect(group.send(prop_to_s, 1001)).to eq("'foos'")
      end

      it "should use the id of the user if it can't" do
        allow(resource.provider).to receive(:gid2name).with(1001).and_return(nil)

        expect(group.send(prop_to_s, 1001)).to eq('1001')
      end
    end
  end
end
