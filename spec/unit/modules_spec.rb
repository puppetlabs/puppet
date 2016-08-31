#!/usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Modules do
  it 'should exist' do
    Puppet.const_defined?("Modules").should be_true
  end
  it 'should be a Module' do
    subject.class.should be_a Module
  end
  it 'should block Puppet::Modules as a Class' do
    lambda { module Puppet; class Modules; end; end; }.should raise_error TypeError, /Modules is not a class/
  end
  it 'should allow monkey patching' do
    module Puppet
      module Modules
        def self.monkey_patch1
          "bar"
        end
      end
    end
    Puppet::Modules.monkey_patch1.should eq "bar"
  end
end
