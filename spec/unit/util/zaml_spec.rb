#!/usr/bin/env rspec
# encoding: UTF-8
#
# The above encoding line is a magic comment to set the default source encoding
# of this file for the Ruby interpreter.  It must be on the first or second
# line of the file if an interpreter is in use.  In Ruby 1.9 and later, the
# source encoding determines the encoding of String and Regexp objects created
# from this source file.  This explicit encoding is important becuase otherwise
# Ruby will pick an encoding based on LANG or LC_CTYPE environment variables.
# These may be different from site to site so it's important for us to
# establish a consistent behavior.  For more information on M17n please see:
# http://links.puppetlabs.com/understanding_m17n

require 'spec_helper'

require 'puppet/util/monkey_patches'

describe "Pure ruby yaml implementation" do
  {
  7            => "--- 7",
  3.14159      => "--- 3.14159",
  'test'       => "--- test",
  []           => "--- []",
  :symbol      => "--- !ruby/sym symbol",
  {:a => "A"}  => "--- \n  !ruby/sym a: A",
  {:a => "x\ny"} => "--- \n  !ruby/sym a: |-\n    x\n    y" 
  }.each { |o,y|
    it "should convert the #{o.class} #{o.inspect} to yaml" do
      o.to_yaml.should == y
    end
    it "should produce yaml for the #{o.class} #{o.inspect} that can be reconstituted" do
      YAML.load(o.to_yaml).should == o
    end
  }
  #
  # Can't test for equality on raw objects
  {
  Object.new                   => "--- !ruby/object {}",
  [Object.new]                 => "--- \n  - !ruby/object {}",
  {Object.new => Object.new}   => "--- \n  ? !ruby/object {}\n  : !ruby/object {}"
  }.each { |o,y|
    it "should convert the #{o.class} #{o.inspect} to yaml" do
      o.to_yaml.should == y
    end
    it "should produce yaml for the #{o.class} #{o.inspect} that can be reconstituted" do
      lambda { YAML.load(o.to_yaml) }.should_not raise_error
    end
  }

  it "should emit proper labels and backreferences for common objects" do
    # Note: this test makes assumptions about the names ZAML chooses
    # for labels.
    x = [1, 2]
    y = [3, 4]
    z = [x, y, x, y]
    z.to_yaml.should == "--- \n  - &id001\n    - 1\n    - 2\n  - &id002\n    - 3\n    - 4\n  - *id001\n  - *id002"
    z2 = YAML.load(z.to_yaml)
    z2.should == z
    z2[0].should equal(z2[2])
    z2[1].should equal(z2[3])
  end

  it "should emit proper labels and backreferences for recursive objects" do
    x = [1, 2]
    x << x
    x.to_yaml.should == "--- &id001\n  \n  - 1\n  - 2\n  - *id001"
    x2 = YAML.load(x.to_yaml)
    x2.should be_a(Array)
    x2.length.should == 3
    x2[0].should == 1
    x2[1].should == 2
    x2[2].should equal(x2)
  end
end

# Note, many of these tests will pass on Ruby 1.8 but fail on 1.9 if the patch
# fix is not applied to Puppet or there's a regression.  These version
# dependant failures are intentional since the string encoding behavior changed
# significantly in 1.9.
describe "UTF-8 encoded String#to_yaml (Bug #11246)" do
  # JJM All of these snowmen are different representations of the same
  # UTF-8 encoded string.
  let(:snowman)         { 'Snowman: [☃]' }
  let(:snowman_escaped) { "Snowman: [\xE2\x98\x83]" }

  describe "UTF-8 String Literal" do
    subject { snowman }

    it "should serialize to YAML" do
      subject.to_yaml
    end
    it "should serialize and deserialize to the same thing" do
      YAML.load(subject.to_yaml).should == subject
    end
    it "should serialize and deserialize to a String compatible with a UTF-8 encoded Regexp" do
      YAML.load(subject.to_yaml).should =~ /☃/u
    end
  end
end
