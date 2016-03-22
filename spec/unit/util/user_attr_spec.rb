#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/user_attr'

describe UserAttr do
  before do
    user_attr = ["foo::::type=role", "bar::::type=normal;profile=foobar"]
    File.stubs(:readlines).returns(user_attr)
  end

  describe "when getting attributes by name" do
    it "should return nil if there is no entry for that name" do
      expect(UserAttr.get_attributes_by_name('baz')).to eq(nil)
    end

    it "should return a hash if there is an entry in /etc/user_attr" do
      expect(UserAttr.get_attributes_by_name('foo').class).to eq(Hash)
    end

    it "should return a hash with the name value from /etc/user_attr" do
      expect(UserAttr.get_attributes_by_name('foo')[:name]).to eq('foo')
    end

    #this test is contrived
    #there are a bunch of possible parameters that could be in the hash
    #the role/normal is just a the convention of the file
    describe "when the name is a role" do
      it "should contain :type = role" do
        expect(UserAttr.get_attributes_by_name('foo')[:type]).to eq('role')
      end
    end

    describe "when the name is not a role" do
      it "should contain :type = normal" do
        expect(UserAttr.get_attributes_by_name('bar')[:type]).to eq('normal')
      end
    end

    describe "when the name has more attributes" do
      it "should contain all the attributes" do
        expect(UserAttr.get_attributes_by_name('bar')[:profile]).to eq('foobar')
      end
    end
  end
end
