#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/constant_inflector'

describe Puppet::Util::ConstantInflector, "when converting file names to constants" do
  it "should capitalize terms" do
    subject.file2constant("file").should == "File"
  end

  it "should switch all '/' characters to double colons" do
    subject.file2constant("file/other").should == "File::Other"
  end

  it "should remove underscores and capitalize the proceeding letter" do
    subject.file2constant("file_other").should == "FileOther"
  end

  it "should correctly replace as many underscores as exist in the file name" do
    subject.file2constant("two_under_scores/with_some_more_underscores").should == "TwoUnderScores::WithSomeMoreUnderscores"
  end

  it "should collapse multiple underscores" do
    subject.file2constant("many___scores").should == "ManyScores"
  end

  it "should correctly handle file names deeper than two directories" do
    subject.file2constant("one_two/three_four/five_six").should == "OneTwo::ThreeFour::FiveSix"
  end
end

describe Puppet::Util::ConstantInflector, "when converting constnats to file names" do
  it "should convert them to a string if necessary" do
    subject.constant2file(Puppet::Util::ConstantInflector).should be_instance_of(String)
  end

  it "should accept string inputs" do
    subject.constant2file("Puppet::Util::ConstantInflector").should be_instance_of(String)
  end

  it "should downcase all terms" do
    subject.constant2file("Puppet").should == "puppet"
  end

  it "should convert '::' to '/'" do
    subject.constant2file("Puppet::Util::Constant").should == "puppet/util/constant"
  end

  it "should convert mid-word capitalization to an underscore" do
    subject.constant2file("OneTwo::ThreeFour").should == "one_two/three_four"
  end

  it "should correctly handle constants with more than two parts" do
    subject.constant2file("OneTwoThree::FourFiveSixSeven").should == "one_two_three/four_five_six_seven"
  end
end
