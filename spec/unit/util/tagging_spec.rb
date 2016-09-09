#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/tagging'

describe Puppet::Util::Tagging do
  let(:tagger) { Object.new.extend(Puppet::Util::Tagging) }

  it "should add tags to the returned tag list" do
    tagger.tag("one")
    expect(tagger.tags).to include("one")
  end

  it "should return a duplicate of the tag list, rather than the original" do
    tagger.tag("one")
    tags = tagger.tags
    tags << "two"
    expect(tagger.tags).to_not include("two")
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

  it "should allow alpha tags" do
    expect { tagger.tag("good_tag") }.not_to raise_error
  end

  it "should allow tags containing '.' characters" do
    expect { tagger.tag("good.tag") }.to_not raise_error
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
