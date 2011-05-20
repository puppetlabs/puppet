#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet_spec/files'
require 'puppet/file_bucket/dipper'

describe Puppet::Type.type(:tidy) do
  include PuppetSpec::Files

  before do
    Puppet::Util::Storage.stubs(:store)
  end

  # Testing #355.
  it "should be able to remove dead links" do
    dir = tmpfile("tidy_link_testing")
    link = File.join(dir, "link")
    target = tmpfile("no_such_file_tidy_link_testing")
    Dir.mkdir(dir)
    File.symlink(target, link)

    tidy = Puppet::Type.type(:tidy).new :path => dir, :recurse => true

    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource(tidy)

    catalog.apply

    FileTest.should_not be_symlink(link)
  end
end
