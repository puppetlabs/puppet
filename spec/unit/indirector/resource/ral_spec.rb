require 'spec_helper'
require 'puppet/indirector/resource/ral'

describe "Puppet::Resource::Ral" do
  it "disallows remote requests" do
    expect(Puppet::Resource::Ral.new.allow_remote_requests?).to eq(false)
  end

  describe "find" do
    before do
      @request = double('request', :key => "user/root")
    end

    it "should find an existing instance" do
      my_resource    = double("my user resource")

      wrong_instance = double("wrong user", :name => "bob")
      my_instance    = double("my user",    :name => "root", :to_resource => my_resource)

      expect(Puppet::Type.type(:user)).to receive(:instances).and_return([ wrong_instance, my_instance, wrong_instance ])
      expect(Puppet::Resource::Ral.new.find(@request)).to eq(my_resource)
    end

    it "should produce Puppet::Error instead of ArgumentError" do
      @bad_request = double('thiswillcauseanerror', :key => "thiswill/causeanerror")
      expect{Puppet::Resource::Ral.new.find(@bad_request)}.to raise_error(Puppet::Error)
    end

    it "if there is no instance, it should create one" do
      wrong_instance = double("wrong user", :name => "bob")
      root = double("Root User")
      root_resource = double("Root Resource")

      expect(Puppet::Type.type(:user)).to receive(:instances).and_return([ wrong_instance, wrong_instance ])
      expect(Puppet::Type.type(:user)).to receive(:new).with(hash_including(name: "root")).and_return(root)
      expect(root).to receive(:to_resource).and_return(root_resource)

      result = Puppet::Resource::Ral.new.find(@request)

      expect(result).to eq(root_resource)
    end
  end

  describe "search" do
    before do
      @request = double('request', :key => "user/", :options => {})
    end

    it "should convert ral resources into regular resources" do
      my_resource = double("my user resource", :title => "my user resource")
      my_instance = double("my user", :name => "root", :to_resource => my_resource)

      expect(Puppet::Type.type(:user)).to receive(:instances).and_return([ my_instance ])
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([my_resource])
    end

    it "should filter results by name if there's a name in the key" do
      my_resource = double("my user resource", title: "my user resource")
      allow(my_resource).to receive(:to_resource).and_return(my_resource)
      allow(my_resource).to receive(:[]).with(:name).and_return("root")

      wrong_resource = double("wrong resource")
      allow(wrong_resource).to receive(:to_resource).and_return(wrong_resource)
      allow(wrong_resource).to receive(:[]).with(:name).and_return("bad")

      my_instance    = double("my user",    :to_resource => my_resource)
      wrong_instance = double("wrong user", :to_resource => wrong_resource)

      @request = double('request', :key => "user/root", :options => {})

      expect(Puppet::Type.type(:user)).to receive(:instances).and_return([ my_instance, wrong_instance ])
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([my_resource])
    end

    it "should filter results by query parameters" do
      wrong_resource = double("my user resource", title: "my user resource")
      allow(wrong_resource).to receive(:to_resource).and_return(wrong_resource)
      allow(wrong_resource).to receive(:[]).with(:name).and_return("root")

      my_resource = double("wrong resource", title: "wrong resource")
      allow(my_resource).to receive(:to_resource).and_return(my_resource)
      allow(my_resource).to receive(:[]).with(:name).and_return("bob")

      my_instance    = double("my user",    :to_resource => my_resource)
      wrong_instance = double("wrong user", :to_resource => wrong_resource)

      @request = double('request', :key => "user/", :options => {:name => "bob"})

      expect(Puppet::Type.type(:user)).to receive(:instances).and_return([ my_instance, wrong_instance ])
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([my_resource])
    end

    it "should return sorted results" do
      a_resource = double("alice resource")
      allow(a_resource).to receive(:to_resource).and_return(a_resource)
      allow(a_resource).to receive(:title).and_return("alice")

      b_resource = double("bob resource")
      allow(b_resource).to receive(:to_resource).and_return(b_resource)
      allow(b_resource).to receive(:title).and_return("bob")

      a_instance = double("alice user", :to_resource => a_resource)
      b_instance = double("bob user",   :to_resource => b_resource)

      @request = double('request', :key => "user/", :options => {})

      expect(Puppet::Type.type(:user)).to receive(:instances).and_return([ b_instance, a_instance ])
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([a_resource, b_resource])
    end
  end

  describe "save" do
    it "returns a report covering the application of the given resource to the system" do
      resource = Puppet::Resource.new(:notify, "the title")
      ral = Puppet::Resource::Ral.new

      applied_resource, report = ral.save(Puppet::Indirector::Request.new(:ral, :save, 'testing', resource, :environment => Puppet::Node::Environment.remote(:testing)))

      expect(applied_resource.title).to eq("the title")
      expect(report.environment).to eq("testing")
      expect(report.resource_statuses["Notify[the title]"].changed).to eq(true)
    end
  end
end
