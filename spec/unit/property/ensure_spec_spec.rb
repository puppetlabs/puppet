#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/property/ensure'

klass = Puppet::Property::Ensure

describe klass do
    it "should be a subclass of Property" do
        klass.superclass.must == Puppet::Property
    end
end
