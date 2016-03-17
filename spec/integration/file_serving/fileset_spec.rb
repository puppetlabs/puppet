#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/fileset'

describe Puppet::FileServing::Fileset do
  it "should be able to recurse on a single file" do
    @path = Tempfile.new("fileset_integration")

    fileset = Puppet::FileServing::Fileset.new(@path.path)
    expect { fileset.files }.not_to raise_error
  end
end
