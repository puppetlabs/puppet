#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/indirector/resource/rest'

describe Puppet::Resource::Rest do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::Resource::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
