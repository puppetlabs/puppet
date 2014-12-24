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

    it "is dirty if the section is marked for deletion" do
      subject.destroy = true
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

    it "is empty if the section is marked for deletion" do
      subject.entries << ['firstkey', 'firstval']
      subject.destroy = true
      expect(subject.format).to eq('')
    end
  end
end

describe Puppet::Util::IniConfig::PhysicalFile do
  subject { described_class.new('/some/nonexistent/file') }

  let(:first_sect) do
    sect = Puppet::Util::IniConfig::Section.new('firstsection', '/some/imaginary/file')
    sect.entries << "# comment\n" << ['onefish', 'redfish'] << "\n"
    sect
  end

  let(:second_sect) do
    sect = Puppet::Util::IniConfig::Section.new('secondsection', '/some/imaginary/file')
    sect.entries << ['twofish', 'bluefish']
    sect
  end

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

      it "raises an error if a section is redefined in the file collection" do
        subject.file_collection = stub('file collection', :get_section => true)
        text = "[mysect]\n[mysect]\n"

        expect {
          subject.parse(text)
        }.to raise_error(Puppet::Util::IniConfig::IniParseError,
                         /Section "mysect" is already defined, cannot redefine/)
      end

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

  describe "formatting" do

    it "concatenates each formatted section in order" do
      subject.contents << first_sect << second_sect

      expected = "[firstsection]\n" +
        "# comment\n" +
        "onefish=redfish\n" +
        "\n" +
        "[secondsection]\n" +
        "twofish=bluefish\n"

      expect(subject.format).to eq expected
    end

    it "includes comments that are not within a section" do
      subject.contents << "# This comment is not in a section\n" << first_sect << second_sect

      expected = "# This comment is not in a section\n" +
        "[firstsection]\n" +
        "# comment\n" +
        "onefish=redfish\n" +
        "\n" +
        "[secondsection]\n" +
        "twofish=bluefish\n"

      expect(subject.format).to eq expected
    end

    it "excludes sections that are marked to be destroyed" do
      subject.contents << first_sect << second_sect
      first_sect.destroy = true

      expected = "[secondsection]\n" + "twofish=bluefish\n"

      expect(subject.format).to eq expected
    end
  end

  describe "storing the file" do
    describe "with empty contents" do
      describe "and destroy_empty is true" do
        before { subject.destroy_empty = true }
        it "removes the file if there are no sections" do
          File.expects(:unlink)
          subject.store
        end

        it "removes the file if all sections are marked to be destroyed" do
          subject.contents << first_sect << second_sect
          first_sect.destroy = true
          second_sect.destroy = true

          File.expects(:unlink)
          subject.store
        end

        it "doesn't remove the file if not all sections are marked to be destroyed" do
          subject.contents << first_sect << second_sect
          first_sect.destroy = true
          second_sect.destroy = false

          File.expects(:unlink).never
          subject.filetype.stubs(:write)
          subject.store
        end
      end

      it "rewrites the file if destroy_empty is false" do
        subject.contents << first_sect << second_sect
        first_sect.destroy = true
        second_sect.destroy = true

        File.expects(:unlink).never
        subject.stubs(:format).returns "formatted"
        subject.filetype.expects(:write).with("formatted")
        subject.store
      end
    end

    it "rewrites the file if any section is dirty" do
      subject.contents << first_sect << second_sect
      first_sect.mark_dirty
      second_sect.mark_clean

      subject.stubs(:format).returns "formatted"
      subject.filetype.expects(:write).with("formatted")
      subject.store
    end

    it "doesn't modify the file if all sections are clean" do
      subject.contents << first_sect << second_sect
      first_sect.mark_clean
      second_sect.mark_clean

      subject.stubs(:format).returns "formatted"
      subject.filetype.expects(:write).never
      subject.store
    end
  end
end

describe Puppet::Util::IniConfig::FileCollection do

  let(:path_a) { '/some/nonexistent/file/a' }
  let(:path_b) { '/some/nonexistent/file/b' }

  let(:file_a) { Puppet::Util::IniConfig::PhysicalFile.new(path_a) }
  let(:file_b) { Puppet::Util::IniConfig::PhysicalFile.new(path_b) }

  let(:sect_a1) { Puppet::Util::IniConfig::Section.new('sect_a1', path_a) }
  let(:sect_a2) { Puppet::Util::IniConfig::Section.new('sect_a2', path_a) }

  let(:sect_b1) { Puppet::Util::IniConfig::Section.new('sect_b1', path_b) }
  let(:sect_b2) { Puppet::Util::IniConfig::Section.new('sect_b2', path_b) }

  before do
    file_a.contents << sect_a1 << sect_a2
    file_b.contents << sect_b1 << sect_b2
  end

  describe "reading a file" do
    let(:stub_file) { stub('Physical file') }

    it "creates a new PhysicalFile and uses that to read the file" do
      stub_file.expects(:read)
      stub_file.expects(:file_collection=)
      Puppet::Util::IniConfig::PhysicalFile.expects(:new).with(path_a).returns stub_file

      subject.read(path_a)
    end

    it "stores the PhysicalFile and the path to the file" do
      stub_file.stubs(:read)
      stub_file.stubs(:file_collection=)
      Puppet::Util::IniConfig::PhysicalFile.stubs(:new).with(path_a).returns stub_file
      subject.read(path_a)

      path, physical_file = subject.files.first

      expect(path).to eq(path_a)
      expect(physical_file).to eq stub_file
    end
  end

  describe "storing all files" do
    before do
      subject.files[path_a] = file_a
      subject.files[path_b] = file_b
    end

    it "stores all files in the collection" do
      file_a.expects(:store).once
      file_b.expects(:store).once

      subject.store
    end
  end

  describe "iterating over sections" do
    before do
      subject.files[path_a] = file_a
      subject.files[path_b] = file_b
    end

    it "yields every section from every file" do
      [sect_a1, sect_a2, sect_b1, sect_b2].each do |sect|
        sect.expects(:touch).once
      end

      subject.each_section do |sect|
        sect.touch
      end
    end
  end

  describe "iterating over files" do
    before do
      subject.files[path_a] = file_a
      subject.files[path_b] = file_b
    end

    it "yields the path to every file in the collection" do
      seen = []
      subject.each_file do |file|
        seen << file
      end

      expect(seen).to include(path_a)
      expect(seen).to include(path_b)
    end
  end

  describe "retrieving a specific section" do
    before do
      subject.files[path_a] = file_a
      subject.files[path_b] = file_b
    end

    it "retrieves the first section defined" do
      expect(subject.get_section('sect_b1')).to eq sect_b1
    end

    it "returns nil if there was no section with the given name" do
      expect(subject.get_section('nope')).to be_nil
    end

    it "allows #[] to be used as an alias to #get_section" do
      expect(subject['b2']).to eq subject.get_section('b2')
    end
  end

  describe "checking if a section has been defined" do
    before do
      subject.files[path_a] = file_a
      subject.files[path_b] = file_b
    end

    it "is true if a section with the given name is defined" do
      expect(subject.include?('sect_a1')).to be_truthy
    end

    it "is false if a section with the given name can't be found" do
      expect(subject.include?('nonexistent')).to be_falsey
    end
  end

  describe "adding a new section" do
    before do
      subject.files[path_a] = file_a
      subject.files[path_b] = file_b
    end

    it "adds the section to the appropriate file" do
      file_a.expects(:add_section).with('newsect')
      subject.add_section('newsect', path_a)
    end
  end
end
