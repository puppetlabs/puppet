#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Util::Execution do
  include Puppet::Util::Execution
  describe "#withenv" do
    before :each do
      @original_path = ENV["PATH"]
      @new_env = {:PATH => "/some/bogus/path"}
    end

    it "should change environment variables within the block then reset environment variables to their original values" do
      withenv @new_env do
        ENV["PATH"].should == "/some/bogus/path"
      end
      ENV["PATH"].should == @original_path
    end

    it "should reset environment variables to their original values even if the block fails" do
      begin
        withenv @new_env do
          ENV["PATH"].should == "/some/bogus/path"
          raise "This is a failure"
        end
      rescue
      end
      ENV["PATH"].should == @original_path
    end

    it "should reset environment variables even when they are set twice" do
      # Setting Path & Environment parameters in Exec type can cause weirdness
      @new_env["PATH"] = "/someother/bogus/path"
      withenv @new_env do
        # When assigning duplicate keys, can't guarantee order of evaluation
        ENV["PATH"].should =~ /\/some.*\/bogus\/path/
      end
      ENV["PATH"].should == @original_path
    end

    it "should remove any new environment variables after the block ends" do
      @new_env[:FOO] = "bar"
      withenv @new_env do
        ENV["FOO"].should == "bar"
      end
      ENV["FOO"].should == nil
    end
  end
end
