#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::Functions do
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
