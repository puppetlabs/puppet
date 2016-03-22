require 'spec_helper'
require 'matchers/include'

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
      Puppet::FileSystem.expects(:exist?).with(@filepath).returns(true)

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
  include Matchers::Include

  matcher :file_with_content do |name, content|
    match do |actual|
      actual.full_path == name && actual.content == content
    end
  end

  matcher :directory_named do |name|
    match do |actual|
      actual.full_path == name
    end
  end

  it "should return an instance for every file in the fileset" do
    path = tmpdir('direct_file_server_testing')
    File.open(File.join(path, "one"), "w") { |f| f.print "one content" }
    File.open(File.join(path, "two"), "w") { |f| f.print "two content" }

    terminus = Puppet::Indirector::FileContent::File.new
    request = terminus.indirection.request(:search, "file:///#{path}", nil, :recurse => true)

    expect(terminus.search(request)).to include_in_any_order(
      file_with_content(File.join(path, "one"), "one content"),
      file_with_content(File.join(path, "two"), "two content"),
      directory_named(path))
  end
end
