require 'spec_helper'
require 'puppet/file_system'
require 'puppet/util/platform'

describe "Puppet::FileSystem" do
  include PuppetSpec::Files

  def with_file_content(content)
    path = tmpfile('file-system')
    file = File.new(path, 'wb')
    file.sync = true
    file.print content

    yield path

  ensure
    file.close
  end

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

    it "times out if the lock cannot be acquired in a specified amount of time", :unless => Puppet::Util::Platform.windows? do
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

  context "read_preserve_line_endings" do
    it "should read a file with line feed" do
      with_file_content("file content \n") do |file|
        expect(Puppet::FileSystem.read_preserve_line_endings(file)).to eq("file content \n")
      end
    end

    it "should read a file with carriage return line feed" do
      with_file_content("file content \r\n") do |file|
        expect(Puppet::FileSystem.read_preserve_line_endings(file)).to eq("file content \r\n")
      end
    end

    it "should read a mixed file using only the first line newline when lf" do
      with_file_content("file content \nsecond line \r\n") do |file|
        expect(Puppet::FileSystem.read_preserve_line_endings(file)).to eq("file content \nsecond line \r\n")
      end
    end

    it "should read a mixed file using only the first line newline when crlf" do
      with_file_content("file content \r\nsecond line \n") do |file|
        expect(Puppet::FileSystem.read_preserve_line_endings(file)).to eq("file content \r\nsecond line \n")
      end
    end
  end

  context "read should allow an encoding to be specified" do
    # First line of Rune version of Rune poem at http://www.columbia.edu/~fdc/utf8/
    # characters chosen since they will not parse on Windows with codepage 437 or 1252
    # Section 3.2.1.3 of Ruby spec guarantees that \u strings are encoded as UTF-8
    let (:rune_utf8) { "\u16A0\u16C7\u16BB" } # 'ᚠᛇᚻ'

    it "and should read a UTF8 file properly" do
      temp_file = file_containing('utf8.txt', rune_utf8)

      contents = Puppet::FileSystem.read(temp_file, :encoding => 'utf-8')

      expect(contents.encoding).to eq(Encoding::UTF_8)
      expect(contents).to eq(rune_utf8)
    end

    it "does not strip the UTF8 BOM (Byte Order Mark) if present in a file" do
      bom = "\uFEFF"

      temp_file = file_containing('utf8bom.txt', "#{bom}#{rune_utf8}")
      contents = Puppet::FileSystem.read(temp_file, :encoding => 'utf-8')

      expect(contents.encoding).to eq(Encoding::UTF_8)
      expect(contents).to eq("#{bom}#{rune_utf8}")
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
      expect(Puppet::FileSystem.symlink?(file)).to be_falsey
    end

    it "should raise an error when trying to read a symlink" do
      expect { Puppet::FileSystem.readlink(file) }.to raise_error(Puppet::Util::Windows::Error)
    end

    it "should return a File::Stat instance when calling stat on an existing file" do
      expect(Puppet::FileSystem.stat(file)).to be_instance_of(File::Stat)
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
      expect(Puppet::FileSystem.exist?(file)).to be_truthy
    end

    it "should return true for file? on a present file" do
      expect(Puppet::FileSystem.file?(file)).to be_truthy
    end

    it "should return false for exist? on a non-existent file" do
      expect(Puppet::FileSystem.exist?(missing_file)).to be_falsey
    end

    it "should return true for exist? on a present directory" do
      expect(Puppet::FileSystem.exist?(dir)).to be_truthy
    end

    it "should return false for exist? on a dangling symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      expect(Puppet::FileSystem.exist?(missing_file)).to be_falsey
      expect(Puppet::FileSystem.exist?(symlink)).to be_falsey
    end

    it "should return true for exist? on valid symlinks" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target).to_s}_link")
        Puppet::FileSystem.symlink(target, symlink)

        expect(Puppet::FileSystem.exist?(target)).to be_truthy
        expect(Puppet::FileSystem.exist?(symlink)).to be_truthy
      end
    end

    it "should return false for exist? when resolving a cyclic symlink chain" do
      # point symlink -> file
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      # point symlink2 -> symlink
      symlink2 = tmpfile("somefile_link2")
      Puppet::FileSystem.symlink(symlink, symlink2)

      # point symlink3 -> symlink2
      symlink3 = tmpfile("somefile_link3")
      Puppet::FileSystem.symlink(symlink2, symlink3)

      # yank file, temporarily dangle
      ::File.delete(file)

      # and trash it so that we can recreate it OK on windows
      Puppet::FileSystem.unlink(symlink)

      # point symlink -> symlink3 to create a cycle
      Puppet::FileSystem.symlink(symlink3, symlink)

      expect(Puppet::FileSystem.exist?(symlink3)).to be_falsey
    end

    it "should return true for exist? when resolving a symlink chain pointing to a file" do
      # point symlink -> file
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      # point symlink2 -> symlink
      symlink2 = tmpfile("somefile_link2")
      Puppet::FileSystem.symlink(symlink, symlink2)

      # point symlink3 -> symlink2
      symlink3 = tmpfile("somefile_link3")
      Puppet::FileSystem.symlink(symlink2, symlink3)

      expect(Puppet::FileSystem.exist?(symlink3)).to be_truthy
    end

    it "should return false for exist? when resolving a symlink chain that dangles" do
      # point symlink -> file
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      # point symlink2 -> symlink
      symlink2 = tmpfile("somefile_link2")
      Puppet::FileSystem.symlink(symlink, symlink2)

      # point symlink3 -> symlink2
      symlink3 = tmpfile("somefile_link3")
      Puppet::FileSystem.symlink(symlink2, symlink3)

      # yank file, and make symlink dangle
      ::File.delete(file)

      # symlink3 is now indirectly dangled
      expect(Puppet::FileSystem.exist?(symlink3)).to be_falsey
    end

    it "should not create a symlink when the :noop option is specified" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target)}_link")
        Puppet::FileSystem.symlink(target, symlink, { :noop => true })

        expect(Puppet::FileSystem.exist?(target)).to be_truthy
        expect(Puppet::FileSystem.exist?(symlink)).to be_falsey
      end
    end

    it "should raise Errno::EEXIST if trying to create a file / directory symlink when the symlink path already exists as a file" do
      existing_file = tmpfile("#{Puppet::FileSystem.basename(file)}_link")
      FileUtils.touch(existing_file)

      [file, dir].each do |target|
        expect { Puppet::FileSystem.symlink(target, existing_file) }.to raise_error(Errno::EEXIST)

        expect(Puppet::FileSystem.exist?(existing_file)).to be_truthy
        expect(Puppet::FileSystem.symlink?(existing_file)).to be_falsey
      end
    end

    it "should silently fail if trying to create a file / directory symlink when the symlink path already exists as a directory" do
      existing_dir = tmpdir("#{Puppet::FileSystem.basename(file)}_dir")

      [file, dir].each do |target|
        expect(Puppet::FileSystem.symlink(target, existing_dir)).to eq(0)

        expect(Puppet::FileSystem.exist?(existing_dir)).to be_truthy
        expect(File.directory?(existing_dir)).to be_truthy
        expect(Puppet::FileSystem.symlink?(existing_dir)).to be_falsey
      end
    end

    it "should silently fail to modify an existing directory symlink to reference a new file or directory" do
      [file, dir].each do |target|
        existing_dir = tmpdir("#{Puppet::FileSystem.basename(target)}_dir")
        symlink = tmpfile("#{Puppet::FileSystem.basename(existing_dir)}_link")
        Puppet::FileSystem.symlink(existing_dir, symlink)

        expect(Puppet::FileSystem.readlink(symlink)).to eq(Puppet::FileSystem.path_string(existing_dir))

        # now try to point it at the new target, no error raised, but file system unchanged
        expect(Puppet::FileSystem.symlink(target, symlink)).to eq(0)
        expect(Puppet::FileSystem.readlink(symlink)).to eq(existing_dir.to_s)
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
        expect(Puppet::FileSystem.readlink(symlink)).to eq(file_2.to_s)
      end
    end

    it "should delete the existing file when creating a file / directory symlink with :force when the symlink path exists as a file" do
      [file, dir].each do |target|
        existing_file = tmpfile("#{Puppet::FileSystem.basename(target)}_existing")
        FileUtils.touch(existing_file)
        expect(Puppet::FileSystem.symlink?(existing_file)).to be_falsey

        Puppet::FileSystem.symlink(target, existing_file, { :force => true })

        expect(Puppet::FileSystem.symlink?(existing_file)).to be_truthy
        expect(Puppet::FileSystem.readlink(existing_file)).to eq(target.to_s)
      end
    end

    it "should modify an existing file symlink when using :force to reference a new file or directory" do
      [file, dir].each do |target|
        existing_file = tmpfile("#{Puppet::FileSystem.basename(target)}_existing")
        FileUtils.touch(existing_file)
        existing_symlink = tmpfile("#{Puppet::FileSystem.basename(existing_file)}_link")
        Puppet::FileSystem.symlink(existing_file, existing_symlink)

        expect(Puppet::FileSystem.readlink(existing_symlink)).to eq(existing_file.to_s)

        Puppet::FileSystem.symlink(target, existing_symlink, { :force => true })

        expect(Puppet::FileSystem.readlink(existing_symlink)).to eq(target.to_s)
      end
    end

    it "should silently fail if trying to overwrite an existing directory with a new symlink when using :force to reference a file or directory" do
      [file, dir].each do |target|
        existing_dir = tmpdir("#{Puppet::FileSystem.basename(target)}_existing")

        expect(Puppet::FileSystem.symlink(target, existing_dir, { :force => true })).to eq(0)

        expect(Puppet::FileSystem.symlink?(existing_dir)).to be_falsey
      end
    end

    it "should silently fail if trying to modify an existing directory symlink when using :force to reference a new file or directory" do
      [file, dir].each do |target|
        existing_dir = tmpdir("#{Puppet::FileSystem.basename(target)}_existing")
        existing_symlink = tmpfile("#{Puppet::FileSystem.basename(existing_dir)}_link")
        Puppet::FileSystem.symlink(existing_dir, existing_symlink)

        expect(Puppet::FileSystem.readlink(existing_symlink)).to eq(existing_dir.to_s)

        expect(Puppet::FileSystem.symlink(target, existing_symlink, { :force => true })).to eq(0)

        expect(Puppet::FileSystem.readlink(existing_symlink)).to eq(existing_dir.to_s)
      end
    end

    it "should accept a string, Pathname or object with to_str (Puppet::Util::WatchedFile) for exist?" do
      [ tmpfile('bogus1'),
        Pathname.new(tmpfile('bogus2')),
        Puppet::Util::WatchedFile.new(tmpfile('bogus3'))
        ].each { |f| expect(Puppet::FileSystem.exist?(f)).to be_falsey  }
    end

    it "should return a File::Stat instance when calling stat on an existing file" do
      expect(Puppet::FileSystem.stat(file)).to be_instance_of(File::Stat)
    end

    it "should raise Errno::ENOENT when calling stat on a missing file" do
      expect { Puppet::FileSystem.stat(missing_file) }.to raise_error(Errno::ENOENT)
    end

    it "should be able to create a symlink, and verify it with symlink?" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      expect(Puppet::FileSystem.symlink?(symlink)).to be_truthy
    end

    it "should report symlink? as false on file, directory and missing files" do
      [file, dir, missing_file].each do |f|
      expect(Puppet::FileSystem.symlink?(f)).to be_falsey
      end
    end

    it "should return a File::Stat with ftype 'link' when calling lstat on a symlink pointing to existing file" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      stat = Puppet::FileSystem.lstat(symlink)
      expect(stat).to be_instance_of(File::Stat)
      expect(stat.ftype).to eq('link')
    end

    it "should return a File::Stat of ftype 'link' when calling lstat on a symlink pointing to missing file" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      stat = Puppet::FileSystem.lstat(symlink)
      expect(stat).to be_instance_of(File::Stat)
      expect(stat.ftype).to eq('link')
    end

    it "should return a File::Stat of ftype 'file' when calling stat on a symlink pointing to existing file" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      stat = Puppet::FileSystem.stat(symlink)
      expect(stat).to be_instance_of(File::Stat)
      expect(stat.ftype).to eq('file')
    end

    it "should return a File::Stat of ftype 'directory' when calling stat on a symlink pointing to existing directory" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(dir, symlink)

      stat = Puppet::FileSystem.stat(symlink)
      expect(stat).to be_instance_of(File::Stat)
      expect(stat.ftype).to eq('directory')

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

      expect(Puppet::FileSystem.stat(symlink2).ftype).to eq('file')
    end


    it "should raise Errno::ENOENT when calling stat on a dangling symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      expect { Puppet::FileSystem.stat(symlink) }.to raise_error(Errno::ENOENT)
    end

    it "should be able to readlink to resolve the physical path to a symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      expect(Puppet::FileSystem.exist?(file)).to be_truthy
      expect(Puppet::FileSystem.readlink(symlink)).to eq(file.to_s)
    end

    it "should not resolve entire symlink chain with readlink on a symlink'd symlink" do
      # point symlink -> file
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)

      # point symlink2 -> symlink
      symlink2 = tmpfile("somefile_link2")
      Puppet::FileSystem.symlink(symlink, symlink2)

      expect(Puppet::FileSystem.exist?(file)).to be_truthy
      expect(Puppet::FileSystem.readlink(symlink2)).to eq(symlink.to_s)
    end

    it "should be able to readlink to resolve the physical path to a dangling symlink" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(missing_file, symlink)

      expect(Puppet::FileSystem.exist?(missing_file)).to be_falsey
      expect(Puppet::FileSystem.readlink(symlink)).to eq(missing_file.to_s)
    end

    it "should be able to unlink a dangling symlink pointed at a file" do
      symlink = tmpfile("somefile_link")
      Puppet::FileSystem.symlink(file, symlink)
      ::File.delete(file)
      Puppet::FileSystem.unlink(symlink)

      expect(Puppet::FileSystem).to_not be_exist(file)
      expect(Puppet::FileSystem).to_not be_exist(symlink)
    end

    it "should be able to unlink a dangling symlink pointed at a directory" do
      symlink = tmpfile("somedir_link")
      Puppet::FileSystem.symlink(dir, symlink)
      Dir.rmdir(dir)
      Puppet::FileSystem.unlink(symlink)

      expect(Puppet::FileSystem).to_not be_exist(dir)
      expect(Puppet::FileSystem).to_not be_exist(symlink)
    end

    it "should delete only the symlink and not the target when calling unlink instance method" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target)}_link")
        Puppet::FileSystem.symlink(target, symlink)

        expect(Puppet::FileSystem.exist?(target)).to be_truthy
        expect(Puppet::FileSystem.readlink(symlink)).to eq(target.to_s)

        expect(Puppet::FileSystem.unlink(symlink)).to eq(1) # count of files

        expect(Puppet::FileSystem.exist?(target)).to be_truthy
        expect(Puppet::FileSystem.exist?(symlink)).to be_falsey
      end
    end

    it "should delete only the symlink and not the target when calling unlink class method" do
      [file, dir].each do |target|
        symlink = tmpfile("#{Puppet::FileSystem.basename(target)}_link")
        Puppet::FileSystem.symlink(target, symlink)

        expect(Puppet::FileSystem.exist?(target)).to be_truthy
        expect(Puppet::FileSystem.readlink(symlink)).to eq(target.to_s)

        expect(Puppet::FileSystem.unlink(symlink)).to eq(1)  # count of files

        expect(Puppet::FileSystem.exist?(target)).to be_truthy
        expect(Puppet::FileSystem.exist?(symlink)).to be_falsey
      end
    end

    describe "unlink" do
      it "should delete files with unlink" do
        expect(Puppet::FileSystem.exist?(file)).to be_truthy

        expect(Puppet::FileSystem.unlink(file)).to eq(1)  # count of files

        expect(Puppet::FileSystem.exist?(file)).to be_falsey
      end

      it "should delete files with unlink class method" do
        expect(Puppet::FileSystem.exist?(file)).to be_truthy

        expect(Puppet::FileSystem.unlink(file)).to eq(1)  # count of files

        expect(Puppet::FileSystem.exist?(file)).to be_falsey
      end

      it "should delete multiple files with unlink class method" do
        paths = (1..3).collect do |i|
          f = tmpfile("somefile_#{i}")
          FileUtils.touch(f)
          expect(Puppet::FileSystem.exist?(f)).to be_truthy
          f.to_s
        end

        expect(Puppet::FileSystem.unlink(*paths)).to eq(3)  # count of files

        paths.each { |p| expect(Puppet::FileSystem.exist?(p)).to be_falsey  }
      end

      it "should raise Errno::EPERM or Errno::EISDIR when trying to delete a directory with the unlink class method" do
        expect(Puppet::FileSystem.exist?(dir)).to be_truthy

        ex = nil
        begin
          Puppet::FileSystem.unlink(dir)
        rescue Exception => e
          ex = e
        end

        expect([
          Errno::EPERM, # Windows and OSX
          Errno::EISDIR # Linux
        ]).to include(ex.class)

        expect(Puppet::FileSystem.exist?(dir)).to be_truthy
      end
    end

    describe "exclusive_create" do
      it "should create a file that doesn't exist" do
        expect(Puppet::FileSystem.exist?(missing_file)).to be_falsey

        Puppet::FileSystem.exclusive_create(missing_file, nil) {}

        expect(Puppet::FileSystem.exist?(missing_file)).to be_truthy
      end

      it "should raise Errno::EEXIST creating a file that does exist" do
        expect(Puppet::FileSystem.exist?(file)).to be_truthy

        expect do
          Puppet::FileSystem.exclusive_create(file, nil) {}
        end.to raise_error(Errno::EEXIST)
      end
    end
  end
end
