#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/terminus_helper'

class TerminusHelperIntegrationTester
  include Puppet::FileServing::TerminusHelper
  def model
    Puppet::FileServing::Metadata
  end
end

describe Puppet::FileServing::TerminusHelper do
  it "should be able to recurse on a single file" do
    @path = Tempfile.new("fileset_integration")
    request = Puppet::Indirector::Request.new(:metadata, :find, @path.path, nil, :recurse => true)

    tester = TerminusHelperIntegrationTester.new
    expect { tester.path2instances(request, @path.path) }.not_to raise_error
  end
end
