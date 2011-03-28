#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/indirection_base'

describe Puppet::Application::IndirectionBase do
  it "should support a 'from' terminus"

  describe "setup" do
    it "should fail if its string does not support an indirection"
  end
end
