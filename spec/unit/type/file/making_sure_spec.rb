#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/type/file/making_sure'

describe Puppet::Type::File::MakingSure do
  include PuppetSpec::Files

  let(:path) { tmpfile('file_ensure') }
  let(:resource) { Puppet::Type.type(:file).new(:making_sure => 'file', :path => path, :replace => true) }
  let(:property) { resource.property(:making_sure) }

  it "should be a subclass of MakingSure" do
    described_class.superclass.must == Puppet::Property::MakingSure
  end

  describe "when retrieving the current state" do
    it "should return :absent if the file does not exist" do
      resource.expects(:stat).returns nil

      property.retrieve.should == :absent
    end

    it "should return the current file type if the file exists" do
      stat = mock 'stat', :ftype => "directory"
      resource.expects(:stat).returns stat

      property.retrieve.should == :directory
    end
  end

  describe "when testing whether :making_sure is in sync" do
    it "should always be in sync if replace is 'false' unless the file is missing" do
      property.should = :file
      resource.expects(:replace?).returns false
      property.safe_insync?(:link).should be_true
    end

    it "should be in sync if :making_sure is set to :absent and the file does not exist" do
      property.should = :absent

      property.must be_safe_insync(:absent)
    end

    it "should not be in sync if :making_sure is set to :absent and the file exists" do
      property.should = :absent

      property.should_not be_safe_insync(:file)
    end

    it "should be in sync if a normal file exists and :making_sure is set to :present" do
      property.should = :present

      property.must be_safe_insync(:file)
    end

    it "should be in sync if a directory exists and :making_sure is set to :present" do
      property.should = :present

      property.must be_safe_insync(:directory)
    end

    it "should be in sync if a symlink exists and :making_sure is set to :present" do
      property.should = :present

      property.must be_safe_insync(:link)
    end

    it "should not be in sync if :making_sure is set to :file and a directory exists" do
      property.should = :file

      property.should_not be_safe_insync(:directory)
    end
  end

  describe "#sync" do
    context "directory" do
      before :each do
        resource[:making_sure] = :directory
      end

      it "should raise if the parent directory doesn't exist" do
        newpath = File.join(path, 'nonexistentparent', 'newdir')
        resource[:path] = newpath

        expect {
          property.sync
        }.to raise_error(Puppet::Error, /Cannot create #{newpath}; parent directory #{File.dirname(newpath)} does not exist/)
      end

      it "should accept octal mode as fixnum" do
        resource[:mode] = 0700
        resource.expects(:property_fix)
        Dir.expects(:mkdir).with(path, 0700)

        property.sync
      end

      it "should accept octal mode as string" do
        resource[:mode] = "700"
        resource.expects(:property_fix)
        Dir.expects(:mkdir).with(path, 0700)

        property.sync
      end

      it "should accept octal mode as string with leading zero" do
        resource[:mode] = "0700"
        resource.expects(:property_fix)
        Dir.expects(:mkdir).with(path, 0700)

        property.sync
      end

      it "should accept symbolic mode" do
        resource[:mode] = "u=rwx,go=x"
        resource.expects(:property_fix)
        Dir.expects(:mkdir).with(path, 0711)

        property.sync
      end
    end
  end
end
