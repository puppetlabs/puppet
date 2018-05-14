#! /usr/bin/env ruby
# coding: utf-8
require 'spec_helper'

require 'puppet/util/tagging'

describe Puppet::Util::Tagging do
  let(:tagger) { Object.new.extend(Puppet::Util::Tagging) }

  it "should add tags to the returned tag list" do
    tagger.tag("one")
    expect(tagger.tags).to include("one")
  end

  it "should add all provided tags to the tag list" do
    tagger.tag("one", "two")
    expect(tagger.tags).to include("one")
    expect(tagger.tags).to include("two")
  end

  it "should fail on tags containing '*' characters" do
    expect { tagger.tag("bad*tag") }.to raise_error(Puppet::ParseError)
  end

  it "should fail on tags starting with '-' characters" do
    expect { tagger.tag("-badtag") }.to raise_error(Puppet::ParseError)
  end

  it "should fail on tags containing ' ' characters" do
    expect { tagger.tag("bad tag") }.to raise_error(Puppet::ParseError)
  end

  it "should fail on tags containing newline characters" do
    expect { tagger.tag("bad\ntag") }.to raise_error(Puppet::ParseError)
  end

  it "should allow alpha tags" do
    expect { tagger.tag("good_tag") }.not_to raise_error
  end

  it "should allow tags containing '.' characters" do
    expect { tagger.tag("good.tag") }.to_not raise_error
  end

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ܎

  it "should allow UTF-8 alphanumeric characters" do
    expect { tagger.tag(mixed_utf8) }.not_to raise_error
  end

  # completely non-exhaustive list of a few UTF-8 punctuation characters
  # http://www.fileformat.info/info/unicode/block/general_punctuation/utf8test.htm
  [
    "\u2020", # dagger †
    "\u203B", # reference mark ※
    "\u204F", # reverse semicolon ⁏
    "!",
    "@",
    "#",
    "$",
    "%",
    "^",
    "&",
    "*",
    "(",
    ")",
    "-",
    "+",
    "=",
    "{",
    "}",
    "[",
    "]",
    "|",
    "\\",
    "/",
    "?",
    "<",
    ">",
    ",",
    ".",
    "~",
    ",",
    ":",
    ";",
    "\"",
    "'",
  ].each do |char|
    it "should not allow UTF-8 punctuation characters, e.g. #{char}" do
      expect { tagger.tag(char) }.to raise_error(Puppet::ParseError)
    end
  end

  it "should allow encodings that can be coerced to UTF-8" do
     chinese = "標記你是它".force_encoding(Encoding::UTF_8)
     ascii   = "tags--".force_encoding(Encoding::ASCII_8BIT)
     jose    = "jos\xE9".force_encoding(Encoding::ISO_8859_1)

     [chinese, ascii, jose].each do |tag|
       expect(tagger.valid_tag?(tag)).to be_truthy
     end
  end

  it "should not allow strings that cannot be converted to UTF-8" do
    invalid = "\xA0".force_encoding(Encoding::ASCII_8BIT)
    expect(tagger.valid_tag?(invalid)).to be_falsey
  end

  it "should add qualified classes as tags" do
    tagger.tag("one::two")
    expect(tagger.tags).to include("one::two")
  end

  it "should add each part of qualified classes as tags" do
    tagger.tag("one::two::three")
    expect(tagger.tags).to include('one')
    expect(tagger.tags).to include("two")
    expect(tagger.tags).to include("three")
  end

  it "should indicate when the object is tagged with a provided tag" do
    tagger.tag("one")
    expect(tagger).to be_tagged("one")
  end

  it "should indicate when the object is not tagged with a provided tag" do
    expect(tagger).to_not be_tagged("one")
  end

  it "should indicate when the object is tagged with any tag in an array" do
    tagger.tag("one")
    expect(tagger).to be_tagged("one","two","three")
  end

  it "should indicate when the object is not tagged with any tag in an array" do
    tagger.tag("one")
    expect(tagger).to_not be_tagged("two","three")
  end

  context "when tagging" do
    it "converts symbols to strings" do
      tagger.tag(:hello)
      expect(tagger.tags).to include('hello')
    end

    it "downcases tags" do
      tagger.tag(:HEllO)
      tagger.tag("GooDByE")
      expect(tagger).to be_tagged("hello")
      expect(tagger).to be_tagged("goodbye")
    end

    it "downcases tag arguments" do
      tagger.tag("hello")
      tagger.tag("goodbye")
      expect(tagger).to be_tagged(:HEllO)
      expect(tagger).to be_tagged("GooDByE")
    end

    it "accepts hyphenated tags" do
      tagger.tag("my-tag")
      expect(tagger).to be_tagged("my-tag")
    end
  end

  context "when querying if tagged" do
    it "responds true if queried on the entire set" do
      tagger.tag("one", "two")
      expect(tagger).to be_tagged("one", "two")
    end

    it "responds true if queried on a subset" do
      tagger.tag("one", "two", "three")
      expect(tagger).to be_tagged("two", "one")
    end

    it "responds true if queried on an overlapping but not fully contained set" do
      tagger.tag("one", "two")
      expect(tagger).to be_tagged("zero", "one")
    end

    it "responds false if queried on a disjoint set" do
      tagger.tag("one", "two", "three")
      expect(tagger).to_not be_tagged("five")
    end

    it "responds false if queried on the empty set" do
      expect(tagger).to_not be_tagged
    end
  end

  context "when assigning tags" do
    it "splits a string on ','" do
      tagger.tags = "one, two, three"
      expect(tagger).to be_tagged("one")
      expect(tagger).to be_tagged("two")
      expect(tagger).to be_tagged("three")
    end

    it "protects against empty tags" do
      expect { tagger.tags = "one,,two"}.to raise_error(/Invalid tag ''/)
    end

    it "takes an array of tags" do
      tagger.tags = ["one", "two"]

      expect(tagger).to be_tagged("one")
      expect(tagger).to be_tagged("two")
    end

    it "removes any existing tags when reassigning" do
      tagger.tags = "one, two"

      tagger.tags = "three, four"

      expect(tagger).to_not be_tagged("one")
      expect(tagger).to_not be_tagged("two")
      expect(tagger).to be_tagged("three")
      expect(tagger).to be_tagged("four")
    end

    it "allows empty tags that are generated from :: separated tags" do
      tagger.tags = "one::::two::three"

      expect(tagger).to be_tagged("one")
      expect(tagger).to be_tagged("")
      expect(tagger).to be_tagged("two")
      expect(tagger).to be_tagged("three")
    end
  end
end
