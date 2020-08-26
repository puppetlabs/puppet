require 'spec_helper'

require 'puppet/util/backups'

describe Puppet::Util::Backups do
  include PuppetSpec::Files

  let(:bucket) { double('bucket', :name => "foo") }
  let!(:file) do
    f = Puppet::Type.type(:file).new(:name => path, :backup => 'foo')
    allow(f).to receive(:bucket).and_return(bucket)
    f
  end

  describe "when backing up a file" do
    let(:path) { make_absolute('/no/such/file') }

    it "should noop if the file does not exist" do
      expect(file).not_to receive(:bucket)
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(false)

      file.perform_backup
    end

    it "should succeed silently if self[:backup] is false" do
      file = Puppet::Type.type(:file).new(:name => path, :backup => false)

      expect(file).not_to receive(:bucket)
      expect(Puppet::FileSystem).not_to receive(:exist?)

      file.perform_backup
    end

    it "a bucket should be used when provided" do
      lstat_path_as(path, 'file')
      expect(bucket).to receive(:backup).with(path).and_return("mysum")
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)

      file.perform_backup
    end

    it "should propagate any exceptions encountered when backing up to a filebucket" do
      lstat_path_as(path, 'file')
      expect(bucket).to receive(:backup).and_raise(ArgumentError)
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)

      expect { file.perform_backup }.to raise_error(ArgumentError)
    end

    describe "and local backup is configured" do
      let(:ext) { 'foobkp' }
      let(:backup) { path + '.' + ext }
      let(:file) { Puppet::Type.type(:file).new(:name => path, :backup => '.'+ext) }

      it "should remove any local backup if one exists" do
        lstat_path_as(backup, 'file')
        expect(Puppet::FileSystem).to receive(:unlink).with(backup)
        allow(FileUtils).to receive(:cp_r)
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)

        file.perform_backup
      end

      it "should fail when the old backup can't be removed" do
        lstat_path_as(backup, 'file')
        expect(Puppet::FileSystem).to receive(:unlink).with(backup).and_raise(ArgumentError)
        expect(FileUtils).not_to receive(:cp_r)
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)

        expect { file.perform_backup }.to raise_error(Puppet::Error)
      end

      it "should not try to remove backups that don't exist" do
        expect(Puppet::FileSystem).to receive(:lstat).with(backup).and_raise(Errno::ENOENT)
        expect(Puppet::FileSystem).not_to receive(:unlink).with(backup)
        allow(FileUtils).to receive(:cp_r)
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)

        file.perform_backup
      end

      it "a copy should be created in the local directory" do
        expect(FileUtils).to receive(:cp_r).with(path, backup, :preserve => true)
        allow(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)

        expect(file.perform_backup).to be_truthy
      end

      it "should propagate exceptions if no backup can be created" do
        expect(FileUtils).to receive(:cp_r).and_raise(ArgumentError)

        allow(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
        expect { file.perform_backup }.to raise_error(Puppet::Error)
      end
    end
  end

  describe "when backing up a directory" do
    let(:path) { make_absolute('/my/dir') }
    let(:filename) { File.join(path, 'file') }

    it "a bucket should work when provided" do
      allow(File).to receive(:file?).with(filename).and_return(true)
      expect(Find).to receive(:find).with(path).and_yield(filename)

      expect(bucket).to receive(:backup).with(filename).and_return(true)

      lstat_path_as(path, 'directory')

      allow(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
      allow(Puppet::FileSystem).to receive(:exist?).with(filename).and_return(true)

      file.perform_backup
    end

    it "should do nothing when recursing" do
      file = Puppet::Type.type(:file).new(:name => path, :backup => 'foo', :recurse => true)

      expect(bucket).not_to receive(:backup)
      stub_file = double('file', :stat => double('stat', :ftype => 'directory'))
      allow(Puppet::FileSystem).to receive(:new).with(path).and_return(stub_file)
      expect(Find).not_to receive(:find)

      file.perform_backup
    end
  end

  def lstat_path_as(path, ftype)
    expect(Puppet::FileSystem).to receive(:lstat).with(path).and_return(double('File::Stat', :ftype => ftype))
  end
end
