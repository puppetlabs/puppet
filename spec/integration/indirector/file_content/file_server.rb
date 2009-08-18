#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_content/file_server'
require 'shared_behaviours/file_server_terminus'

require 'puppet_spec/files'

describe Puppet::Indirector::FileContent::FileServer, " when finding files" do
    it_should_behave_like "Puppet::Indirector::FileServerTerminus"
    include PuppetSpec::Files

    before do
        @terminus = Puppet::Indirector::FileContent::FileServer.new
        @test_class = Puppet::FileServing::Content
    end

    it "should find file content in the environment specified in the request" do
        path = tmpfile("file_content_with_env")

        Dir.mkdir(path)

        modpath = File.join(path, "mod")
        FileUtils.mkdir_p(File.join(modpath, "lib"))
        file = File.join(modpath, "lib", "file.rb")
        File.open(file, "w") { |f| f.puts "1" }

        env = Puppet::Node::Environment.new("foo")
        env.stubs(:modulepath).returns [path]
        Puppet.settings[:modulepath] = "/no/such/file"

        result = Puppet::FileServing::Content.search("plugins", :environment => "foo", :recurse => true)

        result.should_not be_nil
        result.length.should == 2
        result[1].should be_instance_of(Puppet::FileServing::Content)
        result[1].content.should == "1\n"
    end
end
