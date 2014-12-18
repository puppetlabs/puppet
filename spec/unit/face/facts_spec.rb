#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:facts, '0.0.1'] do
  describe "#find" do
    it { should be_action :find }
  end
end
