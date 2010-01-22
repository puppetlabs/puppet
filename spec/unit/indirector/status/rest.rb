#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/indirector/status/rest'

describe Puppet::Indirector::Status::Rest do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::Indirector::Status::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
