#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/file_serving/metadata'
require 'shared_behaviours/file_serving'
require 'puppet/indirector/file_metadata/file_server'

describe Puppet::FileServing::Metadata, " when finding files" do
  it_should_behave_like "Puppet::FileServing::Files"

  before do
    @test_class = Puppet::FileServing::Metadata
    @indirection = Puppet::FileServing::Metadata.indirection
  end
end
