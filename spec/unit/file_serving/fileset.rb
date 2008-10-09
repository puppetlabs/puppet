#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/fileset'

describe Puppet::FileServing::Fileset, " when initializing" do
    it "should require a path" do
        proc { Puppet::FileServing::Fileset.new }.should raise_error(ArgumentError)
    end

    it "should fail if its path is not fully qualified" do
        proc { Puppet::FileServing::Fileset.new("some/file") }.should raise_error(ArgumentError)
    end

    it "should fail if its path does not exist" do
        File.expects(:lstat).with("/some/file").returns nil
        proc { Puppet::FileServing::Fileset.new("/some/file") }.should raise_error(ArgumentError)
    end

    it "should accept a 'recurse' option" do
        File.expects(:lstat).with("/some/file").returns stub("stat")
        set = Puppet::FileServing::Fileset.new("/some/file", :recurse => true)
        set.recurse.should be_true
    end

    it "should accept an 'ignore' option" do
        File.expects(:lstat).with("/some/file").returns stub("stat")
        set = Puppet::FileServing::Fileset.new("/some/file", :ignore => ".svn")
        set.ignore.should == [".svn"]
    end

    it "should accept a 'links' option" do
        File.expects(:lstat).with("/some/file").returns stub("stat")
        set = Puppet::FileServing::Fileset.new("/some/file", :links => :manage)
        set.links.should == :manage
    end

    it "should fail if 'links' is set to anything other than :manage or :follow" do
        proc { Puppet::FileServing::Fileset.new("/some/file", :links => :whatever) }.should raise_error(ArgumentError)
    end

    it "should default to 'false' for recurse" do
        File.expects(:lstat).with("/some/file").returns stub("stat")
        Puppet::FileServing::Fileset.new("/some/file").recurse.should == false
    end

    it "should default to an empty ignore list" do
        File.expects(:lstat).with("/some/file").returns stub("stat")
        Puppet::FileServing::Fileset.new("/some/file").ignore.should == []
    end

    it "should default to :manage for links" do
        File.expects(:lstat).with("/some/file").returns stub("stat")
        Puppet::FileServing::Fileset.new("/some/file").links.should == :manage
    end
end

describe Puppet::FileServing::Fileset, " when determining whether to recurse" do
    before do
        @path = "/my/path"
        File.expects(:lstat).with(@path).returns stub("stat")
        @fileset = Puppet::FileServing::Fileset.new(@path)
    end

    it "should always recurse if :recurse is set to 'true'" do
        @fileset.recurse = true
        @fileset.recurse?(0).should be_true
    end

    it "should never recurse if :recurse is set to 'false'" do
        @fileset.recurse = false
        @fileset.recurse?(-1).should be_false
    end

    it "should recurse if :recurse is set to an integer and the current depth is less than that integer" do
        @fileset.recurse = 1
        @fileset.recurse?(0).should be_true
    end

    it "should recurse if :recurse is set to an integer and the current depth is equal to that integer" do
        @fileset.recurse = 1
        @fileset.recurse?(1).should be_true
    end

    it "should not recurse if :recurse is set to an integer and the current depth is greater than that integer" do
        @fileset.recurse = 1
        @fileset.recurse?(2).should be_false
    end

    it "should not recurse if :recurse is set to 0" do
        @fileset.recurse = 0
        @fileset.recurse?(-1).should be_false
    end
end

