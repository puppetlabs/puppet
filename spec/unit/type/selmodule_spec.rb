#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

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

