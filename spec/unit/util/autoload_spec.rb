require 'spec_helper'
require 'fileutils'

require 'puppet/util/autoload'

describe Puppet::Util::Autoload do
  include PuppetSpec::Files

  let(:env) { Puppet::Node::Environment.create(:foo, []) }

  before do
    @autoload = Puppet::Util::Autoload.new("foo", "tmp")

    @loaded = {}
    allow(@autoload.class).to receive(:loaded).and_return(@loaded)
  end

  describe "when building the search path" do
    before :each do
      ## modulepath/libdir can't be used until after app settings are initialized, so we need to simulate that:
      allow(Puppet.settings).to receive(:app_defaults_initialized?).and_return(true)
    end

    def with_libdir(libdir)
      begin
        old_loadpath = $LOAD_PATH.dup
        old_libdir = Puppet[:libdir]
        Puppet[:libdir] = libdir
        $LOAD_PATH.unshift(libdir)
        yield
      ensure
        Puppet[:libdir] = old_libdir
        $LOAD_PATH.clear
        $LOAD_PATH.concat(old_loadpath)
      end
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

      env = Puppet::Node::Environment.create(:dev, [])
      Puppet.override(environments: Puppet::Environments::Static.new(env)) do
        expect(@autoload.class.module_directories(Puppet.lookup(:current_environment))).to be_empty
      end
    end

    it "raises when no environment is given" do
      Puppet[:environment] = 'nonexistent'

      Puppet.override(environments: Puppet::Environments::Static.new) do
        expect {
          @autoload.class.module_directories(nil)
        }.to raise_error(ArgumentError, /Autoloader requires an environment/)
      end
    end

    it "should include the module directories, the Puppet libdir, Ruby load directories, and vendored modules" do
      vendor_dir = tmpdir('vendor_modules')
      module_libdir = File.join(vendor_dir, 'amodule_core', 'lib')
      FileUtils.mkdir_p(module_libdir)

      libdir = File.expand_path('/libdir1')
      Puppet[:vendormoduledir] = vendor_dir
      Puppet.initialize_settings

      with_libdir(libdir) do
        expect(@autoload.class).to receive(:gem_directories).and_return(%w{/one /two})
        expect(@autoload.class).to receive(:module_directories).and_return(%w{/three /four})
        dirs = @autoload.class.search_directories(nil)
        expect(dirs[0..4]).to eq(%w{/one /two /three /four} + [libdir])
        expect(dirs.last).to eq(module_libdir)
      end
    end

    it "does not split the Puppet[:libdir]" do
      dir = File.expand_path("/libdir1#{File::PATH_SEPARATOR}/libdir2")
      with_libdir(dir) do
        expect(@autoload.class).to receive(:gem_directories).and_return(%w{/one /two})
        expect(@autoload.class).to receive(:module_directories).and_return(%w{/three /four})
        dirs = @autoload.class.search_directories(nil)
        expect(dirs).to include(dir)
      end
    end
  end

  describe "when loading a file" do
    before do
      allow(@autoload.class).to receive(:search_directories).and_return([make_absolute("/a")])
      allow(FileTest).to receive(:directory?).and_return(true)
      @time_a = Time.utc(2010, 'jan', 1, 6, 30)
      allow(File).to receive(:mtime).and_return(@time_a)
    end

    after(:each) do
      $LOADED_FEATURES.delete("/a/tmp/myfile.rb")
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die with Puppet::Error if a #{error.to_s} exception is thrown" do
        allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

        expect(Kernel).to receive(:load).and_raise(error)

        expect { @autoload.load("foo", env) }.to raise_error(Puppet::Error)
      end
    end

    it "should not raise an error if the file is missing" do
      expect(@autoload.load("foo", env)).to eq(false)
    end

    it "should register loaded files with the autoloader" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile", env)

      expect(@autoload.class.loaded?("tmp/myfile.rb")).to be
    end

    it "should be seen by loaded? on the instance using the short name" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile", env)

      expect(@autoload.loaded?("myfile.rb")).to be
    end

    it "should register loaded files with the main loaded file list so they are not reloaded by ruby" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)

      @autoload.load("myfile", env)

      expect($LOADED_FEATURES).to be_include(make_absolute("/a/tmp/myfile.rb"))
    end

    it "should load the first file in the searchpath" do
      allow(@autoload.class).to receive(:search_directories).and_return([make_absolute("/a"), make_absolute("/b")])
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      expect(Kernel).to receive(:load).with(make_absolute("/a/tmp/myfile.rb"), any_args)

      @autoload.load("myfile", env)
    end

    it "should treat equivalent paths to a loaded file as loaded" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile", env)

      expect(@autoload.class.loaded?("tmp/myfile")).to be
      expect(@autoload.class.loaded?("tmp/./myfile.rb")).to be
      expect(@autoload.class.loaded?("./tmp/myfile.rb")).to be
      expect(@autoload.class.loaded?("tmp/../tmp/myfile.rb")).to be
    end
  end

  describe "when loading all files" do
    let(:basedir) { tmpdir('autoloader') }
    let(:path) { File.join(basedir, @autoload.path, 'file.rb') }

    before do
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)

      allow(@autoload.class).to receive(:search_directories).and_return([basedir])
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die an if a #{error.to_s} exception is thrown" do
        expect(Kernel).to receive(:load).and_raise(error)

        expect { @autoload.loadall(env) }.to raise_error(Puppet::Error)
      end
    end

    it "should require the full path to the file" do
      expect(Kernel).to receive(:load).with(path, any_args)

      @autoload.loadall(env)
    end

    it "autoloads from a directory whose ancestor is Windows 8.3", if: Puppet::Util::Platform.windows? do
      pending("GH runners seem to have disabled 8.3 support")

      # File.expand_path will expand ~ in the last directory component only(!)
      # so create an ancestor directory with a long path
      dir = File.join(tmpdir('longpath'), 'short')
      path = File.join(dir, @autoload.path, 'file.rb')

      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)

      dir83 = File.join(File.dirname(basedir), 'longpa~1', 'short')
      path83 = File.join(dir83, @autoload.path, 'file.rb')

      allow(@autoload.class).to receive(:search_directories).and_return([dir83])
      expect(Kernel).to receive(:load).with(path83, any_args)

      @autoload.loadall(env)
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
      expect(@autoload.class.changed?(@file_a, env)).to be
    end

    it "changes should be seen by changed? on the instance using the short name" do
      allow(File).to receive(:mtime).and_return(@first_time)
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Kernel).to receive(:load)
      @autoload.load("myfile", env)
      expect(@autoload.loaded?("myfile")).to be
      expect(@autoload.changed?("myfile", env)).not_to be

      allow(File).to receive(:mtime).and_return(@second_time)
      expect(@autoload.changed?("myfile", env)).to be

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
        @autoload.class.reload_changed(env)
      end

      it "should do nothing if the file is deleted" do
        allow(File).to receive(:mtime).with(@file_a).and_raise(Errno::ENOENT)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_a).and_return(false)
        expect(Kernel).not_to receive(:load)
        @autoload.class.reload_changed(env)
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
        @autoload.class.reload_changed(env)
        expect(@autoload.class.send(:loaded)["file"]).to eq([@file_b, @first_time])
      end

      it "should load a/file when b/file is loaded and a/file is created" do
        allow(File).to receive(:mtime).with(@file_b).and_return(@first_time)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_b).and_return(true)
        @autoload.class.mark_loaded("file", @file_b)

        allow(File).to receive(:mtime).with(@file_a).and_return(@first_time)
        allow(Puppet::FileSystem).to receive(:exist?).with(@file_a).and_return(true)
        expect(Kernel).to receive(:load).with(@file_a, any_args)
        @autoload.class.reload_changed(env)
        expect(@autoload.class.send(:loaded)["file"]).to eq([@file_a, @first_time])
      end
    end
  end

  describe "#cleanpath" do
    it "should leave relative paths relative" do
      path = "hello/there"
      expect(Puppet::Util::Autoload.cleanpath(path)).to eq(path)
    end

    describe "on Windows", :if => Puppet::Util::Platform.windows? do
      it "should convert c:\ to c:/" do
        expect(Puppet::Util::Autoload.cleanpath('c:\\')).to eq('c:/')
      end

      it "should convert all backslashes to forward slashes" do
        expect(Puppet::Util::Autoload.cleanpath('c:\projects\ruby\bug\test.rb')).to eq('c:/projects/ruby/bug/test.rb')
      end
    end
  end

  describe "#expand" do
    it "should expand relative to the autoloader's prefix" do
      expect(@autoload.expand('bar')).to eq('tmp/bar')
    end
  end
end
