#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:group) do
  let(:mock_group_provider) do
    described_class.provide(:mock_group_provider) do
      has_features :manages_members
      mk_resource_methods
      def create; end
      def delete; end
      def exists?; get(:ensure) != :absent; end
      def flush; end
      def self.instances; []; end
    end
  end

  before(:each) do
    @class = Puppet::Type.type(:group)
    described_class.stubs(:defaultprovider).returns mock_group_provider
  end

  it "should have a system_groups feature" do
    expect(@class.provider_feature(:system_groups)).not_to be_nil
  end

  it 'should default to `present`' do
    expect(@class.new(:name => "foo")[:ensure]).to eq(:present)
  end

  it 'should set ensure to whatever is passed in' do
    expect(@class.new(:name => "foo", :ensure => 'absent')[:ensure]).to eq(:absent)
  end

  describe "when validating attributes" do
    [:name, :allowdupe].each do |param|
      it "should have a #{param} parameter" do
        expect(@class.attrtype(param)).to eq(:param)
      end
    end

    [:ensure, :gid].each do |param|
      it "should have a #{param} property" do
        expect(@class.attrtype(param)).to eq(:property)
      end
    end

    it "should convert gids provided as strings into integers" do
      expect(@class.new(:name => "foo", :gid => "15")[:gid]).to eq(15)
    end

    it "should accepts gids provided as integers" do
      expect(@class.new(:name => "foo", :gid => 15)[:gid]).to eq(15)
    end
  end

  it "should have a boolean method for determining if duplicates are allowed" do
    expect(@class.new(:name => "foo")).to respond_to "allowdupe?"
  end

  it "should have a boolean method for determining if system groups are allowed" do
    expect(@class.new(:name => "foo")).to respond_to "system?"
  end

  it "should call 'create' to create the group" do
    group = @class.new(:name => "foo", :ensure => :present)
    group.provider.expects(:create)
    group.parameter(:ensure).sync
  end

  it "should call 'delete' to remove the group" do
    group = @class.new(:name => "foo", :ensure => :absent)
    group.provider.expects(:delete)
    group.parameter(:ensure).sync
  end

  it "delegates the existence check to its provider" do
    provider = @class.provide(:testing) {}
    provider_instance = provider.new
    provider_instance.expects(:exists?).returns true

    type = @class.new(:name => "group", :provider => provider_instance)

    expect(type.exists?).to eq(true)
  end

  describe "when managing members" do
    def stub_property(resource_hash)
      described_class.new(resource_hash).property(:members)
    end

    describe "validation" do
      it "raises an error for a non-String value" do
        expect {
          described_class.new(:name => 'foo', :members => true)
        }.to raise_error(Puppet::Error)
      end

      it "raises an error for an array value containing a non-String element" do
        expect {
          described_class.new(:name => 'foo', :members => [ true, 'foo' ])
        }.to raise_error(Puppet::Error)
      end

      it "raises an error when the members are specified as UIDs instead of usernames" do
        expect {
          described_class.new(:name => 'foo', :members => [ '123', '456' ])
        }.to raise_error(Puppet::Error)
      end

      it "raises an error when an empty string is passed for a member's username" do
        expect {
          described_class.new(:name => 'foo', :members => [ 'foo', '' ])
        }.to raise_error(Puppet::Error)
      end

      it "passes for a single member" do
        expect {
          described_class.new(:name => 'foo', :members => 'foo')
        }.to_not raise_error
      end

      it "passes for a member whose username has a number" do
        expect {
          described_class.new(:name => 'foo', :members => 'foo123')
        }.to_not raise_error
      end

      it "passes for an array of members" do
        expect {
          described_class.new(:name => 'foo', :members => [ 'foo', 'bar' ])
        }.to_not raise_error
      end

      it "passes for a comma-separated list of members" do
        expect {
          described_class.new(:name => 'foo', :members => 'foo,bar')
        }.to_not raise_error
      end
    end

    describe "#inclusive?" do
      it "returns false when auth_membership == false" do
        members_property = stub_property(
          :name => 'foo',
          :auth_membership => false,
          :members => []
        )

        expect(members_property.inclusive?).to be false
      end

      it "returns true when auth_membership == true" do
        members_property = stub_property(
          :name => 'foo',
          :auth_membership => true,
          :members => []
        )

        expect(members_property.inclusive?).to be true
      end
    end

    describe "#should= munging the @should instance variable" do
      def should_var_of(property)
        property.instance_variable_get(:@should)
      end

      it "leaves a single member as-is" do
        members_property = stub_property(:name => 'foo', :members => [])
        members_property.should = 'foo'

        expect(should_var_of(members_property)).to eql([ 'foo' ])
      end

      it "leaves an array of members as-is" do
        members_property = stub_property(:name => 'foo', :members => [])
        members_property.should = [ 'foo', 'bar' ]

        expect(should_var_of(members_property)).to eql(['foo', 'bar'])
      end

      it "munges a comma-separated list of members into an array" do
        members_property = stub_property(:name => 'foo', :members => [])
        members_property.should = 'foo,bar' 

        expect(should_var_of(members_property)).to eql(['foo', 'bar'])
      end
    end
  end
end
