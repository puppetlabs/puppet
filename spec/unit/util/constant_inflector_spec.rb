#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/constant_inflector'

describe Puppet::Util::ConstantInflector, "when converting file names to constants" do
  it "should capitalize terms" do
    expect(subject.file2constant("file")).to eq("File")
  end

  it "should switch all '/' characters to double colons" do
    expect(subject.file2constant("file/other")).to eq("File::Other")
  end

  it "should remove underscores and capitalize the proceeding letter" do
    expect(subject.file2constant("file_other")).to eq("FileOther")
  end

  it "should correctly replace as many underscores as exist in the file name" do
    expect(subject.file2constant("two_under_scores/with_some_more_underscores")).to eq("TwoUnderScores::WithSomeMoreUnderscores")
  end

  it "should collapse multiple underscores" do
    expect(subject.file2constant("many___scores")).to eq("ManyScores")
  end

  it "should correctly handle file names deeper than two directories" do
    expect(subject.file2constant("one_two/three_four/five_six")).to eq("OneTwo::ThreeFour::FiveSix")
  end
end

describe Puppet::Util::ConstantInflector, "when converting constnats to file names" do
  it "should convert them to a string if necessary" do
    expect(subject.constant2file(Puppet::Util::ConstantInflector)).to be_instance_of(String)
  end

  it "should accept string inputs" do
    expect(subject.constant2file("Puppet::Util::ConstantInflector")).to be_instance_of(String)
  end

  it "should downcase all terms" do
    expect(subject.constant2file("Puppet")).to eq("puppet")
  end

  it "should convert '::' to '/'" do
    expect(subject.constant2file("Puppet::Util::Constant")).to eq("puppet/util/constant")
  end

  it "should convert mid-word capitalization to an underscore" do
    expect(subject.constant2file("OneTwo::ThreeFour")).to eq("one_two/three_four")
  end

  it "should correctly handle constants with more than two parts" do
    expect(subject.constant2file("OneTwoThree::FourFiveSixSeven")).to eq("one_two_three/four_five_six_seven")
  end
end
