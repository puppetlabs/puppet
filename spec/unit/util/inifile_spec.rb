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

describe Puppet::Util::IniConfig::PhysicalFile do
  subject { described_class.new('/some/nonexistent/file') }

  describe "when reading a file" do
    it "raises an error if the file does not exist" do
      subject.filetype.stubs(:read)
      expect {
        subject.read
      }.to raise_error(%r[Cannot read nonexistent file .*/some/nonexistent/file])
    end

    it "passes the contents of the file to #parse" do
      subject.filetype.stubs(:read).returns "[section]"
      subject.expects(:parse).with("[section]")

      subject.read
    end

  end

  describe "when parsing a file" do
    describe "parsing sections" do
      it "creates new sections the first time that the section is found" do
        text = "[mysect]\n"

        subject.parse(text)

        expect(subject.contents).to have(1).items
        sect = subject.contents[0]
        expect(sect.name).to eq "mysect"
      end

      it "raises an error if a section is redefined in the file" do
        text = "[mysect]\n[mysect]\n"

        expect {
          subject.parse(text)
        }.to raise_error(Puppet::Util::IniConfig::IniParseError,
                         /Section "mysect" is already defined, cannot redefine/)
      end

      it "raises an error if a section is redefined in the file collection"
    end

    describe "parsing properties" do
      it "raises an error if the property is not within a section" do
        text = "key=val\n"

        expect {
          subject.parse(text)
        }.to raise_error(Puppet::Util::IniConfig::IniParseError,
                         /Property with key "key" outside of a section/)
      end

      it "adds the property to the current section" do
        text = "[main]\nkey=val\n"

        subject.parse(text)
        expect(subject.contents).to have(1).items
        sect = subject.contents[0]
        expect(sect['key']).to eq "val"
      end
    end

    describe "parsing line continuations" do

      it "adds the continued line to the last parsed property" do
        text = "[main]\nkey=val\n moreval"

        subject.parse(text)
        expect(subject.contents).to have(1).items
        sect = subject.contents[0]
        expect(sect['key']).to eq "val\n moreval"
      end
    end

    describe "parsing comments and whitespace" do
      it "treats # as a comment leader" do
        text = "# octothorpe comment"

        subject.parse(text)
        expect(subject.contents).to eq ["# octothorpe comment"]
      end

      it "treats ; as a comment leader" do
        text = "; semicolon comment"

        subject.parse(text)
        expect(subject.contents).to eq ["; semicolon comment"]
      end

      it "treates 'rem' as a comment leader" do
        text = "rem rapid eye movement comment"

        subject.parse(text)
        expect(subject.contents).to eq ["rem rapid eye movement comment"]
      end

      it "stores comments and whitespace in a section in the correct section" do
        text = "[main]\n; main section comment"

        subject.parse(text)

        sect = subject.get_section("main")
        expect(sect.entries).to eq ["; main section comment"]
      end
    end
  end

  it "can return all sections" do
    text = "[first]\n" +
           "; comment\n" +
           "[second]\n" +
           "key=value"

    subject.parse(text)

    sections = subject.sections
    expect(sections).to have(2).items
    expect(sections[0].name).to eq "first"
    expect(sections[1].name).to eq "second"
  end

  it "can retrieve a specific section" do
    text = "[first]\n" +
           "; comment\n" +
           "[second]\n" +
           "key=value"

    subject.parse(text)

    section = subject.get_section("second")
    expect(section.name).to eq "second"
    expect(section["key"]).to eq "value"
  end
end
