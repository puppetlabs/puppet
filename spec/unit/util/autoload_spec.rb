require 'spec_helper'

require 'puppet/util/autoload'

describe Puppet::Util::Autoload do
  include PuppetSpec::Files

  before do
    @autoload = Puppet::Util::Autoload.new("foo", "tmp")

    @loaded = {}
    allow(@autoload.class).to receive(:loaded).and_return(@loaded)
  end

  describe "when building the search path" do
    before :each do
      ## modulepath/libdir can't be used until after app settings are initialized, so we need to simulate that:
      expect(Puppet.settings).to receive(:app_defaults_initialized?).and_return(true).at_least(:once)
    end

    it "should collect all of the lib directories that exist in the current environment's module path" do
      dira = dir_containing('dir_a', {
        "one" => {},
        "two" => { "lib" => {} }
      })

      dirb = dir_containing('dir_a', {
        "one" => {},
        "two" => { "lib" => {} }
      })

      environment = Puppet::Node::Environment.create(:foo, [dira, dirb])

      expect(@autoload.class.module_directories(environment)).to eq(["#{dira}/two/lib", "#{dirb}/two/lib"])
    end

    it "ignores missing module directories" do
      environment = Puppet::Node::Environment.create(:foo, [File.expand_path('does/not/exist')])

      expect(@autoload.class.module_directories(environment)).to be_empty
    end

    it "ignores the configured environment when it doesn't exist" do
      Puppet[:environment] = 'nonexistent'

      Puppet.override({ :environments => Puppet::Environments::Static.new() }) do
        expect(@autoload.class.module_directories(nil)).to be_empty
      end
    end

    it "uses the configured environment when no environment is given" do
      Puppet[:environment] = 'nonexistent'

      Puppet.override({ :environments => Puppet::Environments::Static.new() }) do
        expect(@autoload.class.module_directories(nil)).to be_empty
      end
    end

    it "should include the module directories, the Puppet libdir, and all of the Ruby load directories" do
      Puppet[:libdir] = '/libdir1'
      expect(@autoload.class).to receive(:gem_directories).and_return(%w{/one /two})
      expect(@autoload.class).to receive(:module_directories).and_return(%w{/three /four})
      expect(@autoload.class.search_directories(nil)).to eq(%w{/one /two /three /four} + [Puppet[:libdir]] + $LOAD_PATH)
    end

    it "does not split the Puppet[:libdir]" do
      Puppet[:libdir] = "/libdir1#{File::PATH_SEPARATOR}/libdir2"

      expect(@autoload.class.libdirs).to eq([Puppet[:libdir]])
    end
  end

  describe "when loading a file" do
    before do
      allow(@autoload.class).to receive(:search_directories).and_return([make_absolute("/a")])
      allow(FileTest).to receive(:directory?).and_return(true)
      @time_a = Time.utc(2010, 'jan', 1, 6, 30)
      allow(File).to receive(:mtime).and_return(@time_a)
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die with Puppet::Error if a #{error.to_s} exception is thrown" do
        allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

        expect(Kernel).to receive(:load).and_raise(error)

        expect { @autoload.load("foo") }.to raise_error(Puppet::Error)
      end
    end

    it "should not raise an error if the file is missing" do
      expect(@autoload.load("foo")).to eq(false)
    end

    it "should register loaded files with the autoloader" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile")

      expect(@autoload.class.loaded?("tmp/myfile.rb")).to be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should be seen by loaded? on the instance using the short name" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile")

      expect(@autoload.loaded?("myfile.rb")).to be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should register loaded files with the main loaded file list so they are not reloaded by ruby" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)

      @autoload.load("myfile")

      expect($LOADED_FEATURES).to be_include("tmp/myfile.rb")

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should load the first file in the searchpath" do
      allow(@autoload).to receive(:search_directories).and_return([make_absolute("/a"), make_absolute("/b")])
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      expect(Kernel).to receive(:load).with(make_absolute("/a/tmp/myfile.rb"), any_args)

      @autoload.load("myfile")

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should treat equivalent paths to a loaded file as loaded" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile")

      expect(@autoload.class.loaded?("tmp/myfile")).to be
      expect(@autoload.class.loaded?("tmp/./myfile.rb")).to be
      expect(@autoload.class.loaded?("./tmp/myfile.rb")).to be
      expect(@autoload.class.loaded?("tmp/../tmp/myfile.rb")).to be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end
  end

  describe "when loading all files" do
    before do
      allow(@autoload.class).to receive(:search_directories).and_return([make_absolute("/a")])
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(Dir).to receive(:glob).and_return([make_absolute("/a/foo/file.rb")])
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      @time_a = Time.utc(2010, 'jan', 1, 6, 30)
      allow(File).to receive(:mtime).and_return(@time_a)

      allow(@autoload.class).to receive(:loaded?).and_return(false)
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die an if a #{error.to_s} exception is thrown" do
        expect(Kernel).to receive(:load).and_raise(error)

        expect { @autoload.loadall }.to raise_error(Puppet::Error)
      end
    end

    it "should require the full path to the file" do
      expect(Kernel).to receive(:load).with(make_absolute("/a/foo/file.rb"), any_args)

      @autoload.loadall
    end
  end

  describe "when reloading files" do
    before :each do
      @file_a = make_absolute("/a/file.rb")
      @file_b = make_absolute("/b/file.rb")
      @first_time = Time.utc(2010, 'jan', 1, 6, 30)
      @second_time = @first_time + 60
    end

    after :each do
      $LOADED_FEATURES.delete("a/file.rb")
      $LOADED_FEATURES.delete("b/file.rb")
    end

    it "#changed? should return true for a file that was not loaded" do
      expect(@autoload.class.changed?(@file_a)).to be
    end

    it "changes should be seen by changed? on the instance using the short name" do
      allow(File).to receive(:mtime).and_return(@first_time)
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile")
      expect(@autoload.loaded?("myfile")).to be
      expect(@autoload.changed?("myfile")).not_to be

      allow(File).to receive(:mtime).and_return(@second_time)
      expect(@autoload.changed?("myfile")).to be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    describe "in one directory" do
      before :each do
        allow(@autoload.class).to receive(:search_directories).and_return([make_absolute("/a")])
        expect(File).to receive(:mtime).with(@file_a).and_return(@first_time)
        @autoload.class.mark_loaded("file", @file_a)
      end

      it "should reload if mtime changes" do
        allow(File).to receive(:mtime).with(@file_a).and_return(@first_time + 60)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_a).and_return(true)
        expect(Kernel).to receive(:load).with(@file_a, any_args)
        @autoload.class.reload_changed
      end

      it "should do nothing if the file is deleted" do
        allow(File).to receive(:mtime).with(@file_a).and_raise(Errno::ENOENT)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_a).and_return(false)
        expect(Kernel).not_to receive(:load)
        @autoload.class.reload_changed
      end
    end

    describe "in two directories" do
      before :each do
        allow(@autoload.class).to receive(:search_directories).and_return([make_absolute("/a"), make_absolute("/b")])
      end

      it "should load b/file when a/file is deleted" do
        expect(File).to receive(:mtime).with(@file_a).and_return(@first_time)
        @autoload.class.mark_loaded("file", @file_a)
        allow(File).to receive(:mtime).with(@file_a).and_raise(Errno::ENOENT)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_a).and_return(false)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_b).and_return(true)
        allow(File).to receive(:mtime).with(@file_b).and_return(@first_time)
        expect(Kernel).to receive(:load).with(@file_b, any_args)
        @autoload.class.reload_changed
        expect(@autoload.class.send(:loaded)["file"]).to eq([@file_b, @first_time])
      end

      it "should load a/file when b/file is loaded and a/file is created" do
        allow(File).to receive(:mtime).with(@file_b).and_return(@first_time)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_b).and_return(true)
        @autoload.class.mark_loaded("file", @file_b)

        allow(File).to receive(:mtime).with(@file_a).and_return(@first_time)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_a).and_return(true)
        expect(Kernel).to receive(:load).with(@file_a, any_args)
        @autoload.class.reload_changed
        expect(@autoload.class.send(:loaded)["file"]).to eq([@file_a, @first_time])
      end
    end
  end

  describe "#cleanpath" do
    it "should leave relative paths relative" do
      path = "hello/there"
      expect(Puppet::Util::Autoload.cleanpath(path)).to eq(path)
    end

    describe "on Windows", :if => Puppet.features.microsoft_windows? do
      it "should convert c:\ to c:/" do
        expect(Puppet::Util::Autoload.cleanpath('c:\\')).to eq('c:/')
      end
    end
  end

  describe "#expand" do
    it "should expand relative to the autoloader's prefix" do
      expect(@autoload.expand('bar')).to eq('tmp/bar')
    end
  end
end
