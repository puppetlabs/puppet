#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:instrumentation_data, '0.0.1'] do
  it_should_behave_like "an indirector face"
end
