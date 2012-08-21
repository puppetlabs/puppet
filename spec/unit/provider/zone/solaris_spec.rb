#! /usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Type.type(:zone).provider(:solaris) do
  let(:resource) { Puppet::Type.type(:zone).new(:name => 'dummy', :path => '/', :provider => :solaris) }
  let(:provider) { resource.provider }

  context "#configure" do
    it "should add the create args to the create str" do
      resource.stubs(:properties).returns([])
      resource[:create_args] = "create_args"
      provider.expects(:setconfig).with("create -b create_args\nset zonepath=\/\ncommit\n")
      provider.configure
    end
  end

  context "#install" do
    context "clone" do
      it "should call zoneadm" do
        provider.expects(:zoneadm).with(:install)
        provider.install
      end

      it "with the resource's clone attribute" do
        resource[:clone] = :clone_argument
        provider.expects(:zoneadm).with(:clone, :clone_argument)
        provider.install
      end
    end

    context "not clone" do
      it "should just install if there are no install args" do
        # there is a nil check in type.rb:[]= so we cannot directly set nil.
        resource.stubs(:[]).with(:clone).returns(nil)
        resource.stubs(:[]).with(:install_args).returns(nil)
        provider.expects(:zoneadm).with(:install)
        provider.install
      end

      it "should add the install args to the command if they exist" do
        # there is a nil check in type.rb:[]= so we cannot directly set nil.
        resource.stubs(:[]).with(:clone).returns(nil)
        resource.stubs(:[]).with(:install_args).returns('install args')
        provider.expects(:zoneadm).with(:install, ["install", "args"])
        provider.install
      end
    end
  end
  context "#instances" do
    it "should list the instances correctly" do
      described_class.expects(:adm).with(:list, "-cp").returns("0:dummy:running:/::native:shared")
      instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      instances.size.should == 1
      instances[0].should == {
        :name=>"dummy",
        :ensure=>:running,
      }
    end
  end
  context "#setconfig" do
    it "should correctly set configuration" do
      # provider.expects(:cfg).with('-z', 'myzone')
      provider.expects(:cfg).with('-z', 'dummy', "create -b create_args\nset zonepath=\/\ncommit\n")
      provider.setconfig("create -b create_args\nset zonepath=\/\ncommit\n")
    end

    it "should correctly warn on 'not allowed'" do
      provider.expects(:cfg).with('-z', 'dummy', 'set zonepath=/').returns("Zone z2 already installed; set zonepath not allowed.\n")
      expect {
        provider.setconfig("set zonepath=\/")
      }.to raise_error(ArgumentError, /Failed to apply configuration/)

    end

  end
end
