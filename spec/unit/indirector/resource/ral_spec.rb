require 'spec_helper'
require 'puppet/indirector/resource/ral'

describe Puppet::Resource::Ral do
  let(:my_instance) { Puppet::Type.type(:user).new(:name => "root") }
  let(:wrong_instance) { Puppet::Type.type(:user).new(:name => "bob")}

  def stub_retrieve(*instances)
    instances.each do |i|
      allow(i).to receive(:retrieve).and_return(Puppet::Resource.new(i, nil))
    end
  end

  before do
    described_class.indirection.terminus_class = :ral

    # make sure we don't try to retrieve current state
    allow_any_instance_of(Puppet::Type.type(:user)).to receive(:retrieve).never
    stub_retrieve(my_instance, wrong_instance)
  end

  it "disallows remote requests" do
    expect(Puppet::Resource::Ral.new.allow_remote_requests?).to eq(false)
  end

  describe "find" do
    it "should find an existing instance" do
      allow(Puppet::Type.type(:user)).to receive(:instances).and_return([ wrong_instance, my_instance, wrong_instance ])

      actual_resource = described_class.indirection.find('user/root')
      expect(actual_resource.name).to eq('User/root')
    end

    it "should produce Puppet::Error instead of ArgumentError" do
      expect{described_class.indirection.find('thiswill/causeanerror')}.to raise_error(Puppet::Error)
    end

    it "if there is no instance, it should create one" do
      allow(Puppet::Type.type(:user)).to receive(:instances).and_return([wrong_instance])

      expect(Puppet::Type.type(:user)).to receive(:new).with(hash_including(name: "root")).and_return(my_instance)
      expect(described_class.indirection.find('user/root')).to be
    end
  end

  describe "search" do
    it "should convert ral resources into regular resources" do
      allow(Puppet::Type.type(:user)).to receive(:instances).and_return([ my_instance ])

      actual = described_class.indirection.search('user')
      expect(actual).to contain_exactly(an_instance_of(Puppet::Resource))
    end

    it "should filter results by name if there's a name in the key" do
      pending('to_resource')
      allow(Puppet::Type.type(:user)).to receive(:instances).and_return([ my_instance, wrong_instance ])

      actual = described_class.indirection.search('user/root')
      expect(actual).to contain_exactly(an_object_having_attributes(name: 'User/root'))
    end

    it "should filter results by query parameters" do
      pending('to_resource')
      allow(Puppet::Type.type(:user)).to receive(:instances).and_return([ my_instance, wrong_instance ])

      actual = described_class.indirection.search('user', name: 'bob')
      expect(actual).to contain_exactly(an_object_having_attributes(name: 'User/bob'))
    end

    it "should return sorted results" do
      a_instance = Puppet::Type.type(:user).new(:name => "alice")
      b_instance = Puppet::Type.type(:user).new(:name => "bob")
      stub_retrieve(a_instance, b_instance)
      allow(Puppet::Type.type(:user)).to receive(:instances).and_return([ b_instance, a_instance ])

      expect(described_class.indirection.search('user').map(&:title)).to eq(['alice', 'bob'])
    end
  end

  describe "save" do
    it "returns a report covering the application of the given resource to the system" do
      resource = Puppet::Resource.new(:notify, "the title")

      applied_resource, report = described_class.indirection.save(resource, nil, environment: Puppet::Node::Environment.remote(:testing))

      expect(applied_resource.title).to eq("the title")
      expect(report.environment).to eq("testing")
      expect(report.resource_statuses["Notify[the title]"].changed).to eq(true)
    end
  end
end
