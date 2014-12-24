#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'puppet/settings/value_translator'

describe Puppet::Settings::ValueTranslator do
  let(:translator) { Puppet::Settings::ValueTranslator.new }

  context "booleans" do
    it "translates strings representing booleans to booleans" do
      expect(translator['true']).to eq(true)
      expect(translator['false']).to eq(false)
    end

    it "translates boolean values into themselves" do
      expect(translator[true]).to eq(true)
      expect(translator[false]).to eq(false)
    end

    it "leaves a boolean string with whitespace as a string" do
      expect(translator[' true']).to eq(" true")
      expect(translator['true ']).to eq("true")

      expect(translator[' false']).to eq(" false")
      expect(translator['false ']).to eq("false")
    end
  end

  context "numbers" do
    it "translates integer strings to integers" do
      expect(translator["1"]).to eq(1)
      expect(translator["2"]).to eq(2)
    end

    it "translates numbers starting with a 0 as octal" do
      expect(translator["011"]).to eq(9)
    end

    it "leaves hex numbers as strings" do
      expect(translator["0x11"]).to eq("0x11")
    end
  end

  context "arbitrary strings" do
    it "translates an empty string as the empty string" do
      expect(translator[""]).to eq("")
    end


    it "strips double quotes" do
      expect(translator['"a string"']).to eq('a string')
    end

    it "strips single quotes" do
      expect(translator["'a string'"]).to eq("a string")
    end

    it "does not strip preceding whitespace" do
      expect(translator[" \ta string"]).to eq(" \ta string")
    end

    it "strips trailing whitespace" do
      expect(translator["a string\t "]).to eq("a string")
    end

    it "leaves leading quote that is preceded by whitespace" do
      expect(translator[" 'a string'"]).to eq(" 'a string")
    end

    it "leaves trailing quote that is succeeded by whitespace" do
      expect(translator["'a string' "]).to eq("a string'")
    end

    it "leaves quotes that are not at the beginning or end of the string" do
      expect(translator["a st'\"ring"]).to eq("a st'\"ring")
    end
  end
end
