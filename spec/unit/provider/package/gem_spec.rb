#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:gem)

describe provider_class do
  describe "when installing" do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed
      )
    end

    let(:provider) do
      provider = provider_class.new
      provider.resource = resource
      provider
    end

    it "should use the path to the gem" do
      provider_class.stubs(:command).with(:gemcmd).returns "/my/gem"
      provider.expects(:execute).with { |args| args[0] == "/my/gem" }.returns ""
      provider.install
    end

    it "should specify that the gem is being installed" do
      provider.expects(:execute).with { |args| args[1] == "install" }.returns ""
      provider.install
    end

    it "should specify that dependencies should be included" do
      provider.expects(:execute).with { |args| args[2] == "--include-dependencies" }.returns ""
      provider.install
    end

    it "should specify that documentation should not be included" do
      provider.expects(:execute).with { |args| args[3] == "--no-rdoc" }.returns ""
      provider.install
    end

    it "should specify that RI should not be included" do
      provider.expects(:execute).with { |args| args[4] == "--no-ri" }.returns ""
      provider.install
    end

    it "should specify the package name" do
      provider.expects(:execute).with { |args| args[5] == "myresource" }.returns ""
      provider.install
    end

    describe "when a source is specified" do
      describe "as a normal file" do
        it "should use the file name instead of the gem name" do
          resource[:source] = "/my/file"
          provider.expects(:execute).with { |args| args[3] == "/my/file" }.returns ""
          provider.install
        end
      end
      describe "as a file url" do
        it "should use the file name instead of the gem name" do
          resource[:source] = "file:///my/file"
          provider.expects(:execute).with { |args| args[3] == "/my/file" }.returns ""
          provider.install
        end
      end
      describe "as a puppet url" do
        it "should fail" do
          resource[:source] = "puppet://my/file"
          lambda { provider.install }.should raise_error(Puppet::Error)
        end
      end
      describe "as a non-file and non-puppet url" do
        it "should treat the source as a gem repository" do
          resource[:source] = "http://host/my/file"
          provider.expects(:execute).with { |args| args[3..5] == ["--source", "http://host/my/file", "myresource"] }.returns ""
          provider.install
        end
      end
      describe "with an invalid uri" do
        it "should fail" do
          URI.expects(:parse).raises(ArgumentError)
          resource[:source] = "http:::::uppet:/:/my/file"
          lambda { provider.install }.should raise_error(Puppet::Error)
        end
      end
    end
  end
end
