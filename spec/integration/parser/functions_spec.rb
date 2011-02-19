#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Puppet::Parser::Functions do
  before :each do
    Puppet::Parser::Functions.rmfunction("template") if Puppet::Parser::Functions.function("template")
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