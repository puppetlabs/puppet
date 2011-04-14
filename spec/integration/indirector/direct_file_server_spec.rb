#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/indirector/file_content/file'

describe Puppet::Indirector::DirectFileServer, " when interacting with the filesystem and the model" do
  before do
    # We just test a subclass, since it's close enough.
    @terminus = Puppet::Indirector::FileContent::File.new

    @filepath = "/path/to/my/file"
  end

  it "should return an instance of the model" do
    FileTest.expects(:exists?).with(@filepath).returns(true)

    @terminus.find(@terminus.indirection.request(:find, "file://host#{@filepath}")).should be_instance_of(Puppet::FileServing::Content)
  end

  it "should return an instance capable of returning its content" do
    FileTest.expects(:exists?).with(@filepath).returns(true)
    File.stubs(:lstat).with(@filepath).returns(stub("stat", :ftype => "file"))
    File.expects(:read).with(@filepath).returns("my content")

    instance = @terminus.find(@terminus.indirection.request(:find, "file://host#{@filepath}"))

    instance.content.should == "my content"
  end
end

describe Puppet::Indirector::DirectFileServer, " when interacting with FileServing::Fileset and the model" do
  before do
    @terminus = Puppet::Indirector::FileContent::File.new

    @path = Tempfile.new("direct_file_server_testing")
    path = @path.path
    @path.close!
    @path = path

    Dir.mkdir(@path)
    File.open(File.join(@path, "one"), "w") { |f| f.print "one content" }
    File.open(File.join(@path, "two"), "w") { |f| f.print "two content" }

    @request = @terminus.indirection.request(:search, "file:///#{@path}", :recurse => true)
  end

  after do
    system("rm -rf #{@path}")
  end

  it "should return an instance for every file in the fileset" do
    result = @terminus.search(@request)
    result.should be_instance_of(Array)
    result.length.should == 3
    result.each { |r| r.should be_instance_of(Puppet::FileServing::Content) }
  end

  it "should return instances capable of returning their content" do
    @terminus.search(@request).each do |instance|
      case instance.full_path
      when /one/; instance.content.should == "one content"
      when /two/; instance.content.should == "two content"
      when @path
      else
        raise "No valid key for #{instance.path.inspect}"
      end
    end
  end
end
