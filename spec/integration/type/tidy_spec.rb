#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'
require 'puppet/file_bucket/dipper'

describe Puppet::Type.type(:tidy) do
  include PuppetSpec::Files

  before do
    Puppet::Util::Storage.stubs(:store)
  end

  # Testing #355.
  it "should be able to remove dead links", :if => Puppet.features.manages_symlinks? do
    dir = tmpfile("tidy_link_testing")
    link = File.join(dir, "link")
    target = tmpfile("no_such_file_tidy_link_testing")
    Dir.mkdir(dir)
    Puppet::FileSystem.symlink(target, link)

    tidy = Puppet::Type.type(:tidy).new :path => dir, :recurse => true

    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource(tidy)
    # avoid crude failures because of nil resources that result
    # from implicit containment and lacking containers
    catalog.stubs(:container_of).returns tidy

    catalog.apply

    Puppet::FileSystem.symlink?(link).should be_false
  end
end
