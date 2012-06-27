#!/usr/bin/env rspec

require 'spec_helper'

require 'puppet/file_serving/content'

describe Puppet::FileServing::Content do
  it_should_behave_like "a file_serving model"
end
