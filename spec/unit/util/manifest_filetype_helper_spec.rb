require 'spec_helper'

require 'puppet/util/manifest_filetype_helper'

describe Puppet::Util::ManifestFiletypeHelper do
  subject { Object.new.extend Puppet::Util::ManifestFiletypeHelper }

  describe "#is_ruby_filename?" do
    it "returns true when Ruby filename is passed as an argument" do
      subject.is_ruby_filename?("test.rb").should be true
    end

    it "returns false when not Ruby filename is passed as an argument" do
      subject.is_ruby_filename?("test").should be false
    end
  end

  describe "#is_puppet_filename?" do
    it "returns true when Puppet filename is passed as an argument" do
      subject.is_puppet_filename?("test.pp").should be true
    end

    it "returns false when non-Puppet filename is passed as an argument" do
      subject.is_puppet_filename?("test").should be false
    end
  end

end

