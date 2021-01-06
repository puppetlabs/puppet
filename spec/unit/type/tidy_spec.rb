require 'spec_helper'
require 'puppet/file_bucket/dipper'

tidy = Puppet::Type.type(:tidy)

describe tidy do
  include PuppetSpec::Files

  before do
    @basepath = make_absolute("/what/ever")
    allow(Puppet.settings).to receive(:use)
  end

  context "when normalizing 'path' on windows", :if => Puppet::Util::Platform.windows? do
    it "replaces backslashes with forward slashes" do
      resource = tidy.new(:path => 'c:\directory')
      expect(resource[:path]).to eq('c:/directory')
    end
  end

  it "should use :lstat when stating a file" do
    path = '/foo/bar'
    stat = double('stat')
    expect(Puppet::FileSystem).to receive(:lstat).with(path).and_return(stat)

    resource = tidy.new :path => path, :age => "1d"

    expect(resource.stat(path)).to eq(stat)
  end

  [:age, :size, :path, :matches, :type, :recurse, :rmdirs].each do |param|
    it "should have a #{param} parameter" do
      expect(Puppet::Type.type(:tidy).attrclass(param).ancestors).to be_include(Puppet::Parameter)
    end

    it "should have documentation for its #{param} param" do
      expect(Puppet::Type.type(:tidy).attrclass(param).doc).to be_instance_of(String)
    end
  end

  describe "when validating parameter values" do
    describe "for 'recurse'" do
      before do
        @tidy = Puppet::Type.type(:tidy).new :path => "/tmp", :age => "100d"
      end

      it "should allow 'true'" do
        expect { @tidy[:recurse] = true }.not_to raise_error
      end

      it "should allow 'false'" do
        expect { @tidy[:recurse] = false }.not_to raise_error
      end

      it "should allow integers" do
        expect { @tidy[:recurse] = 10 }.not_to raise_error
      end

      it "should allow string representations of integers" do
        expect { @tidy[:recurse] = "10" }.not_to raise_error
      end

      it "should allow 'inf'" do
        expect { @tidy[:recurse] = "inf" }.not_to raise_error
      end

      it "should not allow arbitrary values" do
        expect { @tidy[:recurse] = "whatever" }.to raise_error(Puppet::ResourceError, /Parameter recurse failed/)
      end
    end

    describe "for 'matches'" do
      before do
        @tidy = Puppet::Type.type(:tidy).new :path => "/tmp", :age => "100d"
      end

      it "should object if matches is given with recurse is not specified" do
        expect { @tidy[:matches] = '*.doh' }.to raise_error(Puppet::ResourceError, /Parameter matches failed/)
      end
      it "should object if matches is given and recurse is 0" do
        expect { @tidy[:recurse] = 0; @tidy[:matches] = '*.doh' }.to raise_error(Puppet::ResourceError, /Parameter matches failed/)
      end
      it "should object if matches is given and recurse is false" do
        expect { @tidy[:recurse] = false; @tidy[:matches] = '*.doh' }.to raise_error(Puppet::ResourceError, /Parameter matches failed/)
      end
      it "should not object if matches is given and recurse is > 0" do
        expect { @tidy[:recurse] = 1; @tidy[:matches] = '*.doh' }.not_to raise_error
      end
      it "should not object if matches is given and recurse is true" do
        expect { @tidy[:recurse] = true; @tidy[:matches] = '*.doh' }.not_to raise_error
      end
    end
  end

  describe "when matching files by age" do
    convertors = {
      :second => 1,
      :minute => 60
    }

    convertors[:hour] = convertors[:minute] * 60
    convertors[:day] = convertors[:hour] * 24
    convertors[:week] = convertors[:day] * 7

    convertors.each do |unit, multiple|
      it "should consider a #{unit} to be #{multiple} seconds" do
        @tidy = Puppet::Type.type(:tidy).new :path => @basepath, :age => "5#{unit.to_s[0..0]}"

        expect(@tidy[:age]).to eq(5 * multiple)
      end
    end
  end

  describe "when matching files by size" do
    convertors = {
      :b => 0,
      :kb => 1,
      :mb => 2,
      :gb => 3,
      :tb => 4
    }

    convertors.each do |unit, multiple|
      it "should consider a #{unit} to be 1024^#{multiple} bytes" do
        @tidy = Puppet::Type.type(:tidy).new :path => @basepath, :size => "5#{unit}"

        total = 5
        multiple.times { total *= 1024 }
        expect(@tidy[:size]).to eq(total)
      end
    end
  end

  describe "when tidying" do
    before do
      @tidy = Puppet::Type.type(:tidy).new :path => @basepath
      @stat = double('stat', :ftype => "directory")
      lstat_is(@basepath, @stat)
    end

    describe "and generating files" do
      it "should set the backup on the file if backup is set on the tidy instance" do
        @tidy[:backup] = "whatever"
        expect(Puppet::Type.type(:file)).to receive(:new).with(hash_including(backup: "whatever"))

        @tidy.mkfile(@basepath)
      end

      it "should set the file's path to the tidy's path" do
        expect(Puppet::Type.type(:file)).to receive(:new).with(hash_including(path: @basepath))

        @tidy.mkfile(@basepath)
      end

      it "should configure the file for deletion" do
        expect(Puppet::Type.type(:file)).to receive(:new).with(hash_including(ensure: :absent))

        @tidy.mkfile(@basepath)
      end

      it "should force deletion on the file" do
        expect(Puppet::Type.type(:file)).to receive(:new).with(hash_including(force: true))

        @tidy.mkfile(@basepath)
      end

      it "should do nothing if the targeted file does not exist" do
        lstat_raises(@basepath, Errno::ENOENT)

        expect(@tidy.generate).to eq([])
      end
    end

    describe "and recursion is not used" do
      it "should generate a file resource if the file should be tidied" do
        expect(@tidy).to receive(:tidy?).with(@basepath).and_return(true)
        file = Puppet::Type.type(:file).new(:path => @basepath+"/eh")
        expect(@tidy).to receive(:mkfile).with(@basepath).and_return(file)

        expect(@tidy.generate).to eq([file])
      end

      it "should do nothing if the file should not be tidied" do
        expect(@tidy).to receive(:tidy?).with(@basepath).and_return(false)
        expect(@tidy).not_to receive(:mkfile)

        expect(@tidy.generate).to eq([])
      end
    end

    describe "and recursion is used" do
      before do
        @tidy[:recurse] = true
        @fileset = Puppet::FileServing::Fileset.new(@basepath)
        allow(Puppet::FileServing::Fileset).to receive(:new).and_return(@fileset)
      end

      it "should use a Fileset for infinite recursion" do
        expect(Puppet::FileServing::Fileset).to receive(:new).with(@basepath, :recurse => true).and_return(@fileset)
        expect(@fileset).to receive(:files).and_return(%w{. one two})
        allow(@tidy).to receive(:tidy?).and_return(false)

        @tidy.generate
      end

      it "should use a Fileset for limited recursion" do
        @tidy[:recurse] = 42
        expect(Puppet::FileServing::Fileset).to receive(:new).with(@basepath, :recurse => true, :recurselimit => 42).and_return(@fileset)
        expect(@fileset).to receive(:files).and_return(%w{. one two})
        allow(@tidy).to receive(:tidy?).and_return(false)

        @tidy.generate
      end

      it "should generate a file resource for every file that should be tidied but not for files that should not be tidied" do
        expect(@fileset).to receive(:files).and_return(%w{. one two})

        expect(@tidy).to receive(:tidy?).with(@basepath).and_return(true)
        expect(@tidy).to receive(:tidy?).with(@basepath+"/one").and_return(true)
        expect(@tidy).to receive(:tidy?).with(@basepath+"/two").and_return(false)

        file = Puppet::Type.type(:file).new(:path => @basepath+"/eh")
        expect(@tidy).to receive(:mkfile).with(@basepath).and_return(file)
        expect(@tidy).to receive(:mkfile).with(@basepath+"/one").and_return(file)

        @tidy.generate
      end
    end

    describe "and determining whether a file matches provided glob patterns" do
      before do
        @tidy = Puppet::Type.type(:tidy).new :path => @basepath, :recurse => 1
        @tidy[:matches] = %w{*foo* *bar*}

        @stat = double('stat')

        @matcher = @tidy.parameter(:matches)
      end

      it "should always convert the globs to an array" do
        @matcher.value = "*foo*"
        expect(@matcher.value).to eq(%w{*foo*})
      end

      it "should return true if any pattern matches the last part of the file" do
        @matcher.value = %w{*foo* *bar*}
        expect(@matcher).to be_tidy("/file/yaybarness", @stat)
      end

      it "should return false if no pattern matches the last part of the file" do
        @matcher.value = %w{*foo* *bar*}
        expect(@matcher).not_to be_tidy("/file/yayness", @stat)
      end
    end

    describe "and determining whether a file is too old" do
      before do
        @tidy = Puppet::Type.type(:tidy).new :path => @basepath
        @stat = double('stat')

        @tidy[:age] = "1s"
        @tidy[:type] = "mtime"
        @ager = @tidy.parameter(:age)
      end

      it "should use the age type specified" do
        @tidy[:type] = :ctime
        expect(@stat).to receive(:ctime).and_return(Time.now)

        @ager.tidy?(@basepath, @stat)
      end

      it "should return false if the file is more recent than the specified age" do
        expect(@stat).to receive(:mtime).and_return(Time.now)

        expect(@ager).not_to be_tidy(@basepath, @stat)
      end

      it "should return true if the file is older than the specified age" do
        expect(@stat).to receive(:mtime).and_return(Time.now - 10)

        expect(@ager).to be_tidy(@basepath, @stat)
      end
    end

    describe "and determining whether a file is too large" do
      before do
        @tidy = Puppet::Type.type(:tidy).new :path => @basepath
        @stat = double('stat', :ftype => "file")

        @tidy[:size] = "1kb"
        @sizer = @tidy.parameter(:size)
      end

      it "should return false if the file is smaller than the specified size" do
        expect(@stat).to receive(:size).and_return(4) # smaller than a kilobyte

        expect(@sizer).not_to be_tidy(@basepath, @stat)
      end

      it "should return true if the file is larger than the specified size" do
        expect(@stat).to receive(:size).and_return(1500) # larger than a kilobyte

        expect(@sizer).to be_tidy(@basepath, @stat)
      end

      it "should return true if the file is equal to the specified size" do
        expect(@stat).to receive(:size).and_return(1024)

        expect(@sizer).to be_tidy(@basepath, @stat)
      end
    end

    describe "and determining whether a file should be tidied" do
      before do
        @tidy = Puppet::Type.type(:tidy).new :path => @basepath
        @catalog = Puppet::Resource::Catalog.new
        @tidy.catalog = @catalog
        @stat = double('stat', :ftype => "file")
        lstat_is(@basepath, @stat)
      end

      it "should not try to recurse if the file does not exist" do
        @tidy[:recurse] = true

        lstat_is(@basepath, nil)

        expect(@tidy.generate).to eq([])
      end

      it "should not be tidied if the file does not exist" do
        lstat_raises(@basepath, Errno::ENOENT)

        expect(@tidy).not_to be_tidy(@basepath)
      end

      it "should not be tidied if the user has no access to the file" do
        lstat_raises(@basepath, Errno::EACCES)

        expect(@tidy).not_to be_tidy(@basepath)
      end

      it "should not be tidied if it is a directory and rmdirs is set to false" do
        stat = double('stat', :ftype => "directory")
        lstat_is(@basepath, stat)

        expect(@tidy).not_to be_tidy(@basepath)
      end

      it "should return false if it does not match any provided globs" do
        @tidy[:recurse] = 1
        @tidy[:matches] = "globs"

        matches = @tidy.parameter(:matches)
        expect(matches).to receive(:tidy?).with(@basepath, @stat).and_return(false)
        expect(@tidy).not_to be_tidy(@basepath)
      end

      it "should return false if it does not match aging requirements" do
        @tidy[:age] = "1d"

        ager = @tidy.parameter(:age)
        expect(ager).to receive(:tidy?).with(@basepath, @stat).and_return(false)
        expect(@tidy).not_to be_tidy(@basepath)
      end

      it "should return false if it does not match size requirements" do
        @tidy[:size] = "1b"

        sizer = @tidy.parameter(:size)
        expect(sizer).to receive(:tidy?).with(@basepath, @stat).and_return(false)
        expect(@tidy).not_to be_tidy(@basepath)
      end

      it "should tidy a file if age and size are set but only size matches" do
        @tidy[:size] = "1b"
        @tidy[:age] = "1d"

        allow(@tidy.parameter(:size)).to receive(:tidy?).and_return(true)
        allow(@tidy.parameter(:age)).to receive(:tidy?).and_return(false)
        expect(@tidy).to be_tidy(@basepath)
      end

      it "should tidy a file if age and size are set but only age matches" do
        @tidy[:size] = "1b"
        @tidy[:age] = "1d"

        allow(@tidy.parameter(:size)).to receive(:tidy?).and_return(false)
        allow(@tidy.parameter(:age)).to receive(:tidy?).and_return(true)
        expect(@tidy).to be_tidy(@basepath)
      end

      it "should tidy all files if neither age nor size is set" do
        expect(@tidy).to be_tidy(@basepath)
      end

      it "should sort the results inversely by path length, so files are added to the catalog before their directories" do
        @tidy[:recurse] = true
        @tidy[:rmdirs] = true
        fileset = Puppet::FileServing::Fileset.new(@basepath)
        expect(Puppet::FileServing::Fileset).to receive(:new).and_return(fileset)
        expect(fileset).to receive(:files).and_return(%w{. one one/two})

        allow(@tidy).to receive(:tidy?).and_return(true)

        expect(@tidy.generate.collect { |r| r[:path] }).to eq([@basepath+"/one/two", @basepath+"/one", @basepath])
      end
    end

    it "should configure directories to require their contained files if rmdirs is enabled, so the files will be deleted first" do
      @tidy[:recurse] = true
      @tidy[:rmdirs] = true
      fileset = double('fileset')
      expect(Puppet::FileServing::Fileset).to receive(:new).with(@basepath, :recurse => true).and_return(fileset)
      expect(fileset).to receive(:files).and_return(%w{. one two one/subone two/subtwo one/subone/ssone})
      allow(@tidy).to receive(:tidy?).and_return(true)

      result = @tidy.generate.inject({}) { |hash, res| hash[res[:path]] = res; hash }
      {
        @basepath => [ @basepath+"/one", @basepath+"/two" ],
        @basepath+"/one" => [@basepath+"/one/subone"],
        @basepath+"/two" => [@basepath+"/two/subtwo"],
        @basepath+"/one/subone" => [@basepath+"/one/subone/ssone"]
      }.each do |parent, children|
        children.each do |child|
          ref = Puppet::Resource.new(:file, child)
          expect(result[parent][:require].find { |req| req.to_s == ref.to_s }).not_to be_nil
        end
      end
    end

    it "should configure directories to require their contained files in sorted order" do
      @tidy[:recurse] = true
      @tidy[:rmdirs] = true
      fileset = double('fileset')
      expect(Puppet::FileServing::Fileset).to receive(:new).with(@basepath, :recurse => true).and_return(fileset)
      expect(fileset).to receive(:files).and_return(%w{. a a/2 a/1 a/3})
      allow(@tidy).to receive(:tidy?).and_return(true)

      result = @tidy.generate.inject({}) { |hash, res| hash[res[:path]] = res; hash }
      expect(result[@basepath + '/a'][:require].collect{|a| a.name[('File//a/' + @basepath).length..-1]}.join()).to eq('321')
    end

    it "generates resources whose noop parameter matches the managed resource's noop parameter" do
      @tidy[:recurse] = true
      @tidy[:noop] = true

      fileset = double('fileset')
      expect(Puppet::FileServing::Fileset).to receive(:new).with(@basepath, :recurse => true).and_return(fileset)
      expect(fileset).to receive(:files).and_return(%w{. a a/2 a/1 a/3})
      allow(@tidy).to receive(:tidy?).and_return(true)

      result = @tidy.generate.inject({}) { |hash, res| hash[res[:path]] = res; hash }

      expect(result.values).to all(be_noop)
    end
  end

  def lstat_is(path, stat)
    allow(Puppet::FileSystem).to receive(:lstat).with(path).and_return(stat)
  end

  def lstat_raises(path, error_class)
    expect(Puppet::FileSystem).to receive(:lstat).with(path).and_raise(Errno::ENOENT)
  end
end
