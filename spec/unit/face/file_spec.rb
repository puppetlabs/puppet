#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:file, '0.0.1'] do
  [:download, :store, :find, :info, :save].each do |action|
    it { should be_action action }
    it { should respond_to action }
  end
end
