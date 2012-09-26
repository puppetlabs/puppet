#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_metadata/selector'

describe Puppet::Indirector::FileMetadata::Selector do
  include PuppetSpec::Files

  it_should_behave_like "Puppet::FileServing::Files", :file_metadata
end

