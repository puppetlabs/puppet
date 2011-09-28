#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/file_serving/fileset'

describe Puppet::FileServing::Fileset, " when initializing" do
  include PuppetSpec::Files

  before :each do
    @somefile = make_absolute("/some/file")
  end

  it "should require a path" do
    proc { Puppet::FileServing::Fileset.new }.should raise_error(ArgumentError)
  end

  it "should fail if its path is not fully qualified" do
    proc { Puppet::FileServing::Fileset.new("some/file") }.should raise_error(ArgumentError)
  end

  it "should not fail if the path is fully qualified, with a trailing separator" do
    path_with_separator = "#{@somefile}#{File::SEPARATOR}"
    File.stubs(:lstat).with(@somefile).returns stub('stat')
    fileset = Puppet::FileServing::Fileset.new(path_with_separator)
    fileset.path.should == @somefile
  end

  it "should not fail if the path is just the file separator" do
    path = File.expand_path(File::SEPARATOR)
    File.stubs(:lstat).with(path).returns stub('stat')
    fileset = Puppet::FileServing::Fileset.new(path)
    fileset.path.should == path
  end

  it "should fail if its path does not exist" do
    File.expects(:lstat).with(@somefile).returns nil
    proc { Puppet::FileServing::Fileset.new(@somefile) }.should raise_error(ArgumentError)
  end

  it "should accept a 'recurse' option" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    set = Puppet::FileServing::Fileset.new(@somefile, :recurse => true)
    set.recurse.should be_true
  end

  it "should accept a 'recurselimit' option" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    set = Puppet::FileServing::Fileset.new(@somefile, :recurselimit => 3)
    set.recurselimit.should == 3
  end

  it "should accept an 'ignore' option" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    set = Puppet::FileServing::Fileset.new(@somefile, :ignore => ".svn")
    set.ignore.should == [".svn"]
  end

  it "should accept a 'links' option" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    set = Puppet::FileServing::Fileset.new(@somefile, :links => :manage)
    set.links.should == :manage
  end

  it "should accept a 'checksum_type' option" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    set = Puppet::FileServing::Fileset.new(@somefile, :checksum_type => :test)
    set.checksum_type.should == :test
  end

  it "should fail if 'links' is set to anything other than :manage or :follow" do
    proc { Puppet::FileServing::Fileset.new(@somefile, :links => :whatever) }.should raise_error(ArgumentError)
  end

  it "should default to 'false' for recurse" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    Puppet::FileServing::Fileset.new(@somefile).recurse.should == false
  end

  it "should default to :infinite for recurselimit" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    Puppet::FileServing::Fileset.new(@somefile).recurselimit.should == :infinite
  end

  it "should default to an empty ignore list" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    Puppet::FileServing::Fileset.new(@somefile).ignore.should == []
  end

  it "should default to :manage for links" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    Puppet::FileServing::Fileset.new(@somefile).links.should == :manage
  end

  it "should support using an Indirector Request for its options" do
    File.expects(:lstat).with(@somefile).returns stub("stat")
    request = Puppet::Indirector::Request.new(:file_serving, :find, "foo")
    lambda { Puppet::FileServing::Fileset.new(@somefile, request) }.should_not raise_error
  end

  describe "using an indirector request" do
    before do
      File.stubs(:lstat).returns stub("stat")
      @values = {:links => :manage, :ignore => %w{a b}, :recurse => true, :recurselimit => 1234}
      @request = Puppet::Indirector::Request.new(:file_serving, :find, "foo")
      @myfile = make_absolute("/my/file")
    end

    [:recurse, :recurselimit, :ignore, :links].each do |option|
      it "should pass :recurse, :recurselimit, :ignore, and :links settings on to the fileset if present" do
        @request.stubs(:options).returns(option => @values[option])
        Puppet::FileServing::Fileset.new(@myfile, @request).send(option).should == @values[option]
      end

      it "should pass :recurse, :recurselimit, :ignore, and :links settings on to the fileset if present with the keys stored as strings" do
        @request.stubs(:options).returns(option.to_s => @values[option])
        Puppet::FileServing::Fileset.new(@myfile, @request).send(option).should == @values[option]
      end
    end

    it "should convert the integer as a string to their integer counterpart when setting options" do
      @request.stubs(:options).returns(:recurselimit => "1234")
      Puppet::FileServing::Fileset.new(@myfile, @request).recurselimit.should == 1234
    end

    it "should convert the string 'true' to the boolean true when setting options" do
      @request.stubs(:options).returns(:recurse => "true")
      Puppet::FileServing::Fileset.new(@myfile, @request).recurse.should == true
    end

    it "should convert the string 'false' to the boolean false when setting options" do
      @request.stubs(:options).returns(:recurse => "false")
      Puppet::FileServing::Fileset.new(@myfile, @request).recurse.should == false
    end
  end
