#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:instrumentation_data, '0.0.1'] do
  it_should_behave_like "an indirector face"
end
