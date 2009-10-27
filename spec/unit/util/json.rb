#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/pson'

class PsonUtil
    include Puppet::Util::Pson
end

describe Puppet::Util::Pson do
    it "should fail if no data is provided" do
        lambda { PsonUtil.new.pson_create("type" => "foo") }.should raise_error(ArgumentError)
    end

    it "should call 'from_pson' with the provided data" do
        pson = PsonUtil.new
        pson.expects(:from_pson).with("mydata")
        pson.pson_create("type" => "foo", "data" => "mydata")
    end
end
