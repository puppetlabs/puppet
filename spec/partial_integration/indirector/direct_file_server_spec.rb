require 'spec_helper'
require 'matchers/include'

require 'puppet/indirector/file_content/file'
require 'puppet/indirector/file_metadata/file'

describe Puppet::Indirector::DirectFileServer, " when interacting with the filesystem and the model" do
  include PuppetSpec::Files

  before do
    # We just test a subclass, since it's close enough.
    @terminus = Puppet::Indirector::FileContent::File.new
  end

  it "should return an instance of the model" do
    filepath = make_absolute("/path/to/my/file")
    Puppet::FileSystem.expects(:exist?).with(filepath).returns(true)

    expect(@terminus.find(@terminus.indirection.request(:find, Puppet::Util.path_to_uri(filepath).to_s, nil))).to be_instance_of(Puppet::FileServing::Content)
  end

  it "should return an instance capable of returning its content" do
    filename = file_containing("testfile", "my content")

    instance = @terminus.find(@terminus.indirection.request(:find, Puppet::Util.path_to_uri(filename).to_s, nil))

    expect(instance.content).to eq("my content")
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
    request = terminus.indirection.request(:search, Puppet::Util.path_to_uri(path).to_s, nil, :recurse => true)

    expect(terminus.search(request)).to include_in_any_order(
      file_with_content(File.join(path, "one"), "one content"),
      file_with_content(File.join(path, "two"), "two content"),
      directory_named(path))
  end
end

describe Puppet::Indirector::DirectFileServer, " when interacting with filesystem metadata" do
  include PuppetSpec::Files
  include_context 'with supported checksum types'

  before do
    @terminus = Puppet::Indirector::FileMetadata::File.new
  end

  with_checksum_types("file_metadata", "testfile") do
    it "should return the correct metadata" do
      request = @terminus.indirection.request(:find, Puppet::Util.path_to_uri(checksum_file).to_s, nil, :checksum_type => checksum_type)
      result = @terminus.find(request)
      expect_correct_checksum(result, checksum_type, checksum, Puppet::FileServing::Metadata)
    end
  end

  with_checksum_types("direct_file_server_testing", "testfile") do
    it "search of FileServing::Fileset should return the correct metadata" do
      request = @terminus.indirection.request(:search, Puppet::Util.path_to_uri(env_path).to_s, nil, :recurse => true, :checksum_type => checksum_type)
      result = @terminus.search(request)

      expect(result).to_not be_nil
      expect(result.length).to eq(2)
      file, dir = result.partition {|x| x.relative_path == 'testfile'}
      expect(file.length).to eq(1)
      expect(dir.length).to eq(1)
      expect_correct_checksum(dir[0], 'ctime', "#{CHECKSUM_STAT_TIME}", Puppet::FileServing::Metadata)
      expect_correct_checksum(file[0], checksum_type, checksum, Puppet::FileServing::Metadata)
    end
  end
end
