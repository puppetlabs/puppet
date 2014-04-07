require 'spec_helper'
require 'puppet/util/inifile'

describe Puppet::Util::IniConfig::Section do

  subject { described_class.new('testsection', '/some/imaginary/file') }

  describe "determining if the section is dirty" do
    it "is not dirty on creation" do
      expect(subject).to_not be_dirty
    end

    it "is dirty if a key is changed" do
      subject['hello'] = 'world'
      expect(subject).to be_dirty
    end

    it "is dirty if the section has been explicitly marked as dirty" do
      subject.mark_dirty
      expect(subject).to be_dirty
    end

    it "is clean if the section has been explicitly marked as clean" do
      subject['hello'] = 'world'
      subject.mark_clean
      expect(subject).to_not be_dirty
    end
  end

  describe "reading an entry" do
    it "returns nil if the key is not present" do
      expect(subject['hello']).to be_nil
    end

    it "returns the value if the key is specified" do
      subject.entries << ['hello', 'world']
      expect(subject['hello']).to eq 'world'
    end

    it "ignores comments when looking for a match" do
      subject.entries << '#this = comment'
      expect(subject['#this']).to be_nil
    end
  end

  describe "formatting the section" do
    it "prefixes the output with the section header" do
      expect(subject.format).to eq "[testsection]\n"
    end

    it "restores comments and blank lines" do
      subject.entries << "#comment\n"
      subject.entries << "    "
      expect(subject.format).to eq(
        "[testsection]\n" +
        "#comment\n" +
        "    "
      )
    end

    it "adds all keys that have values" do
      subject.entries << ['somekey', 'somevalue']
      expect(subject.format).to eq("[testsection]\nsomekey=somevalue\n")
    end

    it "excludes keys that have a value of nil" do
      subject.entries << ['empty', nil]
      expect(subject.format).to eq("[testsection]\n")
    end

    it "preserves the order of the section" do
      subject.entries << ['firstkey', 'firstval']
      subject.entries << "# I am a comment, hear me roar\n"
      subject.entries << ['secondkey', 'secondval']

      expect(subject.format).to eq(
        "[testsection]\n" +
        "firstkey=firstval\n" +
        "# I am a comment, hear me roar\n" +
        "secondkey=secondval\n"
      )
    end
  end
end
