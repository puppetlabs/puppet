#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::Functions do
  before :each do
    Puppet::Parser::Functions.rmfunction("template") if Puppet::Parser::Functions.functions.include?("template")
  end

  it "should support multiple threads autoloading the same function" do
    threads = []
    lambda {
      10.times { |a|
        threads << Thread.new {
          Puppet::Parser::Functions.function("template")
        }
      }
    }.should_not raise_error
    threads.each { |t| t.join }
  end
end
