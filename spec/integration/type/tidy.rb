#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:tidy) do
    def tmpfile(name)
        source = Tempfile.new(name)
        path = source.path
        source.close!
        path
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
