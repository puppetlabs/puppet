#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Status do
    it "should implement find" do
        Puppet::Status.find( :default ).should be_is_a(Puppet::Status)
        Puppet::Status.find( :default ).status["is_alive"].should == true
    end

    it "should default to is_alive is true" do
        Puppet::Status.new.status["is_alive"].should == true
    end

    it "should return a pson hash" do
        Puppet::Status.new.status.to_pson.should == '{"is_alive":true}'
    end

    it "should accept a hash from pson" do
        status = Puppet::Status.new( { "is_alive" => false } )
        status.status.should == { "is_alive" => false }
    end

    it "should have a name" do
        Puppet::Status.new.name
    end

    it "should allow a name to be set" do
        Puppet::Status.new.name = "status"
    end
end
