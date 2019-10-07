require 'spec_helper'

require 'puppet/node'

describe Puppet::Node do
  describe "when delegating indirection calls" do
    before do
      Puppet::Node.indirection.reset_terminus_class
      Puppet::Node.indirection.cache_class = nil

      @name = "me"
      @node = Puppet::Node.new(@name)
    end

    it "should be able to use the yaml terminus" do
      allow(Puppet::Node.indirection).to receive(:terminus_class).and_return(:yaml)

      # Load now, before we stub the exists? method.
      terminus = Puppet::Node.indirection.terminus(:yaml)

      expect(terminus).to receive(:path).with(@name).and_return("/my/yaml/file")

      expect(Puppet::FileSystem).to receive(:exist?).with("/my/yaml/file").and_return(false)
      expect(Puppet::Node.indirection.find(@name)).to be_nil
    end

    it "should be able to use the plain terminus" do
      allow(Puppet::Node.indirection).to receive(:terminus_class).and_return(:plain)

      # Load now, before we stub the exists? method.
      Puppet::Node.indirection.terminus(:plain)

      expect(Puppet::Node).to receive(:new).with(@name).and_return(@node)

      expect(Puppet::Node.indirection.find(@name)).to equal(@node)
    end

    describe "and using the memory terminus" do
      before do
        @name = "me"
        @terminus = Puppet::Node.indirection.terminus(:memory)
        allow(Puppet::Node.indirection).to receive(:terminus).and_return(@terminus)
        @node = Puppet::Node.new(@name)
      end

      after do
        @terminus.instance_variable_set(:@instances, {})
      end

      it "should find no nodes by default" do
        expect(Puppet::Node.indirection.find(@name)).to be_nil
      end

      it "should be able to find nodes that were previously saved" do
        Puppet::Node.indirection.save(@node)
        expect(Puppet::Node.indirection.find(@name)).to equal(@node)
      end

      it "should replace existing saved nodes when a new node with the same name is saved" do
        Puppet::Node.indirection.save(@node)
        two = Puppet::Node.new(@name)
        Puppet::Node.indirection.save(two)
        expect(Puppet::Node.indirection.find(@name)).to equal(two)
      end

      it "should be able to remove previously saved nodes" do
        Puppet::Node.indirection.save(@node)
        Puppet::Node.indirection.destroy(@node.name)
        expect(Puppet::Node.indirection.find(@name)).to be_nil
      end

      it "should fail when asked to destroy a node that does not exist" do
        expect { Puppet::Node.indirection.destroy(@node) }.to raise_error(ArgumentError)
      end
    end
  end
end
