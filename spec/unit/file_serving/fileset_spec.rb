#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/fileset'

describe Puppet::FileServing::Fileset do
  include PuppetSpec::Files
  let(:somefile) { make_absolute("/some/file") }

  context "when initializing" do
    it "requires a path" do
      expect { Puppet::FileServing::Fileset.new }.to raise_error(ArgumentError)
    end

    it "fails if its path is not fully qualified" do
      expect { Puppet::FileServing::Fileset.new("some/file") }.to raise_error(ArgumentError, "Fileset paths must be fully qualified: some/file")
    end

    it "removes a trailing file path separator" do
      path_with_separator = "#{somefile}#{File::SEPARATOR}"
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      fileset = Puppet::FileServing::Fileset.new(path_with_separator)
      fileset.path.should == somefile
    end

    it "can be created from the root directory" do
      path = File.expand_path(File::SEPARATOR)
      Puppet::FileSystem.expects(:lstat).with(path).returns stub('stat')
      fileset = Puppet::FileServing::Fileset.new(path)
      fileset.path.should == path
    end

    it "fails if its path does not exist" do
      Puppet::FileSystem.expects(:lstat).with(somefile).raises(Errno::ENOENT)
      expect { Puppet::FileServing::Fileset.new(somefile) }.to raise_error(ArgumentError, "Fileset paths must exist")
    end

    it "accepts a 'recurse' option" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      set = Puppet::FileServing::Fileset.new(somefile, :recurse => true)
      set.recurse.should be_true
    end

    it "accepts a 'recurselimit' option" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      set = Puppet::FileServing::Fileset.new(somefile, :recurselimit => 3)
      set.recurselimit.should == 3
    end

    it "accepts an 'ignore' option" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      set = Puppet::FileServing::Fileset.new(somefile, :ignore => ".svn")
      set.ignore.should == [".svn"]
    end

    it "accepts a 'links' option" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      set = Puppet::FileServing::Fileset.new(somefile, :links => :manage)
      set.links.should == :manage
    end

    it "accepts a 'checksum_type' option" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      set = Puppet::FileServing::Fileset.new(somefile, :checksum_type => :test)
      set.checksum_type.should == :test
    end

    it "fails if 'links' is set to anything other than :manage or :follow" do
      expect { Puppet::FileServing::Fileset.new(somefile, :links => :whatever) }.to raise_error(ArgumentError, "Invalid :links value 'whatever'")
    end

    it "defaults to 'false' for recurse" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      Puppet::FileServing::Fileset.new(somefile).recurse.should == false
    end

    it "defaults to :infinite for recurselimit" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      Puppet::FileServing::Fileset.new(somefile).recurselimit.should == :infinite
    end

    it "defaults to an empty ignore list" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      Puppet::FileServing::Fileset.new(somefile).ignore.should == []
    end

    it "defaults to :manage for links" do
      Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      Puppet::FileServing::Fileset.new(somefile).links.should == :manage
    end

    describe "using an indirector request" do
      let(:values) { { :links => :manage, :ignore => %w{a b}, :recurse => true, :recurselimit => 1234 } }
      let(:stub_file) { stub(somefile, :lstat => stub('stat')) }

      before :each do
        Puppet::FileSystem.expects(:lstat).with(somefile).returns stub('stat')
      end

      [:recurse, :recurselimit, :ignore, :links].each do |option|
        it "passes the #{option} option on to the fileset if present" do
          request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil, {option => values[option]})

          Puppet::FileServing::Fileset.new(somefile, request).send(option).should == values[option]
        end
      end

      it "converts the integer as a string to their integer counterpart when setting options" do
        request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil,
                                                  {:recurselimit => "1234"})

        Puppet::FileServing::Fileset.new(somefile, request).recurselimit.should == 1234
      end

      it "converts the string 'true' to the boolean true when setting options" do
        request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil,
                                                  {:recurse => "true"})

        Puppet::FileServing::Fileset.new(somefile, request).recurse.should == true
      end

      it "converts the string 'false' to the boolean false when setting options" do
        request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil,
                                                  {:recurse => "false"})

        Puppet::FileServing::Fileset.new(somefile, request).recurse.should == false
      end
    end
  end

  context "when recursing" do
    before do
      @path = make_absolute("/my/path")
      Puppet::FileSystem.stubs(:lstat).with(@path).returns stub('stat', :directory? => true)

      @fileset = Puppet::FileServing::Fileset.new(@path)

      @dirstat = stub 'dirstat', :directory? => true
      @filestat = stub 'filestat', :directory? => false
    end

    def mock_dir_structure(path, stat_method = :lstat)
      Puppet::FileSystem.stubs(stat_method).with(path).returns @dirstat

      # Keep track of the files we're stubbing.
      @files = %w{.}

      top_names = %w{one two .svn CVS}
      sub_names = %w{file1 file2 .svn CVS 0 false}

      Dir.stubs(:entries).with(path).returns(top_names)
      top_names.each do |subdir|
        @files << subdir # relative path
        subpath = File.join(path, subdir)
        Puppet::FileSystem.stubs(stat_method).with(subpath).returns @dirstat
        Dir.stubs(:entries).with(subpath).returns(sub_names)
        sub_names.each do |file|
          @files << File.join(subdir, file) # relative path
          subfile_path = File.join(subpath, file)
          Puppet::FileSystem.stubs(stat_method).with(subfile_path).returns(@filestat)
        end
      end
    end

    MockStat = Struct.new(:path, :directory) do
      # struct doesn't support thing ending in ?
      def directory?
        directory
      end
    end

    MockDirectory = Struct.new(:name, :entries) do
      def mock(base_path)
        extend Mocha::API
        path = File.join(base_path, name)
        Puppet::FileSystem.stubs(:lstat).with(path).returns MockStat.new(path, true)
        Dir.stubs(:entries).with(path).returns(['.', '..'] + entries.map(&:name))
        entries.each do |entry|
          entry.mock(path)
        end
      end
    end

    MockFile = Struct.new(:name) do
      def mock(base_path)
        extend Mocha::API
        path = File.join(base_path, name)
        Puppet::FileSystem.stubs(:lstat).with(path).returns MockStat.new(path, false)
      end
    end

    it "doesn't ignore pending directories when the last entry at the top level is a file" do
      structure = MockDirectory.new('path',
                    [MockDirectory.new('dir1',
                                   [MockDirectory.new('a', [MockFile.new('f')])]),
                     MockFile.new('file')])
      structure.mock(make_absolute('/your'))
      fileset = Puppet::FileServing::Fileset.new(make_absolute('/your/path'))
      fileset.recurse = true
      fileset.links = :manage
      fileset.files.should == [".", "dir1", "file", "dir1/a", "dir1/a/f"]
    end

    it "recurses through the whole file tree if :recurse is set to 'true'" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.files.sort.should == @files.sort
    end

    it "does not recurse if :recurse is set to 'false'" do
      mock_dir_structure(@path)
      @fileset.recurse = false
      @fileset.files.should == %w{.}
    end

    it "recurses to the level set by :recurselimit" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.recurselimit = 1
      @fileset.files.should == %w{. one two .svn CVS}
    end

    it "ignores the '.' and '..' directories in subdirectories" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.files.sort.should == @files.sort
    end

    it "does not fail if the :ignore value provided is nil" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = nil
      expect { @fileset.files }.to_not raise_error
    end

    it "ignores files that match a single pattern in the ignore list" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = ".svn"
      @fileset.files.find { |file| file.include?(".svn") }.should be_nil
    end

    it "ignores files that match any of multiple patterns in the ignore list" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = %w{.svn CVS}
      @fileset.files.find { |file| file.include?(".svn") or file.include?("CVS") }.should be_nil
    end

    it "ignores files that match a pattern given as a number" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = [0]
      @fileset.files.find { |file| file.include?("0") }.should be_nil
    end

    it "ignores files that match a pattern given as a boolean" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = [false]
      @fileset.files.find { |file| file.include?("false") }.should be_nil
    end

    it "uses Puppet::FileSystem#stat if :links is set to :follow" do
      mock_dir_structure(@path, :stat)
      @fileset.recurse = true
      @fileset.links = :follow
      @fileset.files.sort.should == @files.sort
    end

    it "uses Puppet::FileSystem#lstat if :links is set to :manage" do
      mock_dir_structure(@path, :lstat)
      @fileset.recurse = true
      @fileset.links = :manage
      @fileset.files.sort.should == @files.sort
    end

    it "works when paths have regexp significant characters" do
      @path = make_absolute("/my/path/rV1x2DafFr0R6tGG+1bbk++++TM")
      stat = stub('dir_stat', :directory? => true)
      stub_file = stub(@path, :stat => stat, :lstat => stat)
      Puppet::FileSystem.expects(:lstat).with(@path).returns stub(@path, :stat => stat, :lstat => stat)
      @fileset = Puppet::FileServing::Fileset.new(@path)
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.files.sort.should == @files.sort
    end
  end

  it "manages the links to missing files" do
    path = make_absolute("/my/path")
    stat = stub 'stat', :directory? => true

    Puppet::FileSystem.expects(:stat).with(path).returns stat
    Puppet::FileSystem.expects(:lstat).with(path).returns stat

    link_path = File.join(path, "mylink")
    Puppet::FileSystem.expects(:stat).with(link_path).raises(Errno::ENOENT)

    Dir.stubs(:entries).with(path).returns(["mylink"])

    fileset = Puppet::FileServing::Fileset.new(path)

    fileset.links = :follow
    fileset.recurse = true

    fileset.files.sort.should == %w{. mylink}.sort
  end

  context "when merging other filesets" do
    before do
      @paths = [make_absolute("/first/path"), make_absolute("/second/path"), make_absolute("/third/path")]
      Puppet::FileSystem.stubs(:lstat).returns stub('stat', :directory? => false)

      @filesets = @paths.collect do |path|
        Puppet::FileSystem.stubs(:lstat).with(path).returns stub('stat', :directory? => true)
        Puppet::FileServing::Fileset.new(path, :recurse => true)
      end

      Dir.stubs(:entries).returns []
    end

    it "returns a hash of all files in each fileset with the value being the base path" do
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

    it "includes the base directory from the first fileset" do
      Dir.expects(:entries).with(make_absolute("/first/path")).returns(%w{one})
      Dir.expects(:entries).with(make_absolute("/second/path")).returns(%w{two})

      Puppet::FileServing::Fileset.merge(*@filesets)["."].should == make_absolute("/first/path")
    end

    it "uses the base path of the first found file when relative file paths conflict" do
      Dir.expects(:entries).with(make_absolute("/first/path")).returns(%w{one})
      Dir.expects(:entries).with(make_absolute("/second/path")).returns(%w{one})

      Puppet::FileServing::Fileset.merge(*@filesets)["one"].should == make_absolute("/first/path")
    end
  end
end

