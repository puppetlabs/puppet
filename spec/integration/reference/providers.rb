#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/reference'

reference = Puppet::Util::Reference.reference(:providers)

describe reference do
    it "should exist" do
        reference.should_not be_nil
    end

    it "should be able to be rendered as text" do
        lambda { reference.to_text }.should_not raise_error
    end
end
