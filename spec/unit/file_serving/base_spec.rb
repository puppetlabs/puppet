require 'spec_helper'

require 'puppet/file_serving/base'

describe Puppet::FileServing::Base do
  let(:path) { File.expand_path('/module/dir/file') }
  let(:file) { File.expand_path('/my/file') }

  it "should accept a path" do
    expect(Puppet::FileServing::Base.new(path).path).to eq(path)
  end

  it "should require that paths be fully qualified" do
    expect { Puppet::FileServing::Base.new("module/dir/file") }.to raise_error(ArgumentError)
  end

  it "should allow specification of whether links should be managed" do
    expect(Puppet::FileServing::Base.new(path, :links => :manage).links).to eq(:manage)
  end

  it "should have a :source attribute" do
    file = Puppet::FileServing::Base.new(path)
    expect(file).to respond_to(:source)
    expect(file).to respond_to(:source=)
  end

  it "should consider :ignore links equivalent to :manage links" do
    expect(Puppet::FileServing::Base.new(path, :links => :ignore).links).to eq(:manage)
  end

  it "should fail if :links is set to anything other than :manage, :follow, or :ignore" do
    expect { Puppet::FileServing::Base.new(path, :links => :else) }.to raise_error(ArgumentError)
  end

  it "should allow links values to be set as strings" do
    expect(Puppet::FileServing::Base.new(path, :links => "follow").links).to eq(:follow)
  end

  it "should default to :manage for :links" do
    expect(Puppet::FileServing::Base.new(path).links).to eq(:manage)
  end

  it "should allow specification of a relative path" do
    allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
    expect(Puppet::FileServing::Base.new(path, :relative_path => "my/file").relative_path).to eq("my/file")
  end

  it "should have a means of determining if the file exists" do
    expect(Puppet::FileServing::Base.new(file)).to respond_to(:exist?)
  end

  it "should correctly indicate if the file is present" do
    expect(Puppet::FileSystem).to receive(:lstat).with(file).and_return(double('stat'))
    expect(Puppet::FileServing::Base.new(file).exist?).to be_truthy
  end

  it "should correctly indicate if the file is absent" do
    expect(Puppet::FileSystem).to receive(:lstat).with(file).and_raise(RuntimeError)
    expect(Puppet::FileServing::Base.new(file).exist?).to be_falsey
  end

  describe "when setting the relative path" do
    it "should require that the relative path be unqualified" do
      @file = Puppet::FileServing::Base.new(path)
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      expect { @file.relative_path = File.expand_path("/qualified/file") }.to raise_error(ArgumentError)
    end
  end

  describe "when determining the full file path" do
    let(:path) { File.expand_path('/this/file') }
    let(:file) { Puppet::FileServing::Base.new(path) }

    it "should return the path if there is no relative path" do
      expect(file.full_path).to eq(path)
    end

    it "should return the path if the relative_path is set to ''" do
      file.relative_path = ""
      expect(file.full_path).to eq(path)
    end

    it "should return the path if the relative_path is set to '.'" do
      file.relative_path = "."
      expect(file.full_path).to eq(path)
    end

    it "should return the path joined with the relative path if there is a relative path and it is not set to '/' or ''" do
      file.relative_path = "not/qualified"
      expect(file.full_path).to eq(File.join(path, "not/qualified"))
    end

    it "should strip extra slashes" do
      file = Puppet::FileServing::Base.new(File.join(File.expand_path('/'), "//this//file"))
      expect(file.full_path).to eq(path)
    end
  end

  describe "when handling a UNC file path on Windows" do
    let(:path) { '//server/share/filename' }
    let(:file) { Puppet::FileServing::Base.new(path) }

    before :each do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
    end

    it "should preserve double slashes at the beginning of the path" do
      expect(file.full_path).to eq(path)
    end

    it "should strip double slashes not at the beginning of the path" do
      file = Puppet::FileServing::Base.new('//server//share//filename')
      expect(file.full_path).to eq(path)
    end
  end


  describe "when stat'ing files" do
    let(:path) { File.expand_path('/this/file') }
    let(:file) { Puppet::FileServing::Base.new(path) }
    let(:stat) { double('stat', :ftype => 'file' ) }
    let(:stubbed_file) { double(path, :stat => stat, :lstat => stat)}

    it "should stat the file's full path" do
      expect(Puppet::FileSystem).to receive(:lstat).with(path).and_return(stat)
      file.stat
    end

    it "should fail if the file does not exist" do
      expect(Puppet::FileSystem).to receive(:lstat).with(path).and_raise(Errno::ENOENT)
      expect { file.stat }.to raise_error(Errno::ENOENT)
    end

    it "should use :lstat if :links is set to :manage" do
      expect(Puppet::FileSystem).to receive(:lstat).with(path).and_return(stubbed_file)
      file.stat
    end

    it "should use :stat if :links is set to :follow" do
      expect(Puppet::FileSystem).to receive(:stat).with(path).and_return(stubbed_file)
      file.links = :follow
      file.stat
    end
  end

  describe "#absolute?" do
    it "should be accept POSIX paths" do
      expect(Puppet::FileServing::Base).to be_absolute('/')
    end

    it "should accept Windows paths on Windows" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
      allow(Puppet.features).to receive(:posix?).and_return(false)

      expect(Puppet::FileServing::Base).to be_absolute('c:/foo')
    end

    it "should reject Windows paths on POSIX" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)

      expect(Puppet::FileServing::Base).not_to be_absolute('c:/foo')
    end
  end
end
