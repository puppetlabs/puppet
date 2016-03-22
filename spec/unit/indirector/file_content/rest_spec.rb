#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_content/rest'

describe Puppet::Indirector::FileContent::Rest do
  it "should add the node's cert name to the arguments"

  it "should set the content type to text/plain"

  it "should use the :fileserver SRV service" do
    expect(Puppet::Indirector::FileContent::Rest.srv_service).to eq(:fileserver)
  end
end
