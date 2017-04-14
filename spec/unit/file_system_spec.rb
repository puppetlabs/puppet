require 'spec_helper'
require 'puppet/file_system'
require 'puppet/util/platform'

describe "Puppet::FileSystem" do
  include PuppetSpec::Files

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ𠜎

  def with_file_content(content)
    path = tmpfile('file-system')
    file = File.new(path, 'wb')
    file.sync = true
    file.print content

    yield path

  ensure
    file.close
  end

  SYSTEM_SID_BYTES = [1, 1, 0, 0, 0, 0, 0, 5, 18, 0, 0, 0]

  def is_current_user_system?
    SYSTEM_SID_BYTES == Puppet::Util::Windows::ADSI::User.current_user_sid.sid_bytes
  end

  context "#open" do
    it "uses the same default mode as File.open, when specifying a nil mode (umask used on non-Windows)" do
      file = tmpfile('file_to_update')
      expect(Puppet::FileSystem.exist?(file)).to be_falsey

      Puppet::FileSystem.open(file, nil, 'a') { |fh| fh.write('') }

      expected_perms = Puppet::Util::Platform.windows? ?
        # default Windows mode based on temp file storage for SYSTEM user or regular user
        # for Jenkins or other services running as SYSTEM writing to c:\windows\temp
        # the permissions will typically be SYSTEM(F) / Administrators(F) which is 770
        # but sometimes there are extra users like IIS_IUSRS granted rights which adds the "extra ace" 2
        # for local Administrators writing to their own temp folders under c:\users\USER
        # they will have (F) for themselves, and Users will not have a permission, hence 700
        (is_current_user_system? ? ['770', '2000770'] : '2000700') :
        # or for *nix determine expected mode via bitwise AND complement of umask
        (0100000 | 0666 & ~File.umask).to_s(8)
      expect([expected_perms].flatten).to include(Puppet::FileSystem.stat(file).mode.to_s(8))

      default_file = tmpfile('file_to_update2')
      expect(Puppet::FileSystem.exist?(default_file)).to be_falsey

      File.open(default_file, 'a') { |fh| fh.write('') }

      # which matches the behavior of File.open
      expect(Puppet::FileSystem.stat(file).mode).to eq(Puppet::FileSystem.stat(default_file).mode)
    end

    it "can accept an octal mode integer" do
      file = tmpfile('file_to_update')
      # NOTE: 777 here returns 755, but due to Ruby?
      Puppet::FileSystem.open(file, 0444, 'a') { |fh| fh.write('') }

      # Behavior may change in the future on Windows, to *actually* change perms
      # but for now, setting a mode doesn't touch them
      expected_perms = Puppet::Util::Platform.windows? ?
        (is_current_user_system? ? ['770', '2000770'] : '2000700') :
        '100444'
      expect([expected_perms].flatten).to include(Puppet::FileSystem.stat(file).mode.to_s(8))

      expected_ruby_mode = Puppet::Util::Platform.windows? ?
        # The Windows behavior has been changed to ignore the mode specified by open
        # given it's unlikely a caller expects Windows file attributes to be set
        # therefore mode is explicitly not managed (until PUP-6959 is fixed)
        #
        # In default Ruby on Windows a mode controls file attribute setting
        # (like archive, read-only, etc)
        # The GetFileInformationByHandle API returns an attributes value that is
        # a bitmask of Windows File Attribute Constants at
        # https://msdn.microsoft.com/en-us/library/windows/desktop/gg258117(v=vs.85).aspx
        '100644' :
        # On other platforms, the mode should be what was set by octal 0444
        '100444'

      expect(File.stat(file).mode.to_s(8)).to eq(expected_ruby_mode)
    end

    it "cannot accept a mode string" do
      file = tmpfile('file_to_update')
      expect {
        Puppet::FileSystem.open(file, "444", 'a') { |fh| fh.write('') }
      }.to raise_error(TypeError)
    end

    it "opens, creates ands allows updating of a new file, using by default, the external system encoding" do
      begin
        original_encoding = Encoding.default_external

        # this must be set through Ruby API and cannot be mocked - it sets internal state used by File.open
        # pick a bizarre encoding unlikely to be used in any real tests
        Encoding.default_external = Encoding::CP737

        file = tmpfile('file_to_update')

        # test writing a UTF-8 string when Default external encoding is something different
        Puppet::FileSystem.open(file, 0660, 'w') do |fh|
          # note Ruby behavior which has no external_encoding, but implicitly uses Encoding.default_external
          expect(fh.external_encoding).to be_nil
          # write a UTF-8 string to this file
          fh.write(mixed_utf8)
        end

        # prove that Ruby implicitly converts read strings back to Encoding.default_external
        # and that it did that in the previous write
        written = Puppet::FileSystem.read(file)
        expect(written.encoding).to eq(Encoding.default_external)
        expect(written).to eq(mixed_utf8.force_encoding(Encoding.default_external))
      ensure
        # carefully roll back to the previous
        Encoding.default_external = original_encoding
      end
    end
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

    it "opens, creates ands allows updating of a new file, using by default, the external system encoding" do
      begin
        original_encoding = Encoding.default_external

        # this must be set through Ruby API and cannot be mocked - it sets internal state used by File.open
        # pick a bizarre encoding unlikely to be used in any real tests
        Encoding.default_external = Encoding::CP737

        file = tmpfile('file_to_update')

        # test writing a UTF-8 string when Default external encoding is something different
        Puppet::FileSystem.exclusive_open(file, 0660, 'w') do |fh|
          # note Ruby behavior which has no external_encoding, but implicitly uses Encoding.default_external
          expect(fh.external_encoding).to be_nil
          # write a UTF-8 string to this file
          fh.write(mixed_utf8)
        end

        # prove that Ruby implicitly converts read strings back to Encoding.default_external
        # and that it did that in the previous write
        written = Puppet::FileSystem.read(file)
        expect(written.encoding).to eq(Encoding.default_external)
        expect(written).to eq(mixed_utf8.force_encoding(Encoding.default_external))
      ensure
        # carefully roll back to the previous
        Encoding.default_external = original_encoding
      end
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

  context "read without an encoding specified" do
    it "returns strings as Encoding.default_external" do
      temp_file = file_containing('test.txt', 'hello world')

      contents = Puppet::FileSystem.read(temp_file)

      expect(contents.encoding).to eq(Encoding.default_external)
      expect(contents).to eq('hello world')
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

    describe 'expand_path' do
      it 'should raise an error when given nil, like Ruby File.expand_path' do
        expect { File.expand_path(nil) }.to raise_error(TypeError)

        # match Ruby behavior
        expect { Puppet::FileSystem.expand_path(nil) }.to raise_error(TypeError)
      end

      it 'with an expanded path passed to Dir.glob, the same expanded path will be returned' do
        # this exists specifically for Puppet::Pops::Loader::ModuleLoaders::FileBased#add_to_index
        # which should receive an expanded path value from it's parent Environment
        # and will later compare values generated by Dir.glob
        tmp_long_file = tmpfile('foo.bar', tmpdir('super-long-thing-that-Windows-shortens'))
        Puppet::FileSystem.touch(tmp_long_file)
        expanded_path = Puppet::FileSystem.expand_path(tmp_long_file)

        expect(expanded_path).to eq(Dir.glob(expanded_path).first)
      end

      describe 'on non-Windows', :unless => Puppet::Util::Platform.windows? do
        it 'should produce the same results as the Ruby File.expand_path' do
          # on Windows this may be 8.3 style, but not so on other platforms
          # only done since ::File.expects(:expand_path).with(path).at_least_once
          # cannot be used since it will cause a stack overflow
          path = tmpdir('foobar')

          expect(Puppet::FileSystem.expand_path(path)).to eq(File.expand_path(path))
        end
      end

      describe 'on Windows', :if => Puppet::Util::Platform.windows? do
        let(:nonexist_file) { 'C:\\file~1.ext' }
        let(:nonexist_path) { 'C:\\progra~1\\missing\\path\\file.ext' }

        ['/', '\\'].each do |slash|
          it "should return the absolute path including system drive letter when given #{slash}, like Ruby File.expand_path" do

            # regardless of slash direction, return value is drive letter
            expanded = Puppet::FileSystem.expand_path(slash)
            expect(expanded).to eq(ENV['SystemDrive'] + File::SEPARATOR)
            expect(expanded).to eq(File.expand_path(slash))
          end
        end

        it 'should behave like Rubys File.expand_path for a file that doesnt exist' do
          expect(Puppet::FileSystem.exist?(nonexist_file)).to be_falsey
          # this will change c:\\file~1.ext to c:/file~1.ext (existing Ruby behavior), but not expand any ~
          ruby_expanded = File.expand_path(nonexist_file)
          expect(ruby_expanded).to match(/~/)
          expect(Puppet::FileSystem.expand_path(nonexist_file)).to eq(ruby_expanded)
        end

        it 'should behave like Rubys File.expand_path for a file with a parent path that doesnt exist' do
          expect(Puppet::FileSystem.exist?(nonexist_path)).to be_falsey
          # this will change c:\\progra~1 to c:/progra~1 (existing Ruby behavior), but not expand any ~
          ruby_expanded = File.expand_path(nonexist_path)
          expect(ruby_expanded).to match(/~/)
          expect(Puppet::FileSystem.expand_path(nonexist_path)).to eq(ruby_expanded)
        end

        it 'should expand a shortened path completely, unlike Ruby File.expand_path' do
          tmp_long_dir = tmpdir('super-long-thing-that-Windows-shortens')
          short_path = Puppet::Util::Windows::File.get_short_pathname(tmp_long_dir)

          # a shortened path to the temp dir will have a least 2 ~
          # for instance, C:\\Users\\Administrator\\AppData\\Local\\Temp\\rspecrun2016####-####-#######\\super-long-thing-that-Windows-shortens\
          # or C:\\Windows\\Temp\\rspecrun2016####-####-#######\\super-long-thing-that-Windows-shortens\
          # will shorten to Temp\\rspecr~#\\super-~1
          expect(short_path).to match(/~.*~/)

          # expand with Ruby, noting not all ~ have been expanded
          # which is the primary reason that a Puppet helper exists
          ruby_expanded = File.expand_path(short_path)
          expect(ruby_expanded).to match(/~/)

          # Puppet expansion uses the Windows API and has no ~ remaining
          puppet_expanded = Puppet::FileSystem.expand_path(short_path)
          expect(puppet_expanded).to_not match(/~/)

          # and the directories are one and the same
          expect(File.identical?(short_path, puppet_expanded)).to be_truthy
        end
      end
    end
  end
end
