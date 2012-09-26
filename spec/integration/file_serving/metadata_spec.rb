#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/metadata'

describe Puppet::FileServing::Metadata do
  it_should_behave_like "a file_serving model"
end

