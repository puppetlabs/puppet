#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'puppet/settings/value_translator'

describe Puppet::Settings::ValueTranslator do
  let(:translator) { Puppet::Settings::ValueTranslator.new }

  context "booleans" do
    it "translates strings representing booleans to booleans" do
      translator['true'].should == true
      translator['false'].should == false
    end

    it "translates boolean values into themselves" do
      translator[true].should == true
      translator[false].should == false
    end

    it "leaves a boolean string with whitespace as a string" do
      translator[' true'].should == " true"
      translator['true '].should == "true"

      translator[' false'].should == " false"
      translator['false '].should == "false"
    end
  end

  context "numbers" do
    it "translates integer strings to integers" do
      translator["1"].should == 1
      translator["2"].should == 2
    end

    it "translates numbers starting with a 0 as octal" do
      translator["011"].should == 9
    end

    it "leaves hex numbers as strings" do
      translator["0x11"].should == "0x11"
    end
  end

  context "arbitrary strings" do
    it "translates an empty string as the empty string" do
      translator[""].should == ""
    end


    it "strips double quotes" do
      translator['"a string"'].should == 'a string'
    end

    it "strips single quotes" do
      translator["'a string'"].should == "a string"
    end

    it "does not strip preceeding whitespace" do
      translator[" \ta string"].should == " \ta string"
    end

    it "strips trailing whitespace" do
      translator["a string\t "].should == "a string"
    end

    it "leaves leading quote that is preceeded by whitespace" do
      translator[" 'a string'"].should == " 'a string"
    end

    it "leaves trailing quote that is succeeded by whitespace" do
      translator["'a string' "].should == "a string'"
    end

    it "leaves quotes that are not at the beginning or end of the string" do
      translator["a st'\"ring"].should == "a st'\"ring"
    end
  end
end
