#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/file_serving/content'
require 'shared_behaviours/file_serving'

describe Puppet::FileServing::Content, " when finding files" do
  it_should_behave_like "Puppet::FileServing::Files"

  before do
    @test_class = Puppet::FileServing::Content
    @indirection = Puppet::FileServing::Content.indirection
  end
end
