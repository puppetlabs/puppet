#! /usr/bin/env ruby
require 'spec_helper'

augeas = Puppet::Type.type(:augeas)

describe augeas do
  describe "when augeas is present", :if => Puppet.features.augeas? do
    it "should have a default provider inheriting from Puppet::Provider" do
      expect(augeas.defaultprovider.ancestors).to be_include(Puppet::Provider)
    end

    it "should have a valid provider" do
      expect(augeas.new(:name => "foo").provider.class.ancestors).to be_include(Puppet::Provider)
    end
  end

  describe "basic structure" do
    it "should be able to create an instance" do
      provider_class = Puppet::Type::Augeas.provider(Puppet::Type::Augeas.providers[0])
      Puppet::Type::Augeas.expects(:defaultprovider).returns provider_class
      expect(augeas.new(:name => "bar")).not_to be_nil
    end

    it "should have a parse_commands feature" do
      expect(augeas.provider_feature(:parse_commands)).not_to be_nil
    end

    it "should have a need_to_run? feature" do
      expect(augeas.provider_feature(:need_to_run?)).not_to be_nil
    end

    it "should have an execute_changes feature" do
      expect(augeas.provider_feature(:execute_changes)).not_to be_nil
    end

    properties = [:returns]
    params = [:name, :context, :onlyif, :changes, :root, :load_path, :type_check, :show_diff]

    properties.each do |property|
      it "should have a #{property} property" do
        expect(augeas.attrclass(property).ancestors).to be_include(Puppet::Property)
      end

      it "should have documentation for its #{property} property" do
        expect(augeas.attrclass(property).doc).to be_instance_of(String)
      end
    end

    params.each do |param|
      it "should have a #{param} parameter" do
        expect(augeas.attrclass(param).ancestors).to be_include(Puppet::Parameter)
      end

      it "should have documentation for its #{param} parameter" do
        expect(augeas.attrclass(param).doc).to be_instance_of(String)
      end
    end
  end

  describe "default values" do
    before do
      provider_class = augeas.provider(augeas.providers[0])
      augeas.expects(:defaultprovider).returns provider_class
    end

    it "should be blank for context" do
      expect(augeas.new(:name => :context)[:context]).to eq("")
    end

    it "should be blank for onlyif" do
      expect(augeas.new(:name => :onlyif)[:onlyif]).to eq("")
    end

    it "should be blank for load_path" do
      expect(augeas.new(:name => :load_path)[:load_path]).to eq("")
    end

    it "should be / for root" do
      expect(augeas.new(:name => :root)[:root]).to eq("/")
    end

    it "should be false for type_check" do
      expect(augeas.new(:name => :type_check)[:type_check]).to eq(:false)
    end
  end

  describe "provider interaction" do

    it "should return 0 if it does not need to run" do
      provider = stub("provider", :need_to_run? => false)
      resource = stub('resource', :resource => nil, :provider => provider, :line => nil, :file => nil)
      changes = augeas.attrclass(:returns).new(:resource => resource)
      expect(changes.retrieve).to eq(0)
    end

    it "should return :need_to_run if it needs to run" do
      provider = stub("provider", :need_to_run? => true)
      resource = stub('resource', :resource => nil, :provider => provider, :line => nil, :file => nil)
      changes = augeas.attrclass(:returns).new(:resource => resource)
      expect(changes.retrieve).to eq(:need_to_run)
    end
  end

  describe "loading specific files" do
    it "should require lens when incl is used" do
      expect { augeas.new(:name => :no_lens, :incl => "/etc/hosts")}.to raise_error(Puppet::Error)
    end

    it "should require incl when lens is used" do
      expect { augeas.new(:name => :no_incl, :lens => "Hosts.lns") }.to raise_error(Puppet::Error)
    end

    it "should set the context when a specific file is used" do
      fake_provider = stub_everything "fake_provider"
      augeas.stubs(:defaultprovider).returns fake_provider
      expect(augeas.new(:name => :no_incl, :lens => "Hosts.lns", :incl => "/etc/hosts")[:context]).to eq("/files/etc/hosts")
    end
  end
end
