#!/usr/bin/env ruby"

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet'

describe Puppet do
    Puppet::Util::Log.eachlevel do |level|
        it "should have a method for sending '#{level}' logs" do
            Puppet.should respond_to(level)
        end
    end
end
