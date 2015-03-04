#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:selmodule), "when validating attributes" do
  [:name, :selmoduledir, :selmodulepath].each do |param|
    it "should have a #{param} parameter" do
      expect(Puppet::Type.type(:selmodule).attrtype(param)).to eq(:param)
    end
  end

  [:ensure, :syncversion].each do |param|
    it "should have a #{param} property" do
      expect(Puppet::Type.type(:selmodule).attrtype(param)).to eq(:property)
    end
  end
end

