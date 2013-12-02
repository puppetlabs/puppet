require 'spec_helper'
require 'puppet/file_system'
require 'puppet/util/platform'

describe Puppet::FileSystem::File do
  include PuppetSpec::Files

  context "#exclusive_open" do
    it "opens ands allows updating of an existing file" do
      file = Puppet::FileSystem::File.new(file_containing("file_to_update", "the contents"))

      file.exclusive_open(0660, 'r+') do |fh|
        old = fh.read
        fh.truncate(0)
        fh.rewind
        fh.write("updated #{old}")
      end

      expect(file.read).to eq("updated the contents")
    end

    it "opens, creates ands allows updating of a new file" do
      file = Puppet::FileSystem::File.new(tmpfile("file_to_update"))

      file.exclusive_open(0660, 'w') do |fh|
        fh.write("updated new file")
      end

      expect(file.read).to eq("updated new file")
    end

    it "excludes other processes from updating at the same time", :unless => Puppet::Util::Platform.windows? do
      file = Puppet::FileSystem::File.new(file_containing("file_to_update", "0"))

      increment_counter_in_multiple_processes(file, 5, 'r+')

      expect(file.read).to eq("5")
    end

    it "excludes other processes from updating at the same time even when creating the file", :unless => Puppet::Util::Platform.windows? do
      file = Puppet::FileSystem::File.new(tmpfile("file_to_update"))

      increment_counter_in_multiple_processes(file, 5, 'a+')

      expect(file.read).to eq("5")
    end

    it "times out if the lock cannot be aquired in a specified amount of time", :unless => Puppet::Util::Platform.windows? do
      file = tmpfile("file_to_update")

      child = spawn_process_that_locks(file)

      expect do
        Puppet::FileSystem::File.new(file).exclusive_open(0666, 'a', 0.1) do |f|
        end
      end.to raise_error(Timeout::Error)

      Process.kill(9, child)
    end

    def spawn_process_that_locks(file)
      read, write = IO.pipe

      child = Kernel.fork do
        read.close
        Puppet::FileSystem::File.new(file).exclusive_open(0666, 'a') do |fh|
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
      5.times do |number|
        children << Kernel.fork do
          file.exclusive_open(0660, options) do |fh|
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

    let (:file) { Puppet::FileSystem::File.new(tmpfile("somefile")) }
    let (:missing_file) { Puppet::FileSystem::File.new(tmpfile("missingfile")) }
    let (:expected_msg) { "This version of Windows does not support symlinks.  Windows Vista / 2008 or higher is required." }

    before :each do
      FileUtils.touch(file.path)
    end

    it "should raise an error when trying to create a symlink" do
      expect { file.symlink('foo') }.to raise_error(Puppet::Util::Windows::Error)
    end

    it "should return false when trying to check if a path is a symlink" do
      file.symlink?.should be_false
    end

    it "should raise an error when trying to read a symlink" do
      expect { file.readlink }.to raise_error(Puppet::Util::Windows::Error)
    end

    it "should return a File::Stat instance when calling stat on an existing file" do
      file.stat.should be_instance_of(File::Stat)
    end

    it "should raise Errno::ENOENT when calling stat on a missing file" do
      expect { missing_file.stat }.to raise_error(Errno::ENOENT)
    end

    it "should fall back to stat when trying to lstat a file" do
      Puppet::Util::Windows::File.expects(:stat).with(file.path)

      file.lstat
    end
  end

  describe "symlink", :if => Puppet.features.manages_symlinks? do

    let (:file) { Puppet::FileSystem::File.new(tmpfile("somefile")) }
    let (:missing_file) { Puppet::FileSystem::File.new(tmpfile("missingfile")) }
    let (:dir) { Puppet::FileSystem::File.new(tmpdir("somedir")) }

    before :each do
      FileUtils.touch(file.path)
    end

    it "should return true for exist? on a present file" do
      file.exist?.should be_true
      Puppet::FileSystem::File.exist?(file.path).should be_true
    end

    it "should return false for exist? on a non-existant file" do
      missing_file.exist?.should be_false
      Puppet::FileSystem::File.exist?(missing_file.path).should be_false
    end

    it "should return true for exist? on a present directory" do
      dir.exist?.should be_true
      Puppet::FileSystem::File.exist?(dir.path).should be_true
    end

    it "should return false for exist? on a dangling symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      missing_file.exist?.should be_false
      symlink.exist?.should be_false
    end

    it "should return true for exist? on valid symlinks" do
      [file, dir].each do |target|
        symlink = Puppet::FileSystem::File.new(tmpfile("#{target.path.basename.to_s}_link"))
        target.symlink(symlink.path)

        target.exist?.should be_true
        symlink.exist?.should be_true
      end
    end

    it "should not create a symlink when the :noop option is specified" do
      [file, dir].each do |target|
        symlink = Puppet::FileSystem::File.new(tmpfile("#{target.path.basename.to_s}_link"))
        target.symlink(symlink.path, { :noop => true })

        target.exist?.should be_true
        symlink.exist?.should be_false
      end
    end

    it "should raise Errno::EEXIST if trying to create a file / directory symlink when the symlink path already exists as a file" do
      existing_file = Puppet::FileSystem::File.new(tmpfile("#{file.path.basename.to_s}_link"))
      FileUtils.touch(existing_file.path)

      [file, dir].each do |target|
        expect { target.symlink(existing_file.path) }.to raise_error(Errno::EEXIST)

        existing_file.exist?.should be_true
        existing_file.symlink?.should be_false
      end
    end

    it "should silently fail if trying to create a file / directory symlink when the symlink path already exists as a directory" do
      existing_dir = Puppet::FileSystem::File.new(tmpdir("#{file.path.basename.to_s}_dir"))

      [file, dir].each do |target|
        target.symlink(existing_dir.path).should == 0

        existing_dir.exist?.should be_true
        File.directory?(existing_dir.path).should be_true
        existing_dir.symlink?.should be_false
      end
    end

    it "should silently fail to modify an existing directory symlink to reference a new file or directory" do
      [file, dir].each do |target|
        existing_dir = Puppet::FileSystem::File.new(tmpdir("#{target.path.basename.to_s}_dir"))
        symlink = Puppet::FileSystem::File.new(tmpfile("#{existing_dir.path.basename.to_s}_link"))
        existing_dir.symlink(symlink.path)

        symlink.readlink.should == existing_dir.path.to_s

        # now try to point it at the new target, no error raised, but file system unchanged
        target.symlink(symlink.path).should == 0
        symlink.readlink.should == existing_dir.path.to_s
      end
    end

    it "should raise Errno::EEXIST if trying to modify a file symlink to reference a new file or directory" do
      symlink = Puppet::FileSystem::File.new(tmpfile("#{file.path.basename.to_s}_link"))
      file_2 = Puppet::FileSystem::File.new(tmpfile("#{file.path.basename.to_s}_2"))
      FileUtils.touch(file_2.path)
      # symlink -> file_2
      file_2.symlink(symlink.path)

      [file, dir].each do |target|
        expect { target.symlink(symlink.path) }.to raise_error(Errno::EEXIST)
        symlink.readlink.should == file_2.path.to_s
      end
    end

    it "should delete the existing file when creating a file / directory symlink with :force when the symlink path exists as a file" do
      [file, dir].each do |target|
        existing_file = Puppet::FileSystem::File.new(tmpfile("#{target.path.basename.to_s}_existing"))
        FileUtils.touch(existing_file.path)
        existing_file.symlink?.should be_false

        target.symlink(existing_file.path, { :force => true })

        existing_file.symlink?.should be_true
        existing_file.readlink.should == target.path.to_s
      end
    end

    it "should modify an existing file symlink when using :force to reference a new file or directory" do
      [file, dir].each do |target|
        existing_file = Puppet::FileSystem::File.new(tmpfile("#{target.path.basename.to_s}_existing"))
        FileUtils.touch(existing_file.path)
        existing_symlink = Puppet::FileSystem::File.new(tmpfile("#{existing_file.path.basename.to_s}_link"))
        existing_file.symlink(existing_symlink.path)

        existing_symlink.readlink.should == existing_file.path.to_s

        target.symlink(existing_symlink.path, { :force => true })

        existing_symlink.readlink.should == target.path.to_s
      end
    end

    it "should silently fail if trying to overwrite an existing directory with a new symlink when using :force to reference a file or directory" do
      [file, dir].each do |target|
        existing_dir = Puppet::FileSystem::File.new(tmpdir("#{target.path.basename.to_s}_existing"))

        target.symlink(existing_dir.path, { :force => true }).should == 0

        existing_dir.symlink?.should be_false
      end
    end

    it "should silently fail if trying to modify an existing directory symlink when using :force to reference a new file or directory" do
      [file, dir].each do |target|
        existing_dir = Puppet::FileSystem::File.new(tmpdir("#{target.path.basename.to_s}_existing"))
        existing_symlink = Puppet::FileSystem::File.new(tmpfile("#{existing_dir.path.basename.to_s}_link"))
        existing_dir.symlink(existing_symlink.path)

        existing_symlink.readlink.should == existing_dir.path.to_s

        target.symlink(existing_symlink.path, { :force => true }).should == 0

        existing_symlink.readlink.should == existing_dir.path.to_s
      end
    end

    it "should accept a string, Pathname or object with to_str (Puppet::Util::WatchedFile) for exist?" do
      [ tmpfile('bogus1'),
        Pathname.new(tmpfile('bogus2')),
        Puppet::Util::WatchedFile.new(tmpfile('bogus3'))
        ].each { |f| Puppet::FileSystem::File.exist?(f).should be_false  }
    end

    it "should return a File::Stat instance when calling stat on an existing file" do
      file.stat.should be_instance_of(File::Stat)
    end

    it "should raise Errno::ENOENT when calling stat on a missing file" do
      expect { missing_file.stat }.to raise_error(Errno::ENOENT)
    end

    it "should be able to create a symlink, and verify it with symlink?" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      symlink.symlink?.should be_true
    end

    it "should report symlink? as false on file, directory and missing files" do
      [file, dir, missing_file].each do |f|
        f.symlink?.should be_false
      end
    end

    it "should return a File::Stat with ftype 'link' when calling lstat on a symlink pointing to existing file" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      stat = symlink.lstat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'link'
    end

    it "should return a File::Stat of ftype 'link' when calling lstat on a symlink pointing to missing file" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      stat = symlink.lstat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'link'
    end

    it "should return a File::Stat of ftype 'file' when calling stat on a symlink pointing to existing file" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      stat = symlink.stat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'file'
    end

    it "should return a File::Stat of ftype 'directory' when calling stat on a symlink pointing to existing directory" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      dir.symlink(symlink.path)

      stat = symlink.stat
      stat.should be_instance_of(File::Stat)
      stat.ftype.should == 'directory'
    end

    it "should return a File::Stat of ftype 'file' when calling stat on a symlink pointing to another symlink" do
      # point symlink -> file
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      # point symlink2 -> symlink
      symlink2 = Puppet::FileSystem::File.new(tmpfile("somefile_link2"))
      symlink.symlink(symlink2.path)

      symlink2.stat.ftype.should == 'file'
    end


    it "should raise Errno::ENOENT when calling stat on a dangling symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      expect { symlink.stat }.to raise_error(Errno::ENOENT)
    end

    it "should be able to readlink to resolve the physical path to a symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      file.exist?.should be_true
      symlink.readlink.should == file.path.to_s
    end

    it "should not resolve entire symlink chain with readlink on a symlink'd symlink" do
      # point symlink -> file
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      file.symlink(symlink.path)

      # point symlink2 -> symlink
      symlink2 = Puppet::FileSystem::File.new(tmpfile("somefile_link2"))
      symlink.symlink(symlink2.path)

      file.exist?.should be_true
      symlink2.readlink.should == symlink.path.to_s
    end

    it "should be able to readlink to resolve the physical path to a dangling symlink" do
      symlink = Puppet::FileSystem::File.new(tmpfile("somefile_link"))
      missing_file.symlink(symlink.path)

      missing_file.exist?.should be_false
      symlink.readlink.should == missing_file.path.to_s
    end

    it "should delete only the symlink and not the target when calling unlink instance method" do
      [file, dir].each do |target|
        symlink = Puppet::FileSystem::File.new(tmpfile("#{target.path.basename.to_s}_link"))
        target.symlink(symlink.path)

        target.exist?.should be_true
        symlink.readlink.should == target.path.to_s

        symlink.unlink.should == 1 # count of files

        target.exist?.should be_true
        symlink.exist?.should be_false
      end
    end

    it "should delete only the symlink and not the target when calling unlink class method" do
      [file, dir].each do |target|
        symlink = Puppet::FileSystem::File.new(tmpfile("#{target.path.basename.to_s}_link"))
        target.symlink(symlink.path)

        target.exist?.should be_true
        symlink.readlink.should == target.path.to_s

        Puppet::FileSystem::File.unlink(symlink.path).should == 1  # count of files

        target.exist?.should be_true
        symlink.exist?.should be_false
      end
    end

    describe "unlink" do
      it "should delete files with unlink" do
        file.exist?.should be_true

        file.unlink.should == 1  # count of files

        file.exist?.should be_false
      end

      it "should delete files with unlink class method" do
        file.exist?.should be_true

        Puppet::FileSystem::File.unlink(file.path).should == 1  # count of files

        file.exist?.should be_false
      end

      it "should delete multiple files with unlink class method" do
        paths = (1..3).collect do |i|
          f = Puppet::FileSystem::File.new(tmpfile("somefile_#{i}"))
          FileUtils.touch(f.path)
          f.exist?.should be_true
          f.path.to_s
        end

        Puppet::FileSystem::File.unlink(*paths).should == 3  # count of files

        paths.each { |p| Puppet::FileSystem::File.exist?(p).should be_false  }
      end

      it "should raise Errno::EPERM or Errno::EISDIR when trying to delete a directory with the unlink class method" do
        dir.exist?.should be_true

        ex = nil
        begin
          Puppet::FileSystem::File.unlink(dir.path)
        rescue Exception => e
          ex = e
        end

        [
          Errno::EPERM, # Windows and OSX
          Errno::EISDIR # Linux
        ].should include ex.class

        dir.exist?.should be_true
      end
    end
  end
end
