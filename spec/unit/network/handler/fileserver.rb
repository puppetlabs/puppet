#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/network/handler/fileserver'


describe Puppet::Network::Handler do
    require 'tmpdir'

    def create_file(filename)
        File.open(filename, "w") { |f| f.puts filename}
    end

    def create_nested_file()
        dirname = File.join(@basedir, "nested_dir")
        Dir.mkdir(dirname)
        file = File.join(dirname, "nested_dir_file")
        create_file(file)
    end

    before do
        @basedir = File.join(Dir.tmpdir(), "test_network_handler")
        Dir.mkdir(@basedir)
        @file = File.join(@basedir, "aFile")
        @link = File.join(@basedir, "aLink")
        create_file(@file)
        @mount = Puppet::Network::Handler::FileServer::Mount.new("some_path", @basedir)
    end

    it "should list a single directory" do
        @mount.list("/", false, false).should == [["/", "directory"]]
    end

    it "should list a file within a directory when given the file path" do
        @mount.list("/aFile", false, "false").should == [["/", "file"]]
    end

    it "should return nil for a non-existent path" do
        @mount.list("/no_such_file", false, false).should be(nil)
    end

    it "should list a symbolic link as a file when given the link path" do
        File.symlink(@file, @link)
        @mount.list("/aLink", false, false).should == [["/", "file"]]
    end

    it "should return nil for a dangling symbolic link when given the link path" do
        File.symlink("/some/where", @link)
        @mount.list("/aLink", false, false).should be(nil)
    end

    it "should list directory contents of a flat directory structure when asked to recurse" do
        list = @mount.list("/", true, false)
        list.should include(["/aFile", "file"])
        list.should include(["/", "directory"])
        list.should have(2).items
    end

    it "should list the contents of a nested directory" do
        create_nested_file()
        list = @mount.list("/", true, false)
        list.sort.should == [   ["/aFile", "file"], ["/", "directory"] ,
                                ["/nested_dir", "directory"], ["/nested_dir/nested_dir_file", "file"]].sort
    end

    it "should list the contents of a directory ignoring files that match" do
        create_nested_file()
        list = @mount.list("/", true, "*File")
        list.sort.should == [   ["/", "directory"] ,
                                ["/nested_dir", "directory"], ["/nested_dir/nested_dir_file", "file"]].sort
    end

    it "should list the contents of a directory ignoring directories that match" do
        create_nested_file()
        list = @mount.list("/", true, "*nested_dir")
        list.sort.should == [   ["/aFile", "file"], ["/", "directory"] ].sort
    end

    it "should list the contents of a directory ignoring all ignore patterns that match" do
        create_nested_file()
        list = @mount.list("/", true, ["*File" , "*nested_dir"])
        list.should == [ ["/", "directory"] ]
    end

    it "should list the directory when recursing to a depth of zero" do
        create_nested_file()
        list = @mount.list("/", 0, false)
        list.should == [["/", "directory"]]
    end

    it "should list the base directory and files and nested directory to a depth of one" do
        create_nested_file()
        list = @mount.list("/", 1, false)
        list.sort.should == [ ["/aFile", "file"], ["/nested_dir", "directory"], ["/", "directory"] ].sort
    end

    it "should list the base directory and files and nested directory to a depth of two" do
        create_nested_file()
        list = @mount.list("/", 2, false)
        list.sort.should == [   ["/aFile", "file"], ["/", "directory"] ,
                                ["/nested_dir", "directory"], ["/nested_dir/nested_dir_file", "file"]].sort
    end

    it "should list the base directory and files and nested directory to a depth greater than the directory structure" do
        create_nested_file()
        list = @mount.list("/", 42, false)
        list.sort.should == [   ["/aFile", "file"], ["/", "directory"] ,
                                ["/nested_dir", "directory"], ["/nested_dir/nested_dir_file", "file"]].sort
    end

    it "should list a valid symbolic link as a file when recursing base dir" do
        File.symlink(@file, @link)
        list = @mount.list("/", true, false)
        list.sort.should == [ ["/", "directory"], ["/aFile", "file"], ["/aLink", "file"] ].sort
    end

    it "should not error when a dangling symlink is present" do
        File.symlink("/some/where", @link)
        lambda { @mount.list("/", true, false) }.should_not raise_error
    end

    it "should return the directory contents of valid entries when a dangling symlink is present" do
        File.symlink("/some/where", @link)
        list = @mount.list("/", true, false)
        list.sort.should == [ ["/aFile", "file"], ["/", "directory"] ].sort
    end

    after do
        FileUtils.rm_rf(@basedir)
    end

end