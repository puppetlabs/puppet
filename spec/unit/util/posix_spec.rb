#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/posix'

class PosixTest
  include Puppet::Util::POSIX
end

describe Puppet::Util::POSIX do
  before do
    @posix = PosixTest.new
  end

  [:group, :gr].each do |name|
    it "should return :gid as the field for #{name}" do
      @posix.idfield(name).should == :gid
    end

    it "should return :getgrgid as the id method for #{name}" do
      @posix.methodbyid(name).should == :getgrgid
    end

    it "should return :getgrnam as the name method for #{name}" do
      @posix.methodbyname(name).should == :getgrnam
    end
  end

  [:user, :pw, :passwd].each do |name|
    it "should return :uid as the field for #{name}" do
      @posix.idfield(name).should == :uid
    end

    it "should return :getpwuid as the id method for #{name}" do
      @posix.methodbyid(name).should == :getpwuid
    end

    it "should return :getpwnam as the name method for #{name}" do
      @posix.methodbyname(name).should == :getpwnam
    end
  end

  describe "when retrieving a posix field" do
    before do
      @thing = stub 'thing', :field => "asdf"
    end

    it "should fail if no id was passed" do
      lambda { @posix.get_posix_field("asdf", "bar", nil) }.should raise_error(Puppet::DevError)
    end

    describe "and the id is an integer" do
      it "should log an error and return nil if the specified id is greater than the maximum allowed ID" do
        Puppet.settings.expects(:value).with(:maximum_uid).returns 100
        Puppet.expects(:err)

        @posix.get_posix_field("asdf", "bar", 200).should be_nil
      end

      it "should use the method return by :methodbyid and return the specified field" do
        Etc.expects(:getgrgid).returns @thing

        @thing.expects(:field).returns "myval"

        @posix.get_posix_field(:gr, :field, 200).should == "myval"
      end

      it "should return nil if the method throws an exception" do
        Etc.expects(:getgrgid).raises ArgumentError

        @thing.expects(:field).never

        @posix.get_posix_field(:gr, :field, 200).should be_nil
      end
    end

    describe "and the id is not an integer" do
      it "should use the method return by :methodbyid and return the specified field" do
        Etc.expects(:getgrnam).returns @thing

        @thing.expects(:field).returns "myval"

        @posix.get_posix_field(:gr, :field, "asdf").should == "myval"
      end

      it "should return nil if the method throws an exception" do
        Etc.expects(:getgrnam).raises ArgumentError

        @thing.expects(:field).never

        @posix.get_posix_field(:gr, :field, "asdf").should be_nil
      end
    end
  end

  describe "when returning the gid" do
    before do
      @posix.stubs(:get_posix_field)
    end

    describe "and the group is an integer" do
      it "should convert integers specified as a string into an integer" do
        @posix.expects(:get_posix_field).with(:group, :name, 100)

        @posix.gid("100")
      end

      it "should look up the name for the group" do
        @posix.expects(:get_posix_field).with(:group, :name, 100)

        @posix.gid(100)
      end

      it "should return nil if the group cannot be found" do
        @posix.expects(:get_posix_field).once.returns nil
        @posix.expects(:search_posix_field).never

        @posix.gid(100).should be_nil
      end

      it "should use the found name to look up the id" do
        @posix.expects(:get_posix_field).with(:group, :name, 100).returns "asdf"
        @posix.expects(:get_posix_field).with(:group, :gid, "asdf").returns 100

        @posix.gid(100).should == 100
      end

      # LAK: This is because some platforms have a broken Etc module that always return
      # the same group.
      it "should use :search_posix_field if the discovered id does not match the passed-in id" do
        @posix.expects(:get_posix_field).with(:group, :name, 100).returns "asdf"
        @posix.expects(:get_posix_field).with(:group, :gid, "asdf").returns 50

        @posix.expects(:search_posix_field).with(:group, :gid, 100).returns "asdf"

        @posix.gid(100).should == "asdf"
      end
    end

    describe "and the group is a string" do
      it "should look up the gid for the group" do
        @posix.expects(:get_posix_field).with(:group, :gid, "asdf")

        @posix.gid("asdf")
      end

      it "should return nil if the group cannot be found" do
        @posix.expects(:get_posix_field).once.returns nil
        @posix.expects(:search_posix_field).never

        @posix.gid("asdf").should be_nil
      end

      it "should use the found gid to look up the nam" do
        @posix.expects(:get_posix_field).with(:group, :gid, "asdf").returns 100
        @posix.expects(:get_posix_field).with(:group, :name, 100).returns "asdf"

        @posix.gid("asdf").should == 100
      end

      it "should use :search_posix_field if the discovered name does not match the passed-in name" do
        @posix.expects(:get_posix_field).with(:group, :gid, "asdf").returns 100
        @posix.expects(:get_posix_field).with(:group, :name, 100).returns "boo"

        @posix.expects(:search_posix_field).with(:group, :gid, "asdf").returns "asdf"

        @posix.gid("asdf").should == "asdf"
      end
    end
  end

  describe "when returning the uid" do
    before do
      @posix.stubs(:get_posix_field)
    end

    describe "and the group is an integer" do
      it "should convert integers specified as a string into an integer" do
        @posix.expects(:get_posix_field).with(:passwd, :name, 100)

        @posix.uid("100")
      end

      it "should look up the name for the group" do
        @posix.expects(:get_posix_field).with(:passwd, :name, 100)

        @posix.uid(100)
      end

      it "should return nil if the group cannot be found" do
        @posix.expects(:get_posix_field).once.returns nil
        @posix.expects(:search_posix_field).never

        @posix.uid(100).should be_nil
      end

      it "should use the found name to look up the id" do
        @posix.expects(:get_posix_field).with(:passwd, :name, 100).returns "asdf"
        @posix.expects(:get_posix_field).with(:passwd, :uid, "asdf").returns 100

        @posix.uid(100).should == 100
      end

      # LAK: This is because some platforms have a broken Etc module that always return
      # the same group.
      it "should use :search_posix_field if the discovered id does not match the passed-in id" do
        @posix.expects(:get_posix_field).with(:passwd, :name, 100).returns "asdf"
        @posix.expects(:get_posix_field).with(:passwd, :uid, "asdf").returns 50

        @posix.expects(:search_posix_field).with(:passwd, :uid, 100).returns "asdf"

        @posix.uid(100).should == "asdf"
      end
    end

    describe "and the group is a string" do
      it "should look up the uid for the group" do
        @posix.expects(:get_posix_field).with(:passwd, :uid, "asdf")

        @posix.uid("asdf")
      end

      it "should return nil if the group cannot be found" do
        @posix.expects(:get_posix_field).once.returns nil
        @posix.expects(:search_posix_field).never

        @posix.uid("asdf").should be_nil
      end

      it "should use the found uid to look up the nam" do
        @posix.expects(:get_posix_field).with(:passwd, :uid, "asdf").returns 100
        @posix.expects(:get_posix_field).with(:passwd, :name, 100).returns "asdf"

        @posix.uid("asdf").should == 100
      end

      it "should use :search_posix_field if the discovered name does not match the passed-in name" do
        @posix.expects(:get_posix_field).with(:passwd, :uid, "asdf").returns 100
        @posix.expects(:get_posix_field).with(:passwd, :name, 100).returns "boo"

        @posix.expects(:search_posix_field).with(:passwd, :uid, "asdf").returns "asdf"

        @posix.uid("asdf").should == "asdf"
      end
    end
  end

  it "should be able to iteratively search for posix values" do
    @posix.should respond_to(:search_posix_field)
  end

  describe "when searching for posix values iteratively" do
    it "should iterate across all of the structs returned by Etc and return the appropriate field from the first matching value"
  end
end
