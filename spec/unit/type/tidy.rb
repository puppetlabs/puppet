#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:tidy) do
    it "should use :lstat when stating a file" do
        tidy = Puppet::Type.type(:tidy).create :path => "/foo/bar", :age => "1d"
        stat = mock 'stat'
        File.expects(:lstat).with("/foo/bar").returns stat
        tidy.stat.should == stat
    end

    [:ensure, :age, :size].each do |property|
        it "should have a %s property" % property do
            Puppet::Type.type(:tidy).attrclass(property).ancestors.should be_include(Puppet::Property)
        end

        it "should have documentation for its %s property" % property do
            Puppet::Type.type(:tidy).attrclass(property).doc.should be_instance_of(String)
        end
    end

    [:path, :matches, :type, :recurse, :rmdirs].each do |param|
        it "should have a %s parameter" % param do
            Puppet::Type.type(:tidy).attrclass(param).ancestors.should be_include(Puppet::Parameter)
        end

        it "should have documentation for its %s param" % param do
            Puppet::Type.type(:tidy).attrclass(param).doc.should be_instance_of(String)
        end
    end

    describe "when validating parameter values" do
        describe "for 'recurse'" do
            before do
                @tidy = Puppet::Type.type(:tidy).create :path => "/tmp", :age => "100d"
            end

            it "should allow 'true'" do
                lambda { @tidy[:recurse] = true }.should_not raise_error
            end

            it "should allow 'false'" do
                lambda { @tidy[:recurse] = false }.should_not raise_error
            end

            it "should allow integers" do
                lambda { @tidy[:recurse] = 10 }.should_not raise_error
            end

            it "should allow string representations of integers" do
                lambda { @tidy[:recurse] = "10" }.should_not raise_error
            end

            it "should allow 'inf'" do
                lambda { @tidy[:recurse] = "inf" }.should_not raise_error
            end

            it "should not allow arbitrary values" do
                lambda { @tidy[:recurse] = "whatever" }.should raise_error
            end
        end
    end
end
