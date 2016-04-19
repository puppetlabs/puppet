#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe Puppet::Util::Windows::File, :if => Puppet::Util::Platform.windows? do
  include PuppetSpec::Files

  let(:nonexist_file) { 'C:\somefile\that\wont\ever\exist' }
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
end
