#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_content/file'

describe Puppet::Indirector::DirectFileServer, " when interacting with the filesystem and the model" do
  include PuppetSpec::Files

  before do
    # We just test a subclass, since it's close enough.
    @terminus = Puppet::Indirector::FileContent::File.new

    @filepath = make_absolute("/path/to/my/file")
  end

  it "should return an instance of the model" do
    pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
      FileTest.expects(:exists?).with(@filepath).returns(true)

      @terminus.find(@terminus.indirection.request(:find, "file://host#{@filepath}", nil)).should be_instance_of(Puppet::FileServing::Content)
    end
  end

  it "should return an instance capable of returning its content" do
    pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
      filename = file_containing("testfile", "my content")

      instance = @terminus.find(@terminus.indirection.request(:find, "file://host#{filename}", nil))

      instance.content.should == "my content"
    end
  end
end

describe Puppet::Indirector::DirectFileServer, " when interacting with FileServing::Fileset and the model" do
  include PuppetSpec::Files

  let(:path) { tmpdir('direct_file_server_testing') }

  before do
    @terminus = Puppet::Indirector::FileContent::File.new

    File.open(File.join(path, "one"), "w") { |f| f.print "one content" }
    File.open(File.join(path, "two"), "w") { |f| f.print "two content" }

    @request = @terminus.indirection.request(:search, "file:///#{path}", nil, :recurse => true)
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
      when path
      else
        raise "No valid key for #{instance.path.inspect}"
      end
    end
  end
end
