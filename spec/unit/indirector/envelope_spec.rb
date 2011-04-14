#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/indirector/envelope'

describe Puppet::Indirector::Envelope do
  before do
    @instance = Object.new
    @instance.extend(Puppet::Indirector::Envelope)
  end

  it "should have an expiration accessor" do
    @instance.expiration = "testing"
    @instance.expiration.should == "testing"
  end

  it "should have an expiration setter" do
    @instance.should respond_to(:expiration=)
  end

  it "should have a means of testing whether it is expired" do
    @instance.should respond_to(:expired?)
  end

  describe "when testing if it is expired" do
    it "should return false if there is no expiration set" do
      @instance.should_not be_expired
    end

    it "should return true if the current date is after the expiration date" do
      @instance.expiration = Time.now - 10
      @instance.should be_expired
    end

    it "should return false if the current date is prior to the expiration date" do
      @instance.expiration = Time.now + 10
      @instance.should_not be_expired
    end

    it "should return false if the current date is equal to the expiration date" do
      now = Time.now
      Time.stubs(:now).returns(now)
      @instance.expiration = now
      @instance.should_not be_expired
    end
  end
end
