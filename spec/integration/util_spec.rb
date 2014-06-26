#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util do
  include PuppetSpec::Files

  describe "#execute" do
    it "should properly allow stdout and stderr to share a file" do
      command = "ruby -e '(1..10).each {|i| (i%2==0) ? $stdout.puts(i) : $stderr.puts(i)}'"

      Puppet::Util::Execution.execute(command, :combine => true).split.should =~ [*'1'..'10']
    end

    it "should return output and set $CHILD_STATUS" do
      command = "ruby -e 'puts \"foo\"; exit 42'"

      output = Puppet::Util::Execution.execute(command, {:failonfail => false})

      output.should == "foo\n"
      $CHILD_STATUS.exitstatus.should == 42
    end

    it "should raise an error if non-zero exit status is returned" do
      command = "ruby -e 'exit 43'"

      expect { Puppet::Util::Execution.execute(command) }.to raise_error(Puppet::ExecutionFailure, /Execution of '#{command}' returned 43: /)
      $CHILD_STATUS.exitstatus.should == 43
    end

    it "replace_file should preserve original ACEs from existing replaced file on Windows",
      :if => Puppet.features.microsoft_windows? do

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

      replaced_sd.dacl.should == expected_sd.dacl
    end

    it "replace_file should use reasonable default ACEs on a new file on Windows",
      :if => Puppet.features.microsoft_windows? do

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

      new_sd.dacl.should == expected_sd.dacl
    end
  end

  it "replace_file should work with filenames that include - and . (PUP-1389)", :if => Puppet.features.microsoft_windows? do
    expected_content = 'some content'
    dir = tmpdir('ReplaceFile_playground')
    destination_file = File.join(dir, 'some-file.xml')

    Puppet::Util.replace_file(destination_file, nil) do |temp_file|
        temp_file.open
        temp_file.write(expected_content)
    end

    actual_content = File.read(destination_file)
    actual_content.should == expected_content
  end

  it "replace_file should work with filenames that include special characters (PUP-1389)", :if => Puppet.features.microsoft_windows? do
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
    actual_content.should == expected_content
  end
end