describe Puppet::FileServing::Fileset, " when recursing" do
    before do
        @path = "/my/path"
        File.expects(:lstat).with(@path).returns stub("stat", :directory? => true)
        @fileset = Puppet::FileServing::Fileset.new(@path)

        @dirstat = stub 'dirstat', :directory? => true
        @filestat = stub 'filestat', :directory? => false
    end

    def mock_dir_structure(path, stat_method = :lstat)
        File.stubs(stat_method).with(path).returns(@dirstat)
        Dir.stubs(:entries).with(path).returns(%w{one two .svn CVS})

        # Keep track of the files we're stubbing.
        @files = %w{.}

        %w{one two .svn CVS}.each do |subdir|
            @files << subdir # relative path
            subpath = File.join(path, subdir)
            File.stubs(stat_method).with(subpath).returns(@dirstat)
            Dir.stubs(:entries).with(subpath).returns(%w{.svn CVS file1 file2})
            %w{file1 file2 .svn CVS}.each do |file|
                @files << File.join(subdir, file) # relative path
                File.stubs(stat_method).with(File.join(subpath, file)).returns(@filestat)
            end
        end
    end

    it "should recurse through the whole file tree if :recurse is set to 'true'" do
        mock_dir_structure(@path)
        @fileset.stubs(:recurse?).returns(true)
        @fileset.files.sort.should == @files.sort
    end

    it "should not recurse if :recurse is set to 'false'" do
        mock_dir_structure(@path)
        @fileset.stubs(:recurse?).returns(false)
        @fileset.files.should == %w{.}
    end

    # It seems like I should stub :recurse? here, or that I shouldn't stub the
    # examples above, but...
    it "should recurse to the level set if :recurse is set to an integer" do
        mock_dir_structure(@path)
        @fileset.recurse = 1
        @fileset.files.should == %w{. one two .svn CVS}
    end

    it "should ignore the '.' and '..' directories in subdirectories" do
        mock_dir_structure(@path)
        @fileset.recurse = true
        @fileset.files.sort.should == @files.sort
    end

    it "should ignore files that match a single pattern in the ignore list" do
        mock_dir_structure(@path)
        @fileset.recurse = true
        @fileset.ignore = ".svn"
        @fileset.files.find { |file| file.include?(".svn") }.should be_nil
    end

    it "should ignore files that match any of multiple patterns in the ignore list" do
        mock_dir_structure(@path)
        @fileset.recurse = true
        @fileset.ignore = %w{.svn CVS}
        @fileset.files.find { |file| file.include?(".svn") or file.include?("CVS") }.should be_nil
    end

    it "should use File.stat if :links is set to :follow" do
        mock_dir_structure(@path, :stat)
        @fileset.recurse = true
        @fileset.links = :follow
        @fileset.files.sort.should == @files.sort
    end

    it "should use File.lstat if :links is set to :manage" do
        mock_dir_structure(@path, :lstat)
        @fileset.recurse = true
        @fileset.links = :manage
        @fileset.files.sort.should == @files.sort
    end

    it "should succeed when paths have regexp significant characters" do
        @path = "/my/path/rV1x2DafFr0R6tGG+1bbk++++TM"
        File.expects(:lstat).with(@path).returns stub("stat", :directory? => true)
        @fileset = Puppet::FileServing::Fileset.new(@path)
        mock_dir_structure(@path)
        @fileset.recurse = true
        @fileset.files.sort.should == @files.sort
    end
end

describe Puppet::FileServing::Fileset, " when following links that point to missing files" do
    before do
        @path = "/my/path"
        File.expects(:lstat).with(@path).returns stub("stat", :directory? => true)
        @fileset = Puppet::FileServing::Fileset.new(@path)
        @fileset.links = :follow
        @fileset.recurse = true

        @stat = stub 'stat', :directory? => true

        File.expects(:stat).with(@path).returns(@stat)
        File.expects(:stat).with(File.join(@path, "mylink")).raises(Errno::ENOENT)
        Dir.stubs(:entries).with(@path).returns(["mylink"])
    end

    it "should not fail" do
        proc { @fileset.files }.should_not raise_error
    end

    it "should still manage the link" do
        @fileset.files.sort.should == %w{. mylink}.sort
    end
end

describe Puppet::FileServing::Fileset, " when ignoring" do
    before do
        @path = "/my/path"
        File.expects(:lstat).with(@path).returns stub("stat", :directory? => true)
        @fileset = Puppet::FileServing::Fileset.new(@path)
    end

    it "should use ruby's globbing to determine what files should be ignored" do
        @fileset.ignore = ".svn"
        File.expects(:fnmatch?).with(".svn", "my_file")
        @fileset.ignore?("my_file")
    end

    it "should ignore files whose paths match a single provided ignore value" do
        @fileset.ignore = ".svn"
        File.stubs(:fnmatch?).with(".svn", "my_file").returns true
        @fileset.ignore?("my_file").should be_true
    end

    it "should ignore files whose paths match any of multiple provided ignore values" do
        @fileset.ignore = [".svn", "CVS"]
        File.stubs(:fnmatch?).with(".svn", "my_file").returns false
        File.stubs(:fnmatch?).with("CVS", "my_file").returns true
        @fileset.ignore?("my_file").should be_true
    end
end
