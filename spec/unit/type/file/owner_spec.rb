require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:owner) do
  include PuppetSpec::Files

  let(:path) { tmpfile('mode_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :owner => 'joeuser' }
  let(:owner) { resource.property(:owner) }

  before :each do
    allow(Puppet.features).to receive(:root?).and_return(true)
  end

  describe "#insync?" do
    before :each do
      resource[:owner] = ['foo', 'bar']

      allow(resource.provider).to receive(:name2uid).with('foo').and_return(1001)
      allow(resource.provider).to receive(:name2uid).with('bar').and_return(1002)
    end

    it "should fail if an owner's id can't be found by name" do
      allow(resource.provider).to receive(:name2uid).and_return(nil)

      expect { owner.insync?(5) }.to raise_error(/Could not find user foo/)
    end

    it "should return false if an owner's id can't be found by name in noop" do
      Puppet[:noop] = true
      allow(resource.provider).to receive(:name2uid).and_return(nil)

      expect(owner.insync?('notcreatedyet')).to eq(false)
    end

    it "should use the id for comparisons, not the name" do
      expect(owner.insync?('foo')).to be_falsey
    end

    it "should return true if the current owner is one of the desired owners" do
      expect(owner.insync?(1001)).to be_truthy
    end

    it "should return false if the current owner is not one of the desired owners" do
      expect(owner.insync?(1003)).to be_falsey
    end
  end

  %w[is_to_s should_to_s].each do |prop_to_s|
    describe "##{prop_to_s}" do
      it "should use the name of the user if it can find it" do
        allow(resource.provider).to receive(:uid2name).with(1001).and_return('foo')

        expect(owner.send(prop_to_s, 1001)).to eq("'foo'")
      end

      it "should use the id of the user if it can't" do
        allow(resource.provider).to receive(:uid2name).with(1001).and_return(nil)

        expect(owner.send(prop_to_s, 1001)).to eq('1001')
      end
    end
  end
end
