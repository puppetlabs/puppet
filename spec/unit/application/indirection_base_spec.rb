#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/indirection_base'

describe Puppet::Application::IndirectionBase do
  it "should support a 'terminus' accessor" do
    test = subject
    expect { test.terminus = :foo }.should_not raise_error
    test.terminus.should == :foo
  end

  it "should have a 'terminus' CLI option" do
    subject.class.option_parser_commands.select do |options, function|
      options.index { |o| o =~ /terminus/ }
    end.should_not be_empty
  end

  describe "setup" do
    it "should fail if its string does not support an indirection"
  end
end
