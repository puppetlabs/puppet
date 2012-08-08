#! /usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Type.type(:zone) do
  let(:zone)     { described_class.new(:name => 'dummy', :path => '/dummy', :provider => :solaris) }
  let(:provider) { zone.provider }

  parameters = [:create_args, :install_args, :sysidcfg, :path, :realhostname]

  parameters.each do |parameter|
    it "should have a #{parameter} parameter" do
      described_class.attrclass(parameter).ancestors.should be_include(Puppet::Parameter)
    end
  end

  properties = [:ip, :iptype, :autoboot, :pool, :shares, :inherit]

  properties.each do |property|
    it "should have a #{property} property" do
      described_class.attrclass(property).ancestors.should be_include(Puppet::Property)
    end
  end

  it "should be invalid when :path is missing" do
    expect {
      described_class.new(:name => "dummy", :provider => :solaris)
    }.to raise_error(Puppet::Error, /zone path is required/)
  end

  it "should be valid when only :path is given" do
    described_class.new(:name => "dummy", :path => '/dummy', :provider => :solaris)
  end

  it "should be invalid when :ip is missing a \":\" and iptype is :shared" do
    expect {
      described_class.new(:name => "dummy", :ip => "if", :path => "/dummy", :provider => :solaris)
    }.to raise_error(Puppet::Error, /ip must contain interface name and ip address separated by a ":"/)
  end

  it "should be invalid when :ip has a \":\" and iptype is :exclusive" do
    expect {
      described_class.new(:name => "dummy", :ip => "if:1.2.3.4", :iptype => :exclusive, :provider => :solaris)
    }.to raise_error(Puppet::Error, /zone path is required/)
  end

  it "should be invalid when :ip has two \":\" and iptype is :exclusive" do
    expect {
      described_class.new(:name => "dummy", :ip => "if:1.2.3.4:2.3.4.5", :iptype => :exclusive, :provider => :solaris)
    }.to raise_error(Puppet::Error, /zone path is required/)
  end

  it "should be valid when :iptype is :shared and using interface and ip" do
    described_class.new(:name => "dummy", :path => "/dummy", :ip => "if:1.2.3.4", :provider => :solaris)
  end

  it "should be valid when :iptype is :shared and using interface, ip and default route" do
    described_class.new(:name => "dummy", :path => "/dummy", :ip => "if:1.2.3.4:2.3.4.5", :provider => :solaris)
  end

  it "should be valid when :iptype is :exclusive and using interface" do
    described_class.new(:name => "dummy", :path => "/dummy", :ip => "if", :iptype => :exclusive, :provider => :solaris)
  end

  it "should be valid when ensure is :absent" do
    described_class.new(:name => "dummy", :ensure => :absent, :provider => :solaris)
  end

  context "state_name" do
    it "should correctly fetch alias from state_aliases when available" do
      zone.parameter(:ensure).class.state_name('incomplete').should == :installed
    end

    it "should correctly use symbol when alias is unavailable" do
      zone.parameter(:ensure).class.state_name('noalias').should == :noalias
    end
  end

  it "should auto-require :dataset entries" do
    fs = 'random-pool/some-zfs'

    catalog = Puppet::Resource::Catalog.new
    zfs = Puppet::Type.type(:zfs).new(:name => fs)
    catalog.add_resource zfs

    zone = described_class.new(:name    => "dummy",
                               :path    => "/foo",
                               :ip      => 'en1:1.0.0.0',
                               :dataset => fs,
                               :provider => :solaris)
    catalog.add_resource zone

    catalog.relationship_graph.dependencies(zone).should == [zfs]
  end
end
