# coding: utf-8
require 'spec_helper'

describe Puppet::Util do
  include PuppetSpec::Files

  describe "#replace_file on Windows", :if => Puppet::Util::Platform.windows? do
    it "replace_file should preserve original ACEs from existing replaced file on Windows" do

      file = tmpfile("somefile")
      FileUtils.touch(file)

      admins = 'S-1-5-32-544'
      dacl = Puppet::Util::Windows::AccessControlList.new
      dacl.allow(admins, Puppet::Util::Windows::File::FILE_ALL_ACCESS)
      protect = true
      expected_sd = Puppet::Util::Windows::SecurityDescriptor.new(admins, admins, dacl, protect)
      Puppet::Util::Windows::Security.set_security_descriptor(file, expected_sd)

      ignored_mode = 0644
      Puppet::Util.replace_file(file, ignored_mode) do |temp_file|
        ignored_sd = Puppet::Util::Windows::Security.get_security_descriptor(temp_file.path)
        users = 'S-1-5-11'
        ignored_sd.dacl.allow(users, Puppet::Util::Windows::File::FILE_GENERIC_READ)
        Puppet::Util::Windows::Security.set_security_descriptor(temp_file.path, ignored_sd)
      end

      replaced_sd = Puppet::Util::Windows::Security.get_security_descriptor(file)

      expect(replaced_sd.dacl).to eq(expected_sd.dacl)
    end

    it "replace_file should use reasonable default ACEs on a new file on Windows" do

      dir = tmpdir('DACL_playground')
      protected_sd = Puppet::Util::Windows::Security.get_security_descriptor(dir)
      protected_sd.protect = true
      Puppet::Util::Windows::Security.set_security_descriptor(dir, protected_sd)

      sibling_path = File.join(dir, 'sibling_file')
      FileUtils.touch(sibling_path)

      expected_sd = Puppet::Util::Windows::Security.get_security_descriptor(sibling_path)

      new_file_path = File.join(dir, 'new_file')

      ignored_mode = nil
      Puppet::Util.replace_file(new_file_path, ignored_mode) { |tmp_file| }

      new_sd = Puppet::Util::Windows::Security.get_security_descriptor(new_file_path)

      expect(new_sd.dacl).to eq(expected_sd.dacl)
    end

    it "replace_file should work with filenames that include - and . (PUP-1389)" do
      expected_content = 'some content'
      dir = tmpdir('ReplaceFile_playground')
      destination_file = File.join(dir, 'some-file.xml')

      Puppet::Util.replace_file(destination_file, nil) do |temp_file|
          temp_file.open
          temp_file.write(expected_content)
      end

      actual_content = File.read(destination_file)
      expect(actual_content).to eq(expected_content)
    end

    it "replace_file should work with filenames that include special characters (PUP-1389)" do
      expected_content = 'some content'
      dir = tmpdir('ReplaceFile_playground')
      # http://www.fileformat.info/info/unicode/char/00e8/index.htm
      # dest_name = "somèfile.xml"
      dest_name = "som\u00E8file.xml"
      destination_file = File.join(dir, dest_name)

      Puppet::Util.replace_file(destination_file, nil) do |temp_file|
          temp_file.open
          temp_file.write(expected_content)
      end

      actual_content = File.read(destination_file)
      expect(actual_content).to eq(expected_content)
    end
  end

  describe "#which on Windows", :if => Puppet::Util::Platform.windows? do
    let (:rune_utf8) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }
    let (:filename) { 'foo.exe' }

    it "should be able to use UTF8 characters in the path" do
      utf8 = tmpdir(rune_utf8)
      Puppet::FileSystem.mkpath(utf8)

      filepath = File.join(utf8, filename)
      Puppet::FileSystem.touch(filepath)

      path = [utf8, "c:\\windows\\system32", "c:\\windows"].join(File::PATH_SEPARATOR)
      Puppet::Util.withenv("PATH" => path) do
        expect(Puppet::Util.which(filename)).to eq(filepath)
      end
    end
  end
end
