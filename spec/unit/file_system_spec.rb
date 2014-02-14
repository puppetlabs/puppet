require 'spec_helper'
require 'puppet/file_system'
require 'puppet/util/platform'

describe "Puppet::FileSystem" do
  include PuppetSpec::Files

  context "#exclusive_open" do
    it "opens ands allows updating of an existing file" do
      file = file_containing("file_to_update", "the contents")

      Puppet::FileSystem.exclusive_open(file, 0660, 'r+') do |fh|
        old = fh.read
        fh.truncate(0)
        fh.rewind
        fh.write("updated #{old}")
      end

      expect(Puppet::FileSystem.read(file)).to eq("updated the contents")
    end

    it "opens, creates ands allows updating of a new file" do
      file = tmpfile("file_to_update")

      Puppet::FileSystem.exclusive_open(file, 0660, 'w') do |fh|
        fh.write("updated new file")
      end

      expect(Puppet::FileSystem.read(file)).to eq("updated new file")
    end

    it "excludes other processes from updating at the same time", :unless => Puppet::Util::Platform.windows? do
      file = file_containing("file_to_update", "0")

      increment_counter_in_multiple_processes(file, 5, 'r+')

      expect(Puppet::FileSystem.read(file)).to eq("5")
    end

    it "excludes other processes from updating at the same time even when creating the file", :unless => Puppet::Util::Platform.windows? do
      file = tmpfile("file_to_update")

      increment_counter_in_multiple_processes(file, 5, 'a+')

      expect(Puppet::FileSystem.read(file)).to eq("5")
    end

    it "times out if the lock cannot be aquired in a specified amount of time", :unless => Puppet::Util::Platform.windows? do
      file = tmpfile("file_to_update")

      child = spawn_process_that_locks(file)

      expect do
        Puppet::FileSystem.exclusive_open(file, 0666, 'a', 0.1) do |f|
        end
      end.to raise_error(Timeout::Error)

      Process.kill(9, child)
    end

    def spawn_process_that_locks(file)
      read, write = IO.pipe

      child = Kernel.fork do
        read.close
        Puppet::FileSystem.exclusive_open(file, 0666, 'a') do |fh|
          write.write(true)
          write.close
          sleep 10
        end
      end

      write.close
      read.read
      read.close

      child
    end

    def increment_counter_in_multiple_processes(file, num_procs, options)
      children = []
      num_procs.times do
        children << Kernel.fork do
          Puppet::FileSystem.exclusive_open(file, 0660, options) do |fh|
            fh.rewind
            contents = (fh.read || 0).to_i
            fh.truncate(0)
            fh.rewind
            fh.write((contents + 1).to_s)
          end
          exit(0)
        end
      end

      children.each { |pid| Process.wait(pid) }
    end
  end

  describe "symlink",
    :if => ! Puppet.features.manages_symlinks? &&
    Puppet.features.microsoft_windows? do

    let(:file)         { tmpfile("somefile") }
    let(:missing_file) { tmpfile("missingfile") }
    let(:expected_msg) { "This version of Windows does not support symlinks.  Windows Vista / 2008 or higher is required." }

    before :each do
      FileUtils.touch(file)
    end

    it "should raise an error when trying to create a symlink" do
      expect { Puppet::FileSystem.symlink(file, 'foo') }.to raise_error(Puppet::Util::Windows::Error)
    end

    it "should return false when trying to check if a path is a symlink" do
      Puppet::FileSystem.symlink?(file).should be_false
    end

    it "should raise an error when trying to read a symlink" do
      expect { Puppet::FileSystem.readlink(file) }.to raise_error(Puppet::Util::Windows::Error)
    end

    it "should return a File::Stat instance when calling stat on an existing file" do
      Puppet::FileSystem.stat(file).should be_instance_of(File::Stat)
    end

    it "should raise Errno::ENOENT when calling stat on a missing file" do
      expect { Puppet::FileSystem.stat(missing_file) }.to raise_error(Errno::ENOENT)
    end

    it "should fall back to stat when trying to lstat a file" do
      Puppet::Util::Windows::File.expects(:stat).with(Puppet::FileSystem.assert_path(file))

      Puppet::FileSystem.lstat(file)
    end
  end

  describe "symlink", :if => Puppet.features.manages_symlinks? do

    let(:file)          { tmpfile("somefile") }
    let(:missing_file)  { tmpfile("missingfile") }
    let(:dir)           { tmpdir("somedir") }

    before :each do
      FileUtils.touch(file)
    end

    it "should return true for exist? on a present file" do
      Puppet::FileSystem.exist?(file).should be_true
    end

    it "should return true for file? on a present file" do
      Puppet::FileSystem.file?(file).should be_true
    end

    it "should return false for exist? on a non-existant file" do
      Puppet::FileSystem.exist?(missing_file).should be_false
    end

    it "should return true for exist? on a present directory" do
      Puppet::FileSystem.exist?(dir).should be_true
    end

    it "should return false for exist? on a dangling symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      Puppet::FileSystem.exist?(missing_file).should be_false
      Puppet::FileSystem.exist?(symlink).should be_false
    end

    it "should return true for exist? on valid symlinks" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target).to_s}_link")
        Puppet::FileSystem.symlink(target, symlink)

        Puppet::FileSystem.exist?(target).should be_true
        Puppet::FileSystem.exist?(symlink).should be_true
      end
    end

    it "should not create a symlink when the :noop option is specified" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target)}_link")
        Puppet::FileSystem.symlink(target, symlink, { :noop => true })

        Puppet::FileSystem.exist?(target).should be_true
        Puppet::FileSystem.exist?(symlink).should be_false
      end
    end

    it "should raise Errno::EEXIST if trying to create a file / directory symlink when the symlink path already exists as a file" do
      existing_file = tmpfile("#{Puppet::FileSystem.basename(file)}_link")
      FileUtils.touch(existing_file)

      [file, dir].each do |target|
        expect { Puppet::FileSystem.symlink(target, existing_file) }.to raise_error(Errno::EEXIST)

        Puppet::FileSystem.exist?(existing_file).should be_true
        Puppet::FileSystem.symlink?(existing_file).should be_false
      end
    end

    it "should silently fail if trying to create a file / directory symlink when the symlink path already exists as a directory" do
      existing_dir = tmpdir("#{Puppet::FileSystem.basename(file)}_dir")

      [file, dir].each do |target|
        Puppet::FileSystem.symlink(target, existing_dir).should == 0

        Puppet::FileSystem.exist?(existing_dir).should be_true
        File.directory?(existing_dir).should be_true
        Puppet::FileSystem.symlink?(existing_dir).should be_false
      end
    end

    it "should silently fail to modify an existing directory symlink to reference a new file or directory" do
      [file, dir].each do |target|
        existing_dir = tmpdir("#{Puppet::FileSystem.basename(target)}_dir")
        symlink = tmpfile("#{Puppet::FileSystem.basename(existing_dir)}_link")
        Puppet::FileSystem.symlink(existing_dir, symlink)

        Puppet::FileSystem.readlink(symlink).should == Puppet::FileSystem.path_string(existing_dir)

        # now try to point it at the new target, no error raised, but file system unchanged
        Puppet::FileSystem.symlink(target, symlink).should == 0
        Puppet::FileSystem.readlink(symlink).should == existing_dir.to_s
      end
    end

    it "should raise Errno::EEXIST if trying to modify a file symlink to reference a new file or directory" do
      symlink = tmpfile("#{Puppet::FileSystem.basename(file)}_link")
      file_2 = tmpfile("#{Puppet::FileSystem.basename(file)}_2")
      FileUtils.touch(file_2)
      # symlink -> file_2
      Puppet::FileSystem.symlink(file_2, symlink)

      [file, dir].each do |target|
        expect { Puppet::FileSystem.symlink(target, symlink) }.to raise_error(Errno::EEXIST)
        Puppet::FileSystem.readlink(symlink).should == file_2.to_s
      end
    end

    it "should delete the existing file when creating a file / directory symlink with :force when the symlink path exists as a file" do
      [file, dir].each do |target|
        existing_file = tmpfile("#{Puppet::FileSystem.basename(target)}_existing")
        FileUtils.touch(existing_file)
        Puppet::FileSystem.symlink?(existing_file).should be_false

        Puppet::FileSystem.symlink(target, existing_file, { :force => true })

        Puppet::FileSystem.symlink?(existing_file).should be_true
        Puppet::FileSystem.readlink(existing_file).should == target.to_s
      end
    end

    it "should modify an existing file symlink when using :force to reference a new file or directory" do
      [file, dir].each do |target|
        existing_file = tmpfile("#{Puppet::FileSystem.basename(target)}_existing")
        FileUtils.touch(existing_file)
        existing_symlink = tmpfile("#{Puppet::FileSystem.basename(existing_file)}_link")
        Puppet::FileSystem.symlink(existing_file, existing_symlink)

        Puppet::FileSystem.readlink(existing_symlink).should == existing_file.to_s

        Puppet::FileSystem.symlink(target, existing_symlink, { :force => true })

        Puppet::FileSystem.readlink(existing_symlink).should == target.to_s
      end
    end

    it "should silently fail if trying to overwrite an existing directory with a new symlink when using :force to reference a file or directory" do
      [file, dir].each do |target|
        existing_dir = tmpdir("#{Puppet::FileSystem.basename(target)}_existing")

        Puppet::FileSystem.symlink(target, existing_dir, { :force => true }).should == 0

        Puppet::FileSystem.symlink?(existing_dir).should be_false
      end
    end

    it "should silently fail if trying to modify an existing directory symlink when using :force to reference a new file or directory" do
      [file, dir].each do |target|
        existing_dir = tmpdir("#{Puppet::FileSystem.basename(target)}_existing")
        existing_symlink = tmpfile("#{Puppet::FileSystem.basename(existing_dir)}_link")
        Puppet::FileSystem.symlink(existing_dir, existing_symlink)

        Puppet::FileSystem.readlink(existing_symlink).should == existing_dir.to_s

        Puppet::FileSystem.symlink(target, existing_symlink, { :force => true }).should == 0

        Puppet::FileSystem.readlink(existing_symlink).should == existing_dir.to_s
      end
    end

    it "should accept a string, Pathname or object with to_str (Puppet::Util::WatchedFile) for exist?" do
      [ tmpfile('bogus1'),
        Pathname.new(tmpfile('bogus2')),
        Puppet::Util::WatchedFile.new(tmpfile('bogus3'))
        ].each { |f| Puppet::FileSystem.exist?(f).should be_false  }
    end

    it "should return a File::Stat instance when calling stat on an existing file" do
      Puppet::FileSystem.stat(file).should be_instance_of(File::Stat)
    end

    it "should raise Errno::ENOENT when calling stat on a missing file" do
      expect { Puppet::FileSystem.stat(missing_file) }.to raise_error(Errno::ENOENT)
    end

    it "should be able to create a symlink, and verify it with symlink?" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      Puppet::FileSystem.symlink?(symlink).should be_true
    end

    it "should report symlink? as false on file, directory and missing files" do
      [file, dir, missing_file].each do |f|
      Puppet::FileSystem.symlink?(f).should be_false
      end
    end

    it "should return a File::Stat with ftype 'link' when calling lstat on a symlink pointing to existing file" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      stat = Puppet::FileSystem.lstat(symlink)
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'link'
    end

    it "should return a File::Stat of ftype 'link' when calling lstat on a symlink pointing to missing file" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      stat = Puppet::FileSystem.lstat(symlink)
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'link'
    end

    it "should return a File::Stat of ftype 'file' when calling stat on a symlink pointing to existing file" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      stat = Puppet::FileSystem.stat(symlink)
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'file'
    end

    it "should return a File::Stat of ftype 'directory' when calling stat on a symlink pointing to existing directory" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(dir, symlink)

      stat = Puppet::FileSystem.stat(symlink)
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'directory'

      # on Windows, this won't get cleaned up if still linked
      Puppet::FileSystem.unlink(symlink)
    end

    it "should return a File::Stat of ftype 'file' when calling stat on a symlink pointing to another symlink" do
      # point symlink -> file
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      # point symlink2 -> symlink
      symlink2 = tmpfile("somefile_link2")
      Puppet::FileSystem.symlink(symlink, symlink2)

      Puppet::FileSystem.stat(symlink2).ftype.should == 'file'
    end


    it "should raise Errno::ENOENT when calling stat on a dangling symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      expect { Puppet::FileSystem.stat(symlink) }.to raise_error(Errno::ENOENT)
    end

    it "should be able to readlink to resolve the physical path to a symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      Puppet::FileSystem.exist?(file).should be_true
      Puppet::FileSystem.readlink(symlink).should == file.to_s
    end

    it "should not resolve entire symlink chain with readlink on a symlink'd symlink" do
      # point symlink -> file
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      # point symlink2 -> symlink
      symlink2 = tmpfile("somefile_link2")
      Puppet::FileSystem.symlink(symlink, symlink2)

      Puppet::FileSystem.exist?(file).should be_true
      Puppet::FileSystem.readlink(symlink2).should == symlink.to_s
    end

    it "should be able to readlink to resolve the physical path to a dangling symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      Puppet::FileSystem.exist?(missing_file).should be_false
      Puppet::FileSystem.readlink(symlink).should == missing_file.to_s
    end

    it "should delete only the symlink and not the target when calling unlink instance method" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target)}_link")
        Puppet::FileSystem.symlink(target, symlink)

        Puppet::FileSystem.exist?(target).should be_true
        Puppet::FileSystem.readlink(symlink).should == target.to_s

        Puppet::FileSystem.unlink(symlink).should == 1 # count of files

        Puppet::FileSystem.exist?(target).should be_true
        Puppet::FileSystem.exist?(symlink).should be_false
      end
    end

    it "should delete only the symlink and not the target when calling unlink class method" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target)}_link")
        Puppet::FileSystem.symlink(target, symlink)

        Puppet::FileSystem.exist?(target).should be_true
        Puppet::FileSystem.readlink(symlink).should == target.to_s

        Puppet::FileSystem.unlink(symlink).should == 1  # count of files

        Puppet::FileSystem.exist?(target).should be_true
        Puppet::FileSystem.exist?(symlink).should be_false
      end
    end

    describe "unlink" do
      it "should delete files with unlink" do
        Puppet::FileSystem.exist?(file).should be_true

        Puppet::FileSystem.unlink(file).should == 1  # count of files

        Puppet::FileSystem.exist?(file).should be_false
      end

      it "should delete files with unlink class method" do
        Puppet::FileSystem.exist?(file).should be_true

        Puppet::FileSystem.unlink(file).should == 1  # count of files

        Puppet::FileSystem.exist?(file).should be_false
      end

      it "should delete multiple files with unlink class method" do
        paths = (1..3).collect do |i|
          f = tmpfile("somefile_#{i}")
          FileUtils.touch(f)
          Puppet::FileSystem.exist?(f).should be_true
          f.to_s
        end

        Puppet::FileSystem.unlink(*paths).should == 3  # count of files

        paths.each { |p| Puppet::FileSystem.exist?(p).should be_false  }
      end

      it "should raise Errno::EPERM or Errno::EISDIR when trying to delete a directory with the unlink class method" do
        Puppet::FileSystem.exist?(dir).should be_true

        ex = nil
        begin
          Puppet::FileSystem.unlink(dir)
        rescue Exception => e
          ex = e
        end

        [
          Errno::EPERM, # Windows and OSX
          Errno::EISDIR # Linux
        ].should include(ex.class)

        Puppet::FileSystem.exist?(dir).should be_true
      end
    end

    describe "exclusive_create" do
      it "should create a file that doesn't exist" do
        Puppet::FileSystem.exist?(missing_file).should be_false

        Puppet::FileSystem.exclusive_create(missing_file, nil) {}

        Puppet::FileSystem.exist?(missing_file).should be_true
      end

      it "should raise Errno::EEXIST creating a file that does exist" do
        Puppet::FileSystem.exist?(file).should be_true

        expect do
          Puppet::FileSystem.exclusive_create(file, nil) {}
        end.to raise_error(Errno::EEXIST)
      end
    end
  end
end
