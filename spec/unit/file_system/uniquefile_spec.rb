require 'spec_helper'

describe Puppet::FileSystem::Uniquefile do
  include PuppetSpec::Files

  it "makes the name of the file available" do
    Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      expect(file.path).to match(/foo/)
    end
  end

  it "ensures the file has permissions 0600", unless: Puppet::Util::Platform.windows? do
    Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      expect(Puppet::FileSystem.stat(file.path).mode & 07777).to eq(0600)
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
    allow(Puppet::FileSystem::Uniquefile).to receive(:mkdir).and_raise('arbitrary failure')
    expect(Puppet::FileSystem::Uniquefile).not_to receive(:rmdir)

    expect {
      Puppet::FileSystem::Uniquefile.open_tmp('foo') { |tmp| }
    }.to raise_error('arbitrary failure')
  end

  it "only removes lock files that exist" do
    # prevent the .lock directory from being created
    allow(Puppet::FileSystem::Uniquefile).to receive(:mkdir)

    # and expect cleanup to be skipped
    expect(Puppet::FileSystem::Uniquefile).not_to receive(:rmdir)

    Puppet::FileSystem::Uniquefile.open_tmp('foo') { |tmp| }
  end

  it "reports when a parent directory does not exist" do
    dir = tmpdir('uniquefile')
    lock = File.join(dir, 'path', 'to', 'lock')

    expect {
      Puppet::FileSystem::Uniquefile.new('uniquefile', lock)
    }.to raise_error(Errno::ENOENT, %r{No such file or directory - A directory component in .* does not exist or is a dangling symbolic link})
  end

  it "should use UTF8 characters in TMP,TEMP,TMPDIR environment variable", :if => Puppet::Util::Platform.windows? do
    rune_utf8 = "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7"
    temp_rune_utf8 = File.join(Dir.tmpdir, rune_utf8)
    Puppet::FileSystem.mkpath(temp_rune_utf8)

    # Set the temporary environment variables to the UTF8 temp path
    Puppet::Util::Windows::Process.set_environment_variable('TMPDIR', temp_rune_utf8)
    Puppet::Util::Windows::Process.set_environment_variable('TMP', temp_rune_utf8)
    Puppet::Util::Windows::Process.set_environment_variable('TEMP', temp_rune_utf8)

    # Create a unique file
    filename = Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
      File.dirname(file.path)
    end

    expect(filename).to eq(temp_rune_utf8)
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

    context "on unix platforms", :unless => Puppet::Util::Platform.windows? do
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

    context "on unix platforms", :unless => Puppet::Util::Platform.windows? do
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
