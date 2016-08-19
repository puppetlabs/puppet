#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe Puppet::Util::Windows::File, :if => Puppet::Util::Platform.windows? do
  include PuppetSpec::Files

  let(:nonexist_file) { 'C:\foo.bar' }
  let(:nonexist_path) { 'C:\somefile\that\wont\ever\exist' }
  let(:invalid_file_attributes) { 0xFFFFFFFF } #define INVALID_FILE_ATTRIBUTES (DWORD (-1))

  describe "get_attributes" do
    it "should raise an error for files that do not exist by default" do
      expect {
        described_class.get_attributes(nonexist_file)
      }.to raise_error(Puppet::Error, /GetFileAttributes/)
    end

    it "should raise an error for files that do not exist when specified" do
      expect {
        described_class.get_attributes(nonexist_file, true)
      }.to raise_error(Puppet::Error, /GetFileAttributes/)
    end

    it "should not raise an error for files that do not exist when specified" do
      expect {
        described_class.get_attributes(nonexist_file, false)
      }.not_to raise_error
    end

    it "should return INVALID_FILE_ATTRIBUTES for files that do not exist when specified" do
      expect(described_class.get_attributes(nonexist_file, false)).to eq(invalid_file_attributes)
    end
  end

  describe "get_long_pathname" do
    it "should raise an ERROR_FILE_NOT_FOUND for a file that does not exist in a valid path" do
      expect {
        described_class.get_long_pathname(nonexist_file)
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(Puppet::Util::Windows::File::ERROR_FILE_NOT_FOUND)
      end
    end

    it "should raise an ERROR_PATH_NOT_FOUND for a path that does not exist" do
      expect {
        described_class.get_long_pathname(nonexist_path)
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(Puppet::Util::Windows::File::ERROR_PATH_NOT_FOUND)
      end
    end

    it "should return the fully expanded path 'Program Files' given 'Progra~1'" do
      # this test could be resolve some of these values at runtime rather than hard-coding
      shortened = ENV['SystemDrive'] + '\\Progra~1'
      expanded = ENV['SystemDrive'] + '\\Program Files'
      expect(described_class.get_long_pathname(shortened)).to eq (expanded)
    end
  end

  describe "get_short_pathname" do
    it "should raise an ERROR_FILE_NOT_FOUND for a file that does not exist in a valid path" do
      expect {
        described_class.get_short_pathname(nonexist_file)
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(Puppet::Util::Windows::File::ERROR_FILE_NOT_FOUND)
      end
    end

    it "should raise an ERROR_PATH_NOT_FOUND for a path that does not exist" do
      expect {
        described_class.get_short_pathname(nonexist_path)
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(Puppet::Util::Windows::File::ERROR_PATH_NOT_FOUND)
      end
    end

    it "should return the shortened 'PROGRA~1' given fully expanded path 'Program Files'" do
      # this test could be resolve some of these values at runtime rather than hard-coding
      expanded = ENV['SystemDrive'] + '\\Program Files'
      shortened = ENV['SystemDrive'] + '\\PROGRA~1'
      expect(described_class.get_short_pathname(expanded)).to eq (shortened)
    end
  end
end
