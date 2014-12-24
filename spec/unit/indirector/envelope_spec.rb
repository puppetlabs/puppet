#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector/envelope'

describe Puppet::Indirector::Envelope do
  before do
    @instance = Object.new
    @instance.extend(Puppet::Indirector::Envelope)
  end

  describe "when testing if it is expired" do
    it "should return false if there is no expiration set" do
      expect(@instance).not_to be_expired
    end

    it "should return true if the current date is after the expiration date" do
      @instance.expiration = Time.now - 10
      expect(@instance).to be_expired
    end

    it "should return false if the current date is prior to the expiration date" do
      @instance.expiration = Time.now + 10
      expect(@instance).not_to be_expired
    end

    it "should return false if the current date is equal to the expiration date" do
      now = Time.now
      Time.stubs(:now).returns(now)
      @instance.expiration = now
      expect(@instance).not_to be_expired
    end
  end
end
