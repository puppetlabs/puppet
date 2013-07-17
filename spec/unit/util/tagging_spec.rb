#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/tagging'

describe Puppet::Util::Tagging, "when adding tags" do
  before do
    @tagger = Object.new
    @tagger.extend(Puppet::Util::Tagging)
  end

  it "should have a method for adding tags" do
    @tagger.should be_respond_to(:tag)
  end

  it "should have a method for returning all tags" do
    @tagger.should be_respond_to(:tags)
  end

  it "should add tags to the returned tag list" do
    @tagger.tag("one")
    @tagger.tags.should be_include("one")
  end

  it "should not add duplicate tags to the returned tag list" do
    @tagger.tag("one")
    @tagger.tag("one")
    @tagger.tags.should == ["one"]
  end

  it "should return a duplicate of the tag list, rather than the original" do
    @tagger.tag("one")
    tags = @tagger.tags
    tags << "two"
    @tagger.tags.should_not be_include("two")
  end

  it "should add all provided tags to the tag list" do
    @tagger.tag("one", "two")
    @tagger.tags.should be_include("one")
    @tagger.tags.should be_include("two")
  end

  it "should fail on tags containing '*' characters" do
    expect { @tagger.tag("bad*tag") }.to raise_error(Puppet::ParseError)
  end

  it "should fail on tags starting with '-' characters" do
    expect { @tagger.tag("-badtag") }.to raise_error(Puppet::ParseError)
  end

  it "should fail on tags containing ' ' characters" do
    expect { @tagger.tag("bad tag") }.to raise_error(Puppet::ParseError)
  end

  it "should allow alpha tags" do
    expect { @tagger.tag("good_tag") }.to_not raise_error
  end

  it "should allow tags containing '.' characters" do
    expect { @tagger.tag("good.tag") }.to_not raise_error
  end

  it "should add qualified classes as tags" do
    @tagger.tag("one::two")
    @tagger.tags.should be_include("one::two")
  end

  it "should add each part of qualified classes as tags" do
    @tagger.tag("one::two::three")
    @tagger.tags.should be_include("one")
    @tagger.tags.should be_include("two")
    @tagger.tags.should be_include("three")
  end

  it "should indicate when the object is tagged with a provided tag" do
    @tagger.tag("one")
    @tagger.should be_tagged("one")
  end

  it "should indicate when the object is not tagged with a provided tag" do
    @tagger.should_not be_tagged("one")
  end

  it "should indicate when the object is tagged with any tag in an array" do
    @tagger.tag("one")
    @tagger.should be_tagged("one","two","three")
  end

  it "should indicate when the object is not tagged with any tag in an array" do
    @tagger.tag("one")
    @tagger.should_not be_tagged("two","three")
  end
end
