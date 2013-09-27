#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/package'

describe "Base Puppet::Provider::Package" do

  let(:resource) { stub 'resource', :[] => [ 'package1', 'package2' ]}
  let(:provider) { Puppet::Provider::Package.new(resource) }

  describe "querying" do
    it "raises if query a resource with an array of names (#22557)" do
      expect { provider.query }.to raise_error(Puppet::ResourceError, /package provider.*cannot query.*with multiple names/i)
    end
  end
end
