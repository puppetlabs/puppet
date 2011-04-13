#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-02-12.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/util/constant_inflector'

describe Puppet::Util::ConstantInflector, "when converting file names to constants" do
  before do
    @inflector = Object.new
    @inflector.extend(Puppet::Util::ConstantInflector)
  end

  it "should capitalize terms" do
    @inflector.file2constant("file").should == "File"
  end

  it "should switch all '/' characters to double colons" do
    @inflector.file2constant("file/other").should == "File::Other"
  end

  it "should remove underscores and capitalize the proceeding letter" do
    @inflector.file2constant("file_other").should == "FileOther"
  end

  it "should correctly replace as many underscores as exist in the file name" do
    @inflector.file2constant("two_under_scores/with_some_more_underscores").should == "TwoUnderScores::WithSomeMoreUnderscores"
  end

  it "should collapse multiple underscores" do
    @inflector.file2constant("many___scores").should == "ManyScores"
  end

  it "should correctly handle file names deeper than two directories" do
    @inflector.file2constant("one_two/three_four/five_six").should == "OneTwo::ThreeFour::FiveSix"
  end
end

describe Puppet::Util::ConstantInflector, "when converting constnats to file names" do
  before do
    @inflector = Object.new
    @inflector.extend(Puppet::Util::ConstantInflector)
  end

  it "should convert them to a string if necessary" do
    @inflector.constant2file(Puppet::Util::ConstantInflector).should be_instance_of(String)
  end

  it "should accept string inputs" do
    @inflector.constant2file("Puppet::Util::ConstantInflector").should be_instance_of(String)
  end

  it "should downcase all terms" do
    @inflector.constant2file("Puppet").should == "puppet"
  end

  it "should convert '::' to '/'" do
    @inflector.constant2file("Puppet::Util::Constant").should == "puppet/util/constant"
  end

  it "should convert mid-word capitalization to an underscore" do
    @inflector.constant2file("OneTwo::ThreeFour").should == "one_two/three_four"
  end

  it "should correctly handle constants with more than two parts" do
    @inflector.constant2file("OneTwoThree::FourFiveSixSeven").should == "one_two_three/four_five_six_seven"
  end
end
