#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:selmodule), "when validating attributes" do
  [:name, :selmoduledir, :selmodulepath].each do |param|
    it "should have a #{param} parameter" do
      Puppet::Type.type(:selmodule).attrtype(param).should == :param
    end
  end

  [:ensure, :syncversion].each do |param|
    it "should have a #{param} property" do
      Puppet::Type.type(:selmodule).attrtype(param).should == :property
    end
  end
end

