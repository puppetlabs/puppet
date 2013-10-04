#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_content/selector'

describe Puppet::Indirector::FileContent::Selector do
  include PuppetSpec::Files

  it_should_behave_like "Puppet::FileServing::Files", :file_content
end
