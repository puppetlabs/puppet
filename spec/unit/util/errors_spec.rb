#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/errors'

class ErrorTester
  include Puppet::Util::Errors
  attr_accessor :line, :file
end

describe Puppet::Util::Errors do
  before do
    @tester = ErrorTester.new
  end

  it "should provide a 'fail' method" do
    expect(@tester).to respond_to(:fail)
  end

  it "should provide a 'devfail' method" do
    expect(@tester).to respond_to(:devfail)
  end

  it "should raise any provided error when failing" do
    expect { @tester.fail(Puppet::ParseError, "stuff") }.to raise_error(Puppet::ParseError)
  end

  it "should default to Puppet::Error when failing" do
    expect { @tester.fail("stuff") }.to raise_error(Puppet::Error)
  end

  it "should have a method for converting error context into a string" do
    @tester.file = "/my/file"
    @tester.line = 50
    expect(@tester.error_context).to eq(" at /my/file:50")
  end
end
