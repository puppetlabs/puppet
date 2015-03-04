#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:facts, '0.0.1'] do
  describe "#find" do
    it { is_expected.to be_action :find }
  end
end
