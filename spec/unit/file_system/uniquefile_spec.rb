require 'spec_helper'

describe Puppet::FileSystem::Uniquefile do
  it "makes the name of the file available" do
    Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      expect(file.path).to match(/foo/)
    end
  end

  it "provides a writeable file" do
    Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      file.write("stuff")
      file.flush

      expect(Puppet::FileSystem.read(file.path)).to eq("stuff")
    end
  end

  it "returns the value of the block" do
    the_value = Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      "my value"
    end

    expect(the_value).to eq("my value")
  end

  it "unlinks the temporary file" do
    filename = Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      file.path
    end

    expect(Puppet::FileSystem.exist?(filename)).to be_falsey
  end

  it "unlinks the temporary file even if the block raises an error" do
    filename = nil

    begin
      Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
        filename = file.path
        raise "error!"
      end
    rescue
    end

    expect(Puppet::FileSystem.exist?(filename)).to be_falsey
  end

  it "propagates lock creation failures" do
    # use an arbitrary exception so as not accidentally collide
    # with the ENOENT that occurs when trying to call rmdir
    Puppet::FileSystem::Uniquefile.stubs(:mkdir).raises 'arbitrary failure'
    Puppet::FileSystem::Uniquefile.expects(:rmdir).never

    expect {
      Puppet::FileSystem::Uniquefile.open_tmp('foo') { |tmp| }
    }.to raise_error('arbitrary failure')
  end

  it "only removes lock files that exist" do
    # prevent the .lock directory from being created
    Puppet::FileSystem::Uniquefile.stubs(:mkdir) { }

    # and expect cleanup to be skipped
    Puppet::FileSystem::Uniquefile.expects(:rmdir).never

    Puppet::FileSystem::Uniquefile.open_tmp('foo') { |tmp| }
  end

  context "Ruby 1.9.3 Tempfile tests" do
    # the remaining tests in this file are ported directly from the ruby 1.9.3 source,
    # since most of this file was ported from there
    # see: https://github.com/ruby/ruby/blob/v1_9_3_547/test/test_tempfile.rb

    def tempfile(*args, &block)
      t = Puppet::FileSystem::Uniquefile.new(*args, &block)
      @tempfile = (t unless block)
    end

    after(:each) do
      if @tempfile
        @tempfile.close!
      end
    end

    it "creates tempfiles" do
      t = tempfile("foo")
      path = t.path
      t.write("hello world")
      t.close
      expect(File.read(path)).to eq("hello world")
    end

    it "saves in tmpdir by default" do
      t = tempfile("foo")
      expect(Dir.tmpdir).to eq(File.dirname(t.path))
    end

    it "saves in given directory" do
      subdir = File.join(Dir.tmpdir, "tempfile-test-#{rand}")
      Dir.mkdir(subdir)
      begin
        tempfile = Tempfile.new("foo", subdir)
        tempfile.close
        begin
          expect(subdir).to eq(File.dirname(tempfile.path))
        ensure
          tempfile.unlink
        end
      ensure
        Dir.rmdir(subdir)
      end
    end

    it "supports basename" do
      t = tempfile("foo")
      expect(File.basename(t.path)).to match(/^foo/)
    end

    it "supports basename with suffix" do
      t = tempfile(["foo", ".txt"])
      expect(File.basename(t.path)).to match(/^foo/)
      expect(File.basename(t.path)).to match(/\.txt$/)
    end

    it "supports unlink" do
      t = tempfile("foo")
      path = t.path
      t.close
      expect(File.exist?(path)).to eq(true)
      t.unlink
      expect(File.exist?(path)).to eq(false)
      expect(t.path).to eq(nil)
    end

    it "supports closing" do
      t = tempfile("foo")
      expect(t.closed?).to eq(false)
      t.close
      expect(t.closed?).to eq(true)
    end

    it "supports closing and unlinking via boolean argument" do
      t = tempfile("foo")
      path = t.path
      t.close(true)
      expect(t.closed?).to eq(true)
      expect(t.path).to eq(nil)
      expect(File.exist?(path)).to eq(false)
    end

    context "on unix platforms", :unless => Puppet.features.microsoft_windows? do
      it "close doesn't unlink if already unlinked" do
        t = tempfile("foo")
        path = t.path
        t.unlink
        File.open(path, "w").close
        begin
          t.close(true)
          expect(File.exist?(path)).to eq(true)
        ensure
          File.unlink(path) rescue nil
        end
      end
    end

    it "supports close!" do
      t = tempfile("foo")
      path = t.path
      t.close!
      expect(t.closed?).to eq(true)
      expect(t.path).to eq(nil)
      expect(File.exist?(path)).to eq(false)
    end

    context "on unix platforms", :unless => Puppet.features.microsoft_windows? do
      it "close! doesn't unlink if already unlinked" do
        t = tempfile("foo")
        path = t.path
        t.unlink
        File.open(path, "w").close
        begin
          t.close!
          expect(File.exist?(path)).to eq(true)
        ensure
          File.unlink(path) rescue nil
        end
      end
    end

    it "close does not make path nil" do
      t = tempfile("foo")
      t.close
      expect(t.path.nil?).to eq(false)
    end

    it "close flushes buffer" do
      t = tempfile("foo")
      t.write("hello")
      t.close
      expect(File.size(t.path)).to eq(5)
    end
  end
end
