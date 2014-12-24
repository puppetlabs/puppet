#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:file, '0.0.1'] do
  [:download, :store, :find, :info, :save].each do |action|
    it { is_expected.to be_action action }
    it { is_expected.to respond_to action }
  end
end
