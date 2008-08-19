#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

type = Puppet::Type.type(:newfile)

describe type do
    describe "when validating attributes" do
        %w{path}.each do |attr|
            it "should have a '#{attr}' parameter" do
                Puppet::Type.type(:newfile).attrtype(attr.intern).should == :param
            end
        end

        %w{content ensure owner group mode type}.each do |attr|
            it "should have a '#{attr}' property" do
                Puppet::Type.type(:newfile).attrtype(attr.intern).should == :property
            end
        end

        it "should have its 'path' attribute set as its namevar" do
            Puppet::Type.type(:newfile).namevar.should == :path
        end
    end

    describe "when validating 'ensure'" do
        before do
            @file = type.create :path => "/foo/bar"
        end

        it "should support 'absent' as a value" do
            lambda { @file[:ensure] = :absent }.should_not raise_error
        end

        it "should support 'file' as a value" do
            lambda { @file[:ensure] = :file }.should_not raise_error
        end

        it "should support 'directory' as a value" do
            lambda { @file[:ensure] = :directory }.should_not raise_error
        end

        it "should support 'link' as a value" do
            lambda { @file[:ensure] = :link }.should_not raise_error
        end

        it "should not support other values" do
            lambda { @file[:ensure] = :foo }.should raise_error(Puppet::Error)
        end
    end

    describe "when managing the file's type" do
        before do
            @file = type.create :path => "/foo/bar", :ensure => :absent

            # We need a catalog to do our actual work; this kinda blows.
            @catalog = Puppet::Node::Catalog.new
            @catalog.add_resource @file
            Puppet::Util::Log.newdestination :console
        end

        it "should use the provider's :type method to determine the current file type" do
            @file.provider.expects(:type).returns :file
            @file.retrieve
        end

        it "should use 'destroy' to remove the file" do
            @file.provider.stubs(:type).returns :file
            @file.provider.expects(:destroy)
            @catalog.apply
        end

        it "should use 'mkfile' to create a file when the file is absent" do
            @file[:ensure] = :file
            @file.provider.stubs(:type).returns :absent
            @file.provider.expects(:mkfile)
            @catalog.apply
        end

        it "should destroy the file and then use 'mkfile' to create a file when the file is present" do
            @file[:ensure] = :file
            @file.provider.stubs(:type).returns :directory
            @file.provider.expects(:destroy)
            @file.provider.expects(:mkfile)
            @catalog.apply
        end

        it "should use 'mkdir' to make a directory when the file is absent" do
            @file[:ensure] = :directory
            @file.provider.stubs(:type).returns :absent
            @file.provider.expects(:mkdir)
            @catalog.apply
        end

        it "should destroy the file then use 'mkdir' to make a directory when the file is present" do
            @file[:ensure] = :directory
            @file.provider.stubs(:type).returns :file
            @file.provider.expects(:destroy)
            @file.provider.expects(:mkdir)
            @catalog.apply
        end

        it "should use 'mklink' to make a link when the file is absent" do
            @file[:ensure] = :link
            @file.provider.stubs(:type).returns :absent
            @file.provider.expects(:mklink)
            @catalog.apply
        end

        it "should destroy the file then use 'mklink' to make a link when the file is present" do
            @file[:ensure] = :link
            @file.provider.stubs(:type).returns :file
            @file.provider.expects(:destroy)
            @file.provider.expects(:mklink)
            @catalog.apply
        end
    end
end
