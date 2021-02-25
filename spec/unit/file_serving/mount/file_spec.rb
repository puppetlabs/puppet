require 'spec_helper'
require 'puppet/file_serving/mount/file'

module FileServingMountTesting
  def stub_facter(hostname)
    allow(Facter).to receive(:value).with('networking.hostname').and_return(hostname.sub(/\..+/, ''))
    allow(Facter).to receive(:value).with('networking.domain').and_return(hostname.sub(/^[^.]+\./, ''))
  end
end

describe Puppet::FileServing::Mount::File do
  it "should be invalid if it does not have a path" do
    expect { Puppet::FileServing::Mount::File.new("foo").validate }.to raise_error(ArgumentError)
  end

  it "should be valid if it has a path" do
    allow(FileTest).to receive(:directory?).and_return(true)
    allow(FileTest).to receive(:readable?).and_return(true)
    mount = Puppet::FileServing::Mount::File.new("foo")
    mount.path = "/foo"
    expect { mount.validate }.not_to raise_error
  end

  describe "when setting the path" do
    before do
      @mount = Puppet::FileServing::Mount::File.new("test")
      @dir = "/this/path/does/not/exist"
    end

    it "should fail if the path is not a directory" do
      expect(FileTest).to receive(:directory?).and_return(false)
      expect { @mount.path = @dir }.to raise_error(ArgumentError)
    end

    it "should fail if the path is not readable" do
      expect(FileTest).to receive(:directory?).and_return(true)
      expect(FileTest).to receive(:readable?).and_return(false)
      expect { @mount.path = @dir }.to raise_error(ArgumentError)
    end
  end

  describe "when substituting hostnames and ip addresses into file paths" do
    include FileServingMountTesting

    before do
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(FileTest).to receive(:readable?).and_return(true)
      @mount = Puppet::FileServing::Mount::File.new("test")
      @host = "host.domain.com"
    end

    after :each do
      Puppet::FileServing::Mount::File.instance_variable_set(:@localmap, nil)
    end

    it "should replace incidences of %h in the path with the client's short name" do
      @mount.path = "/dir/%h/yay"
      expect(@mount.path(@host)).to eq("/dir/host/yay")
    end

    it "should replace incidences of %H in the path with the client's fully qualified name" do
      @mount.path = "/dir/%H/yay"
      expect(@mount.path(@host)).to eq("/dir/host.domain.com/yay")
    end

    it "should replace incidences of %d in the path with the client's domain name" do
      @mount.path = "/dir/%d/yay"
      expect(@mount.path(@host)).to eq("/dir/domain.com/yay")
    end

    it "should perform all necessary replacements" do
      @mount.path = "/%h/%d/%H"
      expect(@mount.path(@host)).to eq("/host/domain.com/host.domain.com")
    end

    it "should use local host information if no client data is provided" do
      stub_facter("myhost.mydomain.com")
      @mount.path = "/%h/%d/%H"
      expect(@mount.path).to eq("/myhost/mydomain.com/myhost.mydomain.com")
    end
  end

  describe "when determining the complete file path" do
    include FileServingMountTesting

    before do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(FileTest).to receive(:readable?).and_return(true)
      @mount = Puppet::FileServing::Mount::File.new("test")
      @mount.path = "/mount"
      stub_facter("myhost.mydomain.com")
      @host = "host.domain.com"
    end

    it "should return nil if the file is absent" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
      expect(@mount.complete_path("/my/path", nil)).to be_nil
    end

    it "should write a log message if the file is absent" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(false)

      expect(Puppet).to receive(:info).with("File does not exist or is not accessible: /mount/my/path")

      @mount.complete_path("/my/path", nil)
    end

    it "should return the file path if the file is present" do
      allow(Puppet::FileSystem).to receive(:exist?).with("/my/path").and_return(true)
      expect(@mount.complete_path("/my/path", nil)).to eq("/mount/my/path")
    end

    it "should treat a nil file name as the path to the mount itself" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      expect(@mount.complete_path(nil, nil)).to eq("/mount")
    end

    it "should use the client host name if provided in the options" do
      @mount.path = "/mount/%h"
      expect(@mount.complete_path("/my/path", @host)).to eq("/mount/host/my/path")
    end

    it "should perform replacements on the base path" do
      @mount.path = "/blah/%h"
      expect(@mount.complete_path("/my/stuff", @host)).to eq("/blah/host/my/stuff")
    end

    it "should not perform replacements on the per-file path" do
      @mount.path = "/blah"
      expect(@mount.complete_path("/%h/stuff", @host)).to eq("/blah/%h/stuff")
    end

    it "should look for files relative to its base directory" do
      expect(@mount.complete_path("/my/stuff", @host)).to eq("/mount/my/stuff")
    end
  end

  describe "when finding files" do
    include FileServingMountTesting

    before do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(FileTest).to receive(:readable?).and_return(true)
      @mount = Puppet::FileServing::Mount::File.new("test")
      @mount.path = "/mount"
      stub_facter("myhost.mydomain.com")
      @host = "host.domain.com"

      @request = double('request', :node => "foo")
    end

    it "should return the results of the complete file path" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
      expect(@mount).to receive(:complete_path).with("/my/path", "foo").and_return("eh")
      expect(@mount.find("/my/path", @request)).to eq("eh")
    end
  end

  describe "when searching for files" do
    include FileServingMountTesting

    before do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(FileTest).to receive(:readable?).and_return(true)
      @mount = Puppet::FileServing::Mount::File.new("test")
      @mount.path = "/mount"
      stub_facter("myhost.mydomain.com")
      @host = "host.domain.com"

      @request = double('request', :node => "foo")
    end

    it "should return the results of the complete file path as an array" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
      expect(@mount).to receive(:complete_path).with("/my/path", "foo").and_return("eh")
      expect(@mount.search("/my/path", @request)).to eq(["eh"])
    end

    it "should return nil if the complete path is nil" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
      expect(@mount).to receive(:complete_path).with("/my/path", "foo").and_return(nil)
      expect(@mount.search("/my/path", @request)).to be_nil
    end
  end
end
