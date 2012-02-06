#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Util do
  subject { Puppet::Util }
  include PuppetSpec::Files

  context "#replace_file" do
    it { should respond_to :replace_file }

    let :target do
      target = Tempfile.new("puppet-util-replace-file")
      target.puts("hello, world")
      target.flush              # make sure content is on disk.
      target.fsync rescue nil
      target.close
      target
    end

    it "should fail if no block is given" do
      expect { subject.replace_file(target.path, 0600) }.to raise_error /block/
    end

    it "should replace a file when invoked" do
      # Check that our file has the expected content.
      File.read(target.path).should == "hello, world\n"

      # Replace the file.
      subject.replace_file(target.path, 0600) do |fh|
        fh.puts "I am the passenger..."
      end

      # ...and check the replacement was complete.
      File.read(target.path).should == "I am the passenger...\n"
    end

    [0555, 0600, 0660, 0700, 0770].each do |mode|
      it "should copy 0#{mode.to_s(8)} permissions from the target file by default" do
        File.chmod(mode, target.path)

        (File.stat(target.path).mode & 07777).should == mode

        subject.replace_file(target.path, 0000) {|fh| fh.puts "bazam" }

        (File.stat(target.path).mode & 07777).should == mode
        File.read(target.path).should == "bazam\n"
      end
    end

    it "should copy the permissions of the source file before yielding" do
      File.chmod(0555, target.path)
      inode = File.stat(target.path).ino

      yielded = false
      subject.replace_file(target.path, 0600) do |fh|
        (File.stat(fh.path).mode & 07777).should == 0555
        yielded = true
      end
      yielded.should be_true

      # We can't check inode on Windows
      File.stat(target.path).ino.should_not == inode

      (File.stat(target.path).mode & 07777).should == 0555
    end

    it "should use the default permissions if the source file doesn't exist" do
      new_target = target.path + '.foo'
      File.should_not be_exist(new_target)

      begin
        subject.replace_file(new_target, 0555) {|fh| fh.puts "foo" }
        (File.stat(new_target).mode & 07777).should == 0555
      ensure
        File.unlink(new_target) if File.exists?(new_target)
      end
    end

    it "should not replace the file if an exception is thrown in the block" do
      yielded = false
      threw   = false

      begin
        subject.replace_file(target.path, 0600) do |fh|
          yielded = true
          fh.puts "different content written, then..."
          raise "...throw some random failure"
        end
      rescue Exception => e
        if e.to_s =~ /some random failure/
          threw = true
        else
          raise
        end
      end

      yielded.should be_true
      threw.should be_true

      # ...and check the replacement was complete.
      File.read(target.path).should == "hello, world\n"
    end
  end
end
