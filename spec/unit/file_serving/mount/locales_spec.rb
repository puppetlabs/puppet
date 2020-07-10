require 'spec_helper'
require 'puppet/file_serving/mount/locales'

describe Puppet::FileServing::Mount::Locales do
  before do
    @mount = Puppet::FileServing::Mount::Locales.new("locales")

    @environment = double('environment', :module => nil)
    @options = { :recurse => true }
    @request = double('request', :environment => @environment, :options => @options)
  end

  describe  "when finding files" do
    it "should use the provided environment to find the modules" do
      expect(@environment).to receive(:modules).and_return([])

      @mount.find("foo", @request)
    end

    it "should return nil if no module can be found with a matching locale" do
      mod = double('module')
      allow(mod).to receive(:locale).with("foo/bar").and_return(nil)

      allow(@environment).to receive(:modules).and_return([mod])
      expect(@mount.find("foo/bar", @request)).to be_nil
    end

    it "should return the file path from the module" do
      mod = double('module')
      allow(mod).to receive(:locale).with("foo/bar").and_return("eh")

      allow(@environment).to receive(:modules).and_return([mod])
      expect(@mount.find("foo/bar", @request)).to eq("eh")
    end
  end

  describe "when searching for files" do
    it "should use the node's environment to find the modules" do
      expect(@environment).to receive(:modules).at_least(:once).and_return([])
      allow(@environment).to receive(:modulepath).and_return(["/tmp/modules"])

      @mount.search("foo", @request)
    end

    it "should return modulepath if no modules can be found that have locales" do
      mod = double('module')
      allow(mod).to receive(:locales?).and_return(false)

      allow(@environment).to receive(:modules).and_return([])
      allow(@environment).to receive(:modulepath).and_return(["/"])
      expect(@options).to receive(:[]=).with(:recurse, false)
      expect(@mount.search("foo/bar", @request)).to eq(["/"])
    end

    it "should return the default search module path if no modules can be found that have locales and modulepath is invalid" do
      mod = double('module')
      allow(mod).to receive(:locales?).and_return(false)

      allow(@environment).to receive(:modules).and_return([])
      allow(@environment).to receive(:modulepath).and_return([])
      expect(@mount.search("foo/bar", @request)).to eq([Puppet[:codedir]])
    end

    it "should return the locale paths for each module that has locales" do
      one = double('module', :locales? => true, :locale_directory => "/one")
      two = double('module', :locales? => true, :locale_directory => "/two")

      allow(@environment).to receive(:modules).and_return([one, two])
      expect(@mount.search("foo/bar", @request)).to eq(%w{/one /two})
    end
  end
end
