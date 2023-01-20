require 'spec_helper'

describe Puppet::Node::Facts do
  describe "when using the indirector" do
    it "should expire any cached node instances when it is saved" do
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class).and_return(:yaml)

      expect(Puppet::Node::Facts.indirection.terminus(:yaml)).to equal(Puppet::Node::Facts.indirection.terminus(:yaml))
      terminus = Puppet::Node::Facts.indirection.terminus(:yaml)
      allow(terminus).to receive(:save)

      expect(Puppet::Node.indirection).to receive(:expire).with("me", be_a(Hash).or(be_nil))

      facts = Puppet::Node::Facts.new("me")
      Puppet::Node::Facts.indirection.save(facts)
    end

    it "should be able to delegate to the :yaml terminus" do
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class).and_return(:yaml)

      # Load now, before we stub the exists? method.
      terminus = Puppet::Node::Facts.indirection.terminus(:yaml)

      expect(terminus).to receive(:path).with("me").and_return("/my/yaml/file")
      expect(Puppet::FileSystem).to receive(:exist?).with("/my/yaml/file").and_return(false)

      expect(Puppet::Node::Facts.indirection.find("me")).to be_nil
    end

    it "should be able to delegate to the :facter terminus" do
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class).and_return(:facter)

      expect(Facter).to receive(:resolve).and_return({1 => 2})
      facts = Puppet::Node::Facts.new("me")
      expect(Puppet::Node::Facts).to receive(:new).with("me", {1 => 2}).and_return(facts)

      expect(Puppet::Node::Facts.indirection.find("me")).to equal(facts)
    end
  end
end
