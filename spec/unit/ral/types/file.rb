#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'tempfile'

describe Puppet::type(:file), " when used with replace=>false and content" do

    before do
        @path = Tempfile.new("puppetspec")
        @path.close!()
        @path = @path.path
        @file = Puppet::type(:file).create( { :name => @path, :content => "foo", :replace => :false } )
    end

    after do
    end

    it "should be insync if the file exists and the content is different" do
        File.open(@path, "w") do |f| f.puts "bar" end
        @file.property(:content).insync?("bar").should be_true
    end

    it "should be insync if the file exists and the content is right" do
        File.open(@path, "w") do |f| f.puts "foo" end
        @file.property(:content).insync?("foo").should be_true
    end

    it "should not be insync if the file doesnot exist" do
        @file.property(:content).insync?(:nil).should be_false
    end

end