end

describe Puppet::FileServing::Fileset, " when determining whether to recurse" do
  include PuppetSpec::Files

  before do
    @path = make_absolute("/my/path")
    File.expects(:lstat).with(@path).returns stub("stat")
    @fileset = Puppet::FileServing::Fileset.new(@path)
  end

  it "should always recurse if :recurse is set to 'true' and with infinite recursion" do
    @fileset.recurse = true
    @fileset.recurselimit = :infinite
    @fileset.recurse?(0).should be_true
  end

  it "should never recurse if :recurse is set to 'false'" do
    @fileset.recurse = false
    @fileset.recurse?(-1).should be_false
  end

  it "should recurse if :recurse is set to true, :recurselimit is set to an integer and the current depth is less than that integer" do
    @fileset.recurse = true
    @fileset.recurselimit = 1
    @fileset.recurse?(0).should be_true
  end

  it "should recurse if :recurse is set to true, :recurselimit is set to an integer and the current depth is equal to that integer" do
    @fileset.recurse = true
    @fileset.recurselimit = 1
    @fileset.recurse?(1).should be_true
  end

  it "should not recurse if :recurse is set to true, :recurselimit is set to an integer and the current depth is greater than that integer" do
    @fileset.recurse = true
    @fileset.recurselimit = 1
    @fileset.recurse?(2).should be_false
  end
end

describe Puppet::FileServing::Fileset, " when recursing" do
  include PuppetSpec::Files

  before do
    @path = make_absolute("/my/path")
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
  it "should recurse to the level set if :recurselimit is set to an integer" do
    mock_dir_structure(@path)
    @fileset.recurse = true
    @fileset.recurselimit = 1
    @fileset.files.should == %w{. one two .svn CVS}
  end

  it "should ignore the '.' and '..' directories in subdirectories" do
    mock_dir_structure(@path)
    @fileset.recurse = true
    @fileset.files.sort.should == @files.sort
  end

  it "should function if the :ignore value provided is nil" do
    mock_dir_structure(@path)
    @fileset.recurse = true
    @fileset.ignore = nil
    lambda { @fileset.files }.should_not raise_error
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
    @path = make_absolute("/my/path/rV1x2DafFr0R6tGG+1bbk++++TM")
    File.expects(:lstat).with(@path).returns stub("stat", :directory? => true)
    @fileset = Puppet::FileServing::Fileset.new(@path)
    mock_dir_structure(@path)
    @fileset.recurse = true
    @fileset.files.sort.should == @files.sort
  end
end

describe Puppet::FileServing::Fileset, " when following links that point to missing files" do
  include PuppetSpec::Files

  before do
    @path = make_absolute("/my/path")
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
  include PuppetSpec::Files

  before do
    @path = make_absolute("/my/path")
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

describe Puppet::FileServing::Fileset, "when merging other filesets" do
  include PuppetSpec::Files

  before do
    @paths = [make_absolute("/first/path"), make_absolute("/second/path"), make_absolute("/third/path")]
    File.stubs(:lstat).returns stub("stat", :directory? => false)

    @filesets = @paths.collect do |path|
      File.stubs(:lstat).with(path).returns stub("stat", :directory? => true)
      Puppet::FileServing::Fileset.new(path, :recurse => true)
    end

    Dir.stubs(:entries).returns []
  end

  it "should return a hash of all files in each fileset with the value being the base path" do
    Dir.expects(:entries).with(make_absolute("/first/path")).returns(%w{one uno})
    Dir.expects(:entries).with(make_absolute("/second/path")).returns(%w{two dos})
    Dir.expects(:entries).with(make_absolute("/third/path")).returns(%w{three tres})

    Puppet::FileServing::Fileset.merge(*@filesets).should == {
      "." => make_absolute("/first/path"),
      "one" => make_absolute("/first/path"),
      "uno" => make_absolute("/first/path"),
      "two" => make_absolute("/second/path"),
      "dos" => make_absolute("/second/path"),
      "three" => make_absolute("/third/path"),
      "tres" => make_absolute("/third/path"),
    }
  end

  it "should include the base directory from the first fileset" do
    Dir.expects(:entries).with(make_absolute("/first/path")).returns(%w{one})
    Dir.expects(:entries).with(make_absolute("/second/path")).returns(%w{two})

    Puppet::FileServing::Fileset.merge(*@filesets)["."].should == make_absolute("/first/path")
  end

  it "should use the base path of the first found file when relative file paths conflict" do
    Dir.expects(:entries).with(make_absolute("/first/path")).returns(%w{one})
    Dir.expects(:entries).with(make_absolute("/second/path")).returns(%w{one})

    Puppet::FileServing::Fileset.merge(*@filesets)["one"].should == make_absolute("/first/path")
  end
end
