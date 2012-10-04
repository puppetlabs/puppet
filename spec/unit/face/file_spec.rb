#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:file, '0.0.1'] do
  it_should_behave_like "an indirector face"

  [:download, :store].each do |action|
    it { should be_action action }
    it { should respond_to action }
  end
end
