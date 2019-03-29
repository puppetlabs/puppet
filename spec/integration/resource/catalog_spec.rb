require 'spec_helper'

describe Puppet::Resource::Catalog do
  describe "when using the indirector" do
    before do
      # This is so the tests work w/out networking.
      allow(Facter).to receive(:to_hash).and_return({"hostname" => "foo.domain.com"})
      allow(Facter).to receive(:value).and_return("eh")
    end

    it "should be able to delegate to the :yaml terminus" do
      allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class).and_return(:yaml)

      # Load now, before we stub the exists? method.
      terminus = Puppet::Resource::Catalog.indirection.terminus(:yaml)
      expect(terminus).to receive(:path).with("me").and_return("/my/yaml/file")

      expect(Puppet::FileSystem).to receive(:exist?).with("/my/yaml/file").and_return(false)
      expect(Puppet::Resource::Catalog.indirection.find("me")).to be_nil
    end

    it "should be able to delegate to the :compiler terminus" do
      allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class).and_return(:compiler)

      # Load now, before we stub the exists? method.
      compiler = Puppet::Resource::Catalog.indirection.terminus(:compiler)

      node = double('node', :add_server_facts => nil, :trusted_data= => nil, :environment => nil)

      expect(Puppet::Node.indirection).to receive(:find).and_return(node)
      expect(compiler).to receive(:compile).with(node, anything).and_return(nil)

      expect(Puppet::Resource::Catalog.indirection.find("me")).to be_nil
    end

    it "should pass provided node information directly to the terminus" do
      node = double('node')
      terminus = double('terminus')
      allow(terminus).to receive(:validate)
      expect(terminus).to receive(:find) { |request| expect(request.options[:use_node]).to eq(node) }

      allow(Puppet::Resource::Catalog.indirection).to receive(:terminus).and_return(terminus)

      Puppet::Resource::Catalog.indirection.find("me", :use_node => node)
    end
  end
end
