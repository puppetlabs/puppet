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
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      fileset = Puppet::FileServing::Fileset.new(path_with_separator)
      expect(fileset.path).to eq(somefile)
    end

    it "can be created from the root directory" do
      path = File.expand_path(File::SEPARATOR)
      expect(Puppet::FileSystem).to receive(:lstat).with(path).and_return(double('stat'))
      fileset = Puppet::FileServing::Fileset.new(path)
      expect(fileset.path).to eq(path)
    end

    it "fails if its path does not exist" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_raise(Errno::ENOENT)
      expect { Puppet::FileServing::Fileset.new(somefile) }.to raise_error(ArgumentError, "Fileset paths must exist")
    end

    it "accepts a 'recurse' option" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      set = Puppet::FileServing::Fileset.new(somefile, :recurse => true)
      expect(set.recurse).to be_truthy
    end

    it "accepts a 'recurselimit' option" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      set = Puppet::FileServing::Fileset.new(somefile, :recurselimit => 3)
      expect(set.recurselimit).to eq(3)
    end

    it "accepts a 'max_files' option" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      set = Puppet::FileServing::Fileset.new(somefile, :recurselimit => 3, :max_files => 100)
      expect(set.recurselimit).to eq(3)
      expect(set.max_files).to eq(100)
    end

    it "accepts an 'ignore' option" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      set = Puppet::FileServing::Fileset.new(somefile, :ignore => ".svn")
      expect(set.ignore).to eq([".svn"])
    end

    it "accepts a 'links' option" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      set = Puppet::FileServing::Fileset.new(somefile, :links => :manage)
      expect(set.links).to eq(:manage)
    end

    it "accepts a 'checksum_type' option" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      set = Puppet::FileServing::Fileset.new(somefile, :checksum_type => :test)
      expect(set.checksum_type).to eq(:test)
    end

    it "fails if 'links' is set to anything other than :manage or :follow" do
      expect { Puppet::FileServing::Fileset.new(somefile, :links => :whatever) }.to raise_error(ArgumentError, "Invalid :links value 'whatever'")
    end

    it "defaults to 'false' for recurse" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      expect(Puppet::FileServing::Fileset.new(somefile).recurse).to eq(false)
    end

    it "defaults to :infinite for recurselimit" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      expect(Puppet::FileServing::Fileset.new(somefile).recurselimit).to eq(:infinite)
    end

    it "defaults to an empty ignore list" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      expect(Puppet::FileServing::Fileset.new(somefile).ignore).to eq([])
    end

    it "defaults to :manage for links" do
      expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      expect(Puppet::FileServing::Fileset.new(somefile).links).to eq(:manage)
    end

    describe "using an indirector request" do
      let(:values) { { :links => :manage, :ignore => %w{a b}, :recurse => true, :recurselimit => 1234 } }

      before :each do
        expect(Puppet::FileSystem).to receive(:lstat).with(somefile).and_return(double('stat'))
      end

      [:recurse, :recurselimit, :ignore, :links].each do |option|
        it "passes the #{option} option on to the fileset if present" do
          request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil, {option => values[option]})

          expect(Puppet::FileServing::Fileset.new(somefile, request).send(option)).to eq(values[option])
        end
      end

      it "converts the integer as a string to their integer counterpart when setting options" do
        request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil,
                                                  {:recurselimit => "1234"})

        expect(Puppet::FileServing::Fileset.new(somefile, request).recurselimit).to eq(1234)
      end

      it "converts the string 'true' to the boolean true when setting options" do
        request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil,
                                                  {:recurse => "true"})

        expect(Puppet::FileServing::Fileset.new(somefile, request).recurse).to eq(true)
      end

      it "converts the string 'false' to the boolean false when setting options" do
        request = Puppet::Indirector::Request.new(:file_serving, :find, "foo", nil,
                                                  {:recurse => "false"})

        expect(Puppet::FileServing::Fileset.new(somefile, request).recurse).to eq(false)
      end
    end
  end

  context "when recursing" do
    before do
      @path = make_absolute("/my/path")
      allow(Puppet::FileSystem).to receive(:lstat).with(@path).and_return(double('stat', :directory? => true))

      @fileset = Puppet::FileServing::Fileset.new(@path)

      @dirstat = double('dirstat', :directory? => true)
      @filestat = double('filestat', :directory? => false)
    end

    def mock_dir_structure(path, stat_method = :lstat)
      allow(Puppet::FileSystem).to receive(stat_method).with(path).and_return(@dirstat)

      # Keep track of the files we're stubbing.
      @files = %w{.}

      top_names = %w{one two .svn CVS}
      sub_names = %w{file1 file2 .svn CVS 0 false}

      allow(Dir).to receive(:entries).with(path, encoding: Encoding::UTF_8).and_return(top_names)
      top_names.each do |subdir|
        @files << subdir # relative path
        subpath = File.join(path, subdir)
        allow(Puppet::FileSystem).to receive(stat_method).with(subpath).and_return(@dirstat)
        allow(Dir).to receive(:entries).with(subpath, encoding: Encoding::UTF_8).and_return(sub_names)
        sub_names.each do |file|
          @files << File.join(subdir, file) # relative path
          subfile_path = File.join(subpath, file)
          allow(Puppet::FileSystem).to receive(stat_method).with(subfile_path).and_return(@filestat)
        end
      end
    end

    def mock_big_dir_structure(path, stat_method = :lstat)
      allow(Puppet::FileSystem).to receive(stat_method).with(path).and_return(@dirstat)

      # Keep track of the files we're stubbing.
      @files = %w{.}

      top_names = (1..10).map {|i| "dir_#{i}" }
      sub_names = (1..100).map {|i| "file__#{i}" }

      allow(Dir).to receive(:entries).with(path, encoding: Encoding::UTF_8).and_return(top_names)
      top_names.each do |subdir|
        @files << subdir # relative path
        subpath = File.join(path, subdir)
        allow(Puppet::FileSystem).to receive(stat_method).with(subpath).and_return(@dirstat)
        allow(Dir).to receive(:entries).with(subpath, encoding: Encoding::UTF_8).and_return(sub_names)
        sub_names.each do |file|
          @files << File.join(subdir, file) # relative path
          subfile_path = File.join(subpath, file)
          allow(Puppet::FileSystem).to receive(stat_method).with(subfile_path).and_return(@filestat)
        end
      end
    end

    def setup_mocks_for_dir(mock_dir, base_path)
      path = File.join(base_path, mock_dir.name)
      allow(Puppet::FileSystem).to receive(:lstat).with(path).and_return(MockStat.new(path, true))
      allow(Dir).to receive(:entries).with(path, encoding: Encoding::UTF_8).and_return(['.', '..'] + mock_dir.entries.map(&:name))
      mock_dir.entries.each do |entry|
        setup_mocks_for_entry(entry, path)
      end
    end

    def setup_mocks_for_file(mock_file, base_path)
      path = File.join(base_path, mock_file.name)
      allow(Puppet::FileSystem).to receive(:lstat).with(path).and_return(MockStat.new(path, false))
    end

    def setup_mocks_for_entry(entry, base_path)
      case entry
      when MockDirectory
        setup_mocks_for_dir(entry, base_path)
      when MockFile
        setup_mocks_for_file(entry, base_path)
      end
    end

    MockStat = Struct.new(:path, :directory) do
      # struct doesn't support thing ending in ?
      def directory?
        directory
      end
    end

    MockDirectory = Struct.new(:name, :entries)
    MockFile = Struct.new(:name)

    it "doesn't ignore pending directories when the last entry at the top level is a file" do
      structure = MockDirectory.new('path',
                    [MockDirectory.new('dir1',
                                   [MockDirectory.new('a', [MockFile.new('f')])]),
                     MockFile.new('file')])
      setup_mocks_for_dir(structure, make_absolute('/your'))
      fileset = Puppet::FileServing::Fileset.new(make_absolute('/your/path'))
      fileset.recurse = true
      fileset.links = :manage
      expect(fileset.files).to eq([".", "dir1", "file", "dir1/a", "dir1/a/f"])
    end

    it "recurses through the whole file tree if :recurse is set to 'true'" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      expect(@fileset.files.sort).to eq(@files.sort)
    end

    it "does not recurse if :recurse is set to 'false'" do
      mock_dir_structure(@path)
      @fileset.recurse = false
      expect(@fileset.files).to eq(%w{.})
    end

    it "recurses to the level set by :recurselimit" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.recurselimit = 1
      expect(@fileset.files).to eq(%w{. one two .svn CVS})
    end

    it "ignores the '.' and '..' directories in subdirectories" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      expect(@fileset.files.sort).to eq(@files.sort)
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
      expect(@fileset.files.find { |file| file.include?(".svn") }).to be_nil
    end

    it "ignores files that match any of multiple patterns in the ignore list" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = %w{.svn CVS}
      expect(@fileset.files.find { |file| file.include?(".svn") or file.include?("CVS") }).to be_nil
    end

    it "ignores files that match a pattern given as a number" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = [0]
      expect(@fileset.files.find { |file| file.include?("0") }).to be_nil
    end

    it "raises exception if number of files is greater than :max_files" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.max_files = 22
      expect { @fileset.files }.to raise_error(Puppet::Error, "The directory '#{@path}' contains 28 entries, which exceeds the limit of 22 specified by the max_files parameter for this resource. The limit may be increased, but be aware that large number of file resources can result in excessive resource consumption and degraded performance. Consider using an alternate method to manage large directory trees")
    end

    it "logs a warning if number of files is greater than soft max_files limit of 1000" do
      mock_big_dir_structure(@path)
      @fileset.recurse = true
      expect(Puppet).to receive(:warning).with("The directory '#{@path}' contains 1010 entries, which exceeds the default soft limit 1000 and may cause excessive resource consumption and degraded performance. To remove this warning set a value for `max_files` parameter or consider using an alternate method to manage large directory trees")
      expect { @fileset.files }.to_not raise_error
    end

    it "ignores files that match a pattern given as a boolean" do
      mock_dir_structure(@path)
      @fileset.recurse = true
      @fileset.ignore = [false]
      expect(@fileset.files.find { |file| file.include?("false") }).to be_nil
    end

    it "uses Puppet::FileSystem#stat if :links is set to :follow" do
      mock_dir_structure(@path, :stat)
      @fileset.recurse = true
      @fileset.links = :follow
      expect(@fileset.files.sort).to eq(@files.sort)
    end

    it "uses Puppet::FileSystem#lstat if :links is set to :manage" do
      mock_dir_structure(@path, :lstat)
      @fileset.recurse = true
      @fileset.links = :manage
      expect(@fileset.files.sort).to eq(@files.sort)
    end

    it "works when paths have regexp significant characters" do
      @path = make_absolute("/my/path/rV1x2DafFr0R6tGG+1bbk++++TM")
      stat = double('dir_stat', :directory? => true)
      expect(Puppet::FileSystem).to receive(:lstat).with(@path).and_return(double(@path, :stat => stat, :lstat => stat))
      @fileset = Puppet::FileServing::Fileset.new(@path)
      mock_dir_structure(@path)
      @fileset.recurse = true
      expect(@fileset.files.sort).to eq(@files.sort)
    end
  end

  it "manages the links to missing files" do
    path = make_absolute("/my/path")
    stat = double('stat', :directory? => true)

    expect(Puppet::FileSystem).to receive(:stat).with(path).and_return(stat)
    expect(Puppet::FileSystem).to receive(:lstat).with(path).and_return(stat)

    link_path = File.join(path, "mylink")
    expect(Puppet::FileSystem).to receive(:stat).with(link_path).and_raise(Errno::ENOENT)

    allow(Dir).to receive(:entries).with(path, encoding: Encoding::UTF_8).and_return(["mylink"])

    fileset = Puppet::FileServing::Fileset.new(path)

    fileset.links = :follow
    fileset.recurse = true

    expect(fileset.files.sort).to eq(%w{. mylink}.sort)
  end

  context "when merging other filesets" do
    before do
      @paths = [make_absolute("/first/path"), make_absolute("/second/path"), make_absolute("/third/path")]
      allow(Puppet::FileSystem).to receive(:lstat).and_return(double('stat', :directory? => false))

      @filesets = @paths.collect do |path|
        allow(Puppet::FileSystem).to receive(:lstat).with(path).and_return(double('stat', :directory? => true))
        Puppet::FileServing::Fileset.new(path, :recurse => true)
      end

      allow(Dir).to receive(:entries).and_return([])
    end

    it "returns a hash of all files in each fileset with the value being the base path" do
      expect(Dir).to receive(:entries).with(make_absolute("/first/path"), encoding: Encoding::UTF_8).and_return(%w{one uno})
      expect(Dir).to receive(:entries).with(make_absolute("/second/path"), encoding: Encoding::UTF_8).and_return(%w{two dos})
      expect(Dir).to receive(:entries).with(make_absolute("/third/path"), encoding: Encoding::UTF_8).and_return(%w{three tres})

      expect(Puppet::FileServing::Fileset.merge(*@filesets)).to eq({
        "." => make_absolute("/first/path"),
        "one" => make_absolute("/first/path"),
        "uno" => make_absolute("/first/path"),
        "two" => make_absolute("/second/path"),
        "dos" => make_absolute("/second/path"),
        "three" => make_absolute("/third/path"),
        "tres" => make_absolute("/third/path"),
      })
    end

    it "includes the base directory from the first fileset" do
      expect(Dir).to receive(:entries).with(make_absolute("/first/path"), encoding: Encoding::UTF_8).and_return(%w{one})
      expect(Dir).to receive(:entries).with(make_absolute("/second/path"), encoding: Encoding::UTF_8).and_return(%w{two})

      expect(Puppet::FileServing::Fileset.merge(*@filesets)["."]).to eq(make_absolute("/first/path"))
    end

    it "uses the base path of the first found file when relative file paths conflict" do
      expect(Dir).to receive(:entries).with(make_absolute("/first/path"), encoding: Encoding::UTF_8).and_return(%w{one})
      expect(Dir).to receive(:entries).with(make_absolute("/second/path"), encoding: Encoding::UTF_8).and_return(%w{one})

      expect(Puppet::FileServing::Fileset.merge(*@filesets)["one"]).to eq(make_absolute("/first/path"))
    end
  end
end

