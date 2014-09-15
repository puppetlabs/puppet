#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:facts, '0.0.1'] do
  describe "#find" do
    it { should be_action :find }

    it "should fail without a key" do
      expect { subject.find }.to raise_error ArgumentError, /wrong number of arguments/
    end
  end
end
