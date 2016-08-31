#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:project) do
  before do

    @provider_class = described_class.provide(:fake) { mk_resource_methods }
    @provider_class.stubs(:suitable).returns true

    described_class.stubs(:defaultprovider).returns @provider_class

#    @provider = @provider_class.new
#    @resource = stub 'resource', :resource => nil, :provider => @provider
#
#    @class.stubs(:defaultprovider).returns @provider_class
#    @class.any_instance.stubs(:provider).returns @provider
#
#    @catalog = Puppet::Resource::Catalog.new
  end


  it "should have :name be its keyattribute" do
    described_class.key_attributes.should == [:name]
  end

  describe "when validating attributes" do

    [:name, :user_membership, :group_membership, :attribute_membership, :provider].each do |param|
      it "should have a #{param} parameter" do
        described_class.attrtype(param).should == :param
      end
    end

    [:ensure, :users, :groups, :comment, :attributes, :projid].each do |property|
      it "should have #{property} property" do
        described_class.attrtype(property).should == :property
      end
    end

  end

  describe "when validating values" do

    describe "for ensure" do

      it "should support present" do
        proc { described_class.new(:name => "whev", :ensure => :present) }.should_not raise_error
      end

      it "should support absent" do
        proc { described_class.new(:name => "whev", :ensure => :absent) }.should_not raise_error
      end

      it "should support not support other values" do
        proc { described_class.new(:name => "whev", :ensure => :foo) }.should raise_error(Puppet::Error, /Invalid value/)
      end

    end

    [:user_membership, :group_membership, :attribute_membership].each do |param|

      describe "for #{param}" do

        it "should support minimum" do
          proc { described_class.new(:name => "whev", param => :minimum) }.should_not raise_error
        end

        it "should support inclusive" do
          proc { described_class.new(:name => "whev", param => :inclusive) }.should_not raise_error
        end

        it "should use minimum as the defaultvalue" do
          described_class.new(:name => 'testproj')[param].should == :minimum
        end

        it "should not support other values" do
          proc { described_class.new(:name => "whev", param => :minimal) }.should raise_error(Puppet::Error, /Invalid value/)
        end

      end

    end

    describe "for name" do

      it "should support alphabetic names" do
        proc { described_class.new(:name => "proj") }.should_not raise_error
        proc { described_class.new(:name => "pOjEcT") }.should_not raise_error
      end

      it "should support alphanumeric names" do
        proc { described_class.new(:name => "proj123") }.should_not raise_error
      end

      it "should support underlines, dots, and hyphens" do
        proc { described_class.new(:name => "my_fancy_project") }.should_not raise_error
        proc { described_class.new(:name => "my_fancy_project") }.should_not raise_error
        proc { described_class.new(:name => "root.project") }.should_not raise_error
        proc { described_class.new(:name => "Aa09_-as.a") }.should_not raise_error
      end

      it "should not support invalid project names" do
        proc { described_class.new(:name => ":test") }.should raise_error(Puppet::Error, /is an invalid project name/)
        proc { described_class.new(:name => "test:") }.should raise_error(Puppet::Error, /is an invalid project name/)
        proc { described_class.new(:name => "te:st:") }.should raise_error(Puppet::Error, /is an invalid project name/)
        proc { described_class.new(:name => "te§st") }.should raise_error(Puppet::Error, /is an invalid project name/)
      end

    end

    describe "for projid" do

      it "should support valid numbers" do
        proc { described_class.new(:name => "proj", :projid => '0') }.should_not raise_error
        proc { described_class.new(:name => "proj", :projid => '1') }.should_not raise_error
        proc { described_class.new(:name => "proj", :projid => '2147483647') }.should_not raise_error
      end

      it "should not support an id that is not numeric" do
        proc { described_class.new(:name => "proj", :projid => "500a") }.should raise_error(Puppet::Error, /projid has to be numeric/)
        proc { described_class.new(:name => "proj", :projid => "a500") }.should raise_error(Puppet::Error, /projid has to be numeric/)
        proc { described_class.new(:name => "proj", :projid => "5a00") }.should raise_error(Puppet::Error, /projid has to be numeric/)
      end

      it "should not support an id that is out of range" do
        proc { described_class.new(:name => "proj", :projid => "-1") }.should raise_error(Puppet::Error, /(projid has to be numeric)|(projid.*out of range)/)
        proc { described_class.new(:name => "proj", :projid => "2147483648") }.should raise_error(Puppet::Error, /projid.*out of range/)
      end

    end

    describe "for user" do

      it "should support a single user" do
        proc { described_class.new(:name => "proj", :users => 'user1') }.should_not raise_error
      end

      it "should support multiple users" do
        proc { described_class.new(:name => "proj", :users => ['user1','user2']) }.should_not raise_error
      end

      it "should not support a comma separated list" do
        proc { described_class.new(:name => "proj", :users => 'user1,user2') }.should raise_error(Puppet::Error, /multiple users.*array/)
      end

    end

    describe "for group" do

      it "should support a single group" do
        proc { described_class.new(:name => "proj", :groups => 'user1') }.should_not raise_error
      end

      it "should support multiple groups" do
        proc { described_class.new(:name => "proj", :groups => ['group1','group2']) }.should_not raise_error
      end

      it "should not support a comma separated list" do
        proc { described_class.new(:name => "proj", :groups => 'group1,group2') }.should raise_error(Puppet::Error, /multiple groups.*array/)
      end

    end

    describe "for attributes" do

      it "should support a single attribute" do
        proc { described_class.new(:name => "proj", :attributes => 'task.max-lwps=(priv,1000,deny)') }.should_not raise_error
      end

      it "should support multiple attributes" do
        proc { described_class.new(:name => "proj", :attributes => ['key1=value1','key2=value2']) }.should_not raise_error
      end

      it "should support attributes without values" do
        proc { described_class.new(:name => "proj", :attributes => ['key1=value1','key2']) }.should_not raise_error
      end

      it "should support values with equal signes" do
        proc { described_class.new(:name => "proj", :attributes => ['key1=value1','task.max-lwps=(privileged,10,deny),(priv,1000,signal=KILL)']) }.should_not raise_error
      end

      it "should not support a comma separated list" do
        proc { described_class.new(:name => "proj", :attributes => 'key1=value1;key2=value2') }.should raise_error(Puppet::Error, /multiple attributes.*array/)
      end

    end

  end

  describe "when syncing" do

    before :each do
      # is
      @provider = @provider_class.new(
        :name       => 'foo',
        :users      => 'user2,user1',
        :groups     => 'group1,group2',
        :attributes => {
          :attribute1 => 'val1',
          :attribute2 => 'val2',
          :attribute3 => 'val3',
        }
      )
      # should
      @resource = described_class.new(
        :name       => 'foo',
        :users      => ['user3','user2'],
        :groups     => ['group3','group2'],
        :attributes => ['attribute2=val2','attribute4=val4','attribute3=newval']
      )
      @resource.provider = @provider
    end

    describe "users" do

      it "should merge the is-value when membership is set to minimum" do
        @resource[:user_membership] = :minimum
        @resource.should(:users).should == 'user1,user2,user3'
      end


      it "should not merge the is-value when membership is set to inclusive" do
        @resource[:user_membership] = :inclusive
        @resource.should(:users).should == 'user2,user3'
      end

      it "should send the sorted and joined array to the provider" do
        @resource[:user_membership] = :inclusive
        @provider.expects(:'users=').with('user2,user3')
        @resource.parameter(:users).sync
      end

      it "should send the merged and joined array to the provider when membership is set to minimum" do
        @resource[:user_membership] = :minimum
        @provider.expects(:'users=').with('user1,user2,user3')
        @resource.parameter(:users).sync
      end

      it "should not care about the order when checking insync" do
        @resource[:user_membership] = :inclusive
        @resource.parameter(:users).insync?(%w{user2 user3}).should == true
        @resource.parameter(:users).insync?(%w{user3 user2}).should == true
      end

    end

    describe "groups" do

      it "should merge the is-value when membership is set to minimum" do
        @resource[:group_membership] = :minimum
        @resource.should(:groups).should == 'group1,group2,group3'
      end


      it "should not merge the is-value when membership is set to inclusive" do
        @resource[:group_membership] = :inclusive
        @resource.should(:groups).should == 'group2,group3'
      end

      it "should send the sorted and joined array to the provider" do
        @resource[:group_membership] = :inclusive
        @provider.expects(:'groups=').with('group2,group3')
        @resource.parameter(:groups).sync
      end

      it "should send the merged and joined array to the provider when membership is set to minimum" do
        @resource[:user_membership] = :minimum
        @provider.expects(:'groups=').with('group1,group2,group3')
        @resource.parameter(:groups).sync
      end

      it "should not care about the order when checking insync" do
        @resource[:group_membership] = :inclusive
        @resource.parameter(:groups).insync?(%w{group2 group3}).should == true
        @resource.parameter(:groups).insync?(%w{group3 group2}).should == true
      end

    end

    describe "attributes" do

      it "should send the should value as a hash to the provider" do
        @resource[:attribute_membership] = :inclusive
        @provider.expects(:'attributes=').with(
          :attribute2 => 'val2',
          :attribute3 => 'newval',
          :attribute4 => 'val4'
        )
        @resource.parameter(:attributes).sync
      end

      it "should merge is-values when membership is set to minimum" do
        @resource[:attribute_membership] = :minimum
        @provider.expects(:'attributes=').with(
          :attribute1 => 'val1',
          :attribute2 => 'val2',
          :attribute3 => 'newval',
          :attribute4 => 'val4'
        )
        @resource.parameter(:attributes).sync
      end

      it "should use nil as value when the key does not have a value" do
        described_class.new(
          :name                 => 'foo',
          :attributes           => ['foo=v1','bar','baz=dummy'],
          :attribute_membership => :inclusive
        ).should(:attributes).should == {
          :foo => 'v1',
          :baz => 'dummy',
          :bar => nil
        }
      end


    end

  end

  describe "when autorequireing resources" do

    before :each do
      @resource = described_class.new(
        :name             => 'proj',
        :users            => [ 'user1', 'user2','user3'],
        :groups           => [ 'group1', 'group2','group3' ],
        :user_membership  => :inclusive,
        :group_membership => :inclusive
      )
      @resource_plain = described_class.new(
        :name => 'proj2'
      )
      @catalog = Puppet::Resource::Catalog.new

      @user2 = Puppet::Type.type(:user).new(:name => 'user2')
      @user3 = Puppet::Type.type(:user).new(:name => 'user3')
      @user4 = Puppet::Type.type(:user).new(:name => 'user4')

      @group2 = Puppet::Type.type(:group).new(:name => 'group2')
      @group3 = Puppet::Type.type(:group).new(:name => 'group3')
      @group4 = Puppet::Type.type(:group).new(:name => 'group4')

    end

    it "should not autorequire anything if users and groups are empty" do
      @catalog.add_resource(@user2,@user3,@user4,@group2,@group3,@group4,@resource_plain)
      @resource_plain.autorequire.size.should == 0
    end

    it "should autorequire users" do
      @catalog.add_resource(@user2,@user3,@user4,@resource)

      reqs = @resource.autorequire

      reqs.size.should == 2
      reqs[0].target.must == @resource
      reqs[0].source.must == @user2
      reqs[1].target.must == @resource
      reqs[1].source.must == @user3
    end

    it "should autorequire groups" do
      @catalog.add_resource(@group2,@group3,@group4,@resource)

      reqs = @resource.autorequire

      reqs.size.should == 2
      reqs[0].target.must == @resource
      reqs[0].source.must == @group2
      reqs[1].target.must == @resource
      reqs[1].source.must == @group3
    end

  end

end
