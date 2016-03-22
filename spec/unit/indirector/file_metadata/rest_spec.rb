#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_metadata'
require 'puppet/indirector/file_metadata/rest'

describe "Puppet::Indirector::Metadata::Rest" do
  it "should add the node's cert name to the arguments"

  it "should use the :fileserver SRV service" do
    expect(Puppet::Indirector::FileMetadata::Rest.srv_service).to eq(:fileserver)
  end
end
