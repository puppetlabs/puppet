#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/json'

class JsonUtil
    include Puppet::Util::Json
end

describe Puppet::Util::Json do
    it "should fail if no data is provided" do
        lambda { JsonUtil.new.json_create("json_class" => "foo") }.should raise_error(ArgumentError)
    end

    it "should call 'from_json' with the provided data" do
        json = JsonUtil.new
        json.expects(:from_json).with("mydata")
        json.json_create("json_class" => "foo", "data" => "mydata")
    end
end
