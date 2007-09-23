#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file/checksum'

module FileChecksumTesting
    def setup
        Puppet.settings.stubs(:use)
        @store = Puppet::Indirector::File::Checksum.new

        @value = "70924d6fa4b2d745185fa4660703a5c0"
        @sum = stub 'sum', :name => @value

        @dir = "/what/ever"

        Puppet.stubs(:[]).with(:bucketdir).returns(@dir)

        @path = @store.path(@value)
    end
end

describe Puppet::Indirector::File::Checksum do
    it "should be a subclass of the File terminus class" do
        Puppet::Indirector::File::Checksum.superclass.should equal(Puppet::Indirector::File)
    end

    it "should have documentation" do
        Puppet::Indirector::File::Checksum.doc.should be_instance_of(String)
    end
end

describe Puppet::Indirector::File::Checksum, " when initializing" do
    it "should use the filebucket settings section" do
        Puppet.settings.expects(:use).with(:filebucket)
        Puppet::Indirector::File::Checksum.new
    end
end

describe Puppet::Indirector::File::Checksum, " when determining file paths" do
    include FileChecksumTesting

    # I was previously passing the object in.
    it "should use the value passed in to path() as the checksum" do
        @value.expects(:name).never
        @store.path(@value)
    end

    it "should use the value of the :bucketdir setting as the root directory" do
        @path.should =~ %r{^#{@dir}}
    end

    it "should choose a path 8 directories deep with each directory name being the respective character in the checksum" do
        dirs = @value[0..7].split("").join(File::SEPARATOR)
        @path.should be_include(dirs)
    end

    it "should use the full checksum as the final directory name" do
        File.basename(File.dirname(@path)).should == @value
    end

    it "should use 'contents' as the actual file name" do
        File.basename(@path).should == "contents"
    end

    it "should use the bucketdir, the 8 sum character directories, the full checksum, and 'contents' as the full file name" do
        @path.should == [@dir, @value[0..7].split(""), @value, "contents"].flatten.join(File::SEPARATOR)
    end
end

describe Puppet::Indirector::File::Checksum, " when retrieving files" do
    include FileChecksumTesting

    # The smallest test that will use the calculated path
    it "should look for the calculated path" do
        File.expects(:exist?).with(@path).returns(false)
        @store.find(@value)
    end

    it "should return an instance of Puppet::Checksum with the checksum and content set correctly if the file exists" do
        content = "my content"
        sum = stub 'file'
        sum.expects(:content=).with(content)
        Puppet::Checksum.expects(:new).with(@value).returns(sum)

        File.expects(:exist?).with(@path).returns(true)
        File.expects(:read).with(@path).returns(content)

        @store.find(@value).should equal(sum)
    end

    it "should return nil if no file is found" do
        File.expects(:exist?).with(@path).returns(false)
        @store.find(@value).should be_nil
    end

    it "should fail intelligently if a found file cannot be read" do
        File.expects(:exist?).with(@path).returns(true)
        File.expects(:read).with(@path).raises(RuntimeError)
        proc { @store.find(@value) }.should raise_error(Puppet::Error)
    end
end

describe Puppet::Indirector::File::Checksum, " when saving files" do
    include FileChecksumTesting

    # LAK:FIXME I don't know how to include in the spec the fact that we're
    # using the superclass's save() method and thus are acquiring all of
    # it's behaviours.
    it "should save the content to the calculated path" do
        File.stubs(:directory?).with(File.dirname(@path)).returns(true)
        File.expects(:open).with(@path, "w")

        file = stub 'file', :name => @value
        @store.save(file)
    end

    it "should make any directories necessary for storage" do
        FileUtils.expects(:mkdir_p).with do |arg|
            File.umask == 0007 and arg == File.dirname(@path)
        end
        File.expects(:directory?).with(File.dirname(@path)).returns(true)
        File.expects(:open).with(@path, "w")

        file = stub 'file', :name => @value
        @store.save(file)
    end
end

describe Puppet::Indirector::File::Checksum, " when deleting files" do
    include FileChecksumTesting

    it "should remove the file at the calculated path" do
        File.expects(:exist?).with(@path).returns(true)
        File.expects(:unlink).with(@path)

        file = stub 'file', :name => @value
        @store.destroy(file)
    end
end
