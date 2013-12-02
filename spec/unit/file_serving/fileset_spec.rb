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
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      fileset = Puppet::FileServing::Fileset.new(path_with_separator)
      fileset.path.should == somefile
    end

    it "can be created from the root directory" do
      path = File.expand_path(File::SEPARATOR)
      stub_file = stub(path, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(path).returns stub_file
      fileset = Puppet::FileServing::Fileset.new(path)
      fileset.path.should == path
    end

    it "fails if its path does not exist" do
      mock_file = mock(somefile)
      Puppet::FileSystem::File.expects(:new).with(somefile).returns mock_file
      mock_file.expects(:lstat).raises(Errno::ENOENT)
      expect { Puppet::FileServing::Fileset.new(somefile) }.to raise_error(ArgumentError, "Fileset paths must exist")
    end

    it "accepts a 'recurse' option" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      set = Puppet::FileServing::Fileset.new(somefile, :recurse => true)
      set.recurse.should be_true
    end

    it "accepts a 'recurselimit' option" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      set = Puppet::FileServing::Fileset.new(somefile, :recurselimit => 3)
      set.recurselimit.should == 3
    end

    it "accepts an 'ignore' option" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      set = Puppet::FileServing::Fileset.new(somefile, :ignore => ".svn")
      set.ignore.should == [".svn"]
    end

    it "accepts a 'links' option" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      set = Puppet::FileServing::Fileset.new(somefile, :links => :manage)
      set.links.should == :manage
    end

    it "accepts a 'checksum_type' option" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      set = Puppet::FileServing::Fileset.new(somefile, :checksum_type => :test)
      set.checksum_type.should == :test
    end

    it "fails if 'links' is set to anything other than :manage or :follow" do
      expect { Puppet::FileServing::Fileset.new(somefile, :links => :whatever) }.to raise_error(ArgumentError, "Invalid :links value 'whatever'")
    end

    it "defaults to 'false' for recurse" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      Puppet::FileServing::Fileset.new(somefile).recurse.should == false
    end

    it "defaults to :infinite for recurselimit" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      Puppet::FileServing::Fileset.new(somefile).recurselimit.should == :infinite
    end

    it "defaults to an empty ignore list" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      Puppet::FileServing::Fileset.new(somefile).ignore.should == []
    end

    it "defaults to :manage for links" do
      stub_file = stub(somefile, :lstat => stub('stat'))
      Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
      Puppet::FileServing::Fileset.new(somefile).links.should == :manage
    end

    describe "using an indirector request" do
      let(:values) { { :links => :manage, :ignore => %w{a b}, :recurse => true, :recurselimit => 1234 } }
      let(:stub_file) { stub(somefile, :lstat => stub('stat')) }

      before :each do
        Puppet::FileSystem::File.expects(:new).with(somefile).returns stub_file
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
      @stub_file = stub(@path, :lstat => stub('stat', :directory? => true))
      Puppet::FileSystem::File.stubs(:new).with(@path).returns @stub_file
      @fileset = Puppet::FileServing::Fileset.new(@path)

      @dirstat = stub 'dirstat', :directory? => true
      @filestat = stub 'filestat', :directory? => false
    end

    def mock_dir_structure(path, stat_method = :lstat)
      @stub_file.stubs(stat_method).returns(@dirstat)
      Dir.stubs(:entries).with(path).returns(%w{one two .svn CVS})

      # Keep track of the files we're stubbing.
      @files = %w{.}

      %w{one two .svn CVS}.each do |subdir|
        @files << subdir # relative path
        subpath = File.join(path, subdir)
        stub_subpath = stub(subpath, stat_method => @dirstat)
        Puppet::FileSystem::File.stubs(:new).with(subpath).returns stub_subpath
        Dir.stubs(:entries).with(subpath).returns(%w{.svn CVS file1 file2})
        %w{file1 file2 .svn CVS}.each do |file|
          @files << File.join(subdir, file) # relative path
          subfile_path = File.join(subpath, file)
          stub_subfile_path = stub(subfile_path, stat_method => @filestat)
          Puppet::FileSystem::File.stubs(:new).with(subfile_path).returns stub_subfile_path
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
        stub_dir = stub(path, :lstat => MockStat.new(path, true))
        Puppet::FileSystem::File.stubs(:new).with(path).returns stub_dir
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
        stub_file = stub(path, :lstat => MockStat.new(path, false))
        Puppet::FileSystem::File.stubs(:new).with(path).returns stub_file
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

    it "uses Puppet::FileSystem::File#stat if :links is set to :follow" do
      mock_dir_structure(@path, :stat)
      @fileset.recurse = true
      @fileset.links = :follow
      @fileset.files.sort.should == @files.sort
    end

    it "uses Puppet::FileSystem::File#lstat if :links is set to :manage" do
      mock_dir_structure(@path, :lstat)
      @fileset.recurse = true
      @fileset.links = :manage
      @fileset.files.sort.should == @files.sort
    end

    it "works when paths have regexp significant characters" do
      @path = make_absolute("/my/path/rV1x2DafFr0R6tGG+1bbk++++TM")
      stat = stub('dir_stat', :directory? => true)
      stub_file = stub(@path, :stat => stat, :lstat => stat)
      Puppet::FileSystem::File.expects(:new).with(@path).twice.returns stub_file
      @fileset = Puppet::FileServing::Fileset.new(@path)
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.files.sort.should == @files.sort
    end
  end

  it "manages the links to missing files" do
    path = make_absolute("/my/path")
    stat = stub 'stat', :directory? => true

    mock_file = mock(path, :lstat => stat, :stat => stat)
    Puppet::FileSystem::File.expects(:new).with(path).twice.returns mock_file

    link_path = File.join(path, "mylink")
    mock_link = mock(link_path)
    Puppet::FileSystem::File.expects(:new).with(link_path).returns mock_link
    mock_link.expects(:stat).raises(Errno::ENOENT)

    Dir.stubs(:entries).with(path).returns(["mylink"])

    fileset = Puppet::FileServing::Fileset.new(path)

    fileset.links = :follow
    fileset.recurse = true

    fileset.files.sort.should == %w{. mylink}.sort
  end

  context "when merging other filesets" do
    before do
      @paths = [make_absolute("/first/path"), make_absolute("/second/path"), make_absolute("/third/path")]
      stub_file = stub(:lstat => stub('stat', :directory? => false))
      Puppet::FileSystem::File.stubs(:new).returns stub_file

      @filesets = @paths.collect do |path|
        stub_dir = stub(path, :lstat => stub('stat', :directory? => true))
        Puppet::FileSystem::File.stubs(:new).with(path).returns stub_dir
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

