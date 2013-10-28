#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/metadata'

# the json-schema gem doesn't support windows
if not Puppet.features.microsoft_windows?
  FILE_METADATA_SCHEMA = JSON.parse(File.read(File.join(File.dirname(__FILE__), '../../../api/schemas/file_metadata.json')))

  describe "catalog schema" do
    it "should validate against the json meta-schema" do
      JSON::Validator.validate!(JSON_META_SCHEMA, FILE_METADATA_SCHEMA)
    end
  end

  def validate_json_for_file_metadata(file_metadata)
    JSON::Validator.validate!(FILE_METADATA_SCHEMA, file_metadata.to_pson)
  end
end

describe Puppet::FileServing::Metadata do
  let(:foobar) { File.expand_path('/foo/bar') }

  it "should be a subclass of Base" do
    Puppet::FileServing::Metadata.superclass.should equal(Puppet::FileServing::Base)
  end

  it "should indirect file_metadata" do
    Puppet::FileServing::Metadata.indirection.name.should == :file_metadata
  end

  it "should have a method that triggers attribute collection" do
    Puppet::FileServing::Metadata.new(foobar).should respond_to(:collect)
  end

  it "should support pson serialization" do
    Puppet::FileServing::Metadata.new(foobar).should respond_to(:to_pson)
  end

  it "should support to_pson_data_hash" do
    Puppet::FileServing::Metadata.new(foobar).should respond_to(:to_pson_data_hash)
  end

  it "should support pson deserialization" do
    Puppet::FileServing::Metadata.should respond_to(:from_pson)
  end

  describe "when serializing" do
    let(:metadata) { Puppet::FileServing::Metadata.new(foobar) }

    it "should serialize as FileMetadata" do
      metadata.to_pson_data_hash['document_type'].should == "FileMetadata"
    end

    it "the data should include the path, relative_path, links, owner, group, mode, checksum, type, and destination" do
      metadata.to_pson_data_hash['data'].keys.sort.should == %w{ path relative_path links owner group mode checksum type destination }.sort
    end

    it "should pass the path in the hash verbatim" do
      metadata.to_pson_data_hash['data']['path'].should == metadata.path
    end

    it "should pass the relative_path in the hash verbatim" do
      metadata.to_pson_data_hash['data']['relative_path'].should == metadata.relative_path
    end

    it "should pass the links in the hash verbatim" do
      metadata.to_pson_data_hash['data']['links'].should == metadata.links
    end

    it "should pass the path owner in the hash verbatim" do
      metadata.to_pson_data_hash['data']['owner'].should == metadata.owner
    end

    it "should pass the group in the hash verbatim" do
      metadata.to_pson_data_hash['data']['group'].should == metadata.group
    end

    it "should pass the mode in the hash verbatim" do
      metadata.to_pson_data_hash['data']['mode'].should == metadata.mode
    end

    it "should pass the ftype in the hash verbatim as the 'type'" do
      metadata.to_pson_data_hash['data']['type'].should == metadata.ftype
    end

    it "should pass the destination verbatim" do
      metadata.to_pson_data_hash['data']['destination'].should == metadata.destination
    end

    it "should pass the checksum in the hash as a nested hash" do
      metadata.to_pson_data_hash['data']['checksum'].should be_is_a(Hash)
    end

    it "should pass the checksum_type in the hash verbatim as the checksum's type" do
      metadata.to_pson_data_hash['data']['checksum']['type'].should == metadata.checksum_type
    end

    it "should pass the checksum in the hash verbatim as the checksum's value" do
      metadata.to_pson_data_hash['data']['checksum']['value'].should == metadata.checksum
    end
  end
end

describe Puppet::FileServing::Metadata do
  include PuppetSpec::Files

  shared_examples_for "metadata collector" do
    let(:metadata) do
      data = described_class.new(path)
      data.collect
      data
    end

    describe "when collecting attributes" do
      describe "when managing files" do
        let(:path) { tmpfile('file_serving_metadata') }

        before :each do
          FileUtils.touch(path)
        end

        it "should set the owner to the file's current owner" do
          metadata.owner.should == owner
        end

        it "should set the group to the file's current group" do
          metadata.group.should == group
        end

        it "should set the mode to the file's masked mode" do
          set_mode(33261, path)

          metadata.mode.should == 0755
        end

        describe "#checksum" do
          let(:checksum) { Digest::MD5.hexdigest("some content\n") }

          before :each do
            File.open(path, "wb") {|f| f.print("some content\n")}
          end

          it "should default to a checksum of type MD5 with the file's current checksum" do
            metadata.checksum.should == "{md5}#{checksum}"
          end

          it "should give a mtime checksum when checksum_type is set" do
            time = Time.now
            metadata.checksum_type = "mtime"
            metadata.expects(:mtime_file).returns(@time)
            metadata.collect
            metadata.checksum.should == "{mtime}#{@time}"
          end
        end

        it "should validate against the schema", :unless => Puppet.features.microsoft_windows? do
          validate_json_for_file_metadata(metadata)
        end
      end

      describe "when managing directories" do
        let(:path) { tmpdir('file_serving_metadata_dir') }
        let(:time) { Time.now }

        before :each do
          metadata.expects(:ctime_file).returns(time)
        end

        it "should only use checksums of type 'ctime' for directories" do
          metadata.collect
          metadata.checksum.should == "{ctime}#{time}"
        end

        it "should only use checksums of type 'ctime' for directories even if checksum_type set" do
          metadata.checksum_type = "mtime"
          metadata.expects(:mtime_file).never
          metadata.collect
          metadata.checksum.should == "{ctime}#{time}"
        end

        it "should validate against the schema", :unless => Puppet.features.microsoft_windows? do
          metadata.collect
          validate_json_for_file_metadata(metadata)
        end
      end
    end
  end

  shared_examples_for "metadata collector symlinks" do

    let(:metadata) do
      data = described_class.new(path)
      data.collect
      data
    end

    describe "when collecting attributes" do
      describe "when managing links" do
        # 'path' is a link that points to 'target'
        let(:path) { tmpfile('file_serving_metadata_link') }
        let(:target) { tmpfile('file_serving_metadata_target') }
        let(:checksum) { Digest::MD5.hexdigest("some content\n") }
        let(:fmode) { File.lstat(path).mode & 0777 }

        before :each do
          File.open(target, "wb") {|f| f.print("some content\n")}
          set_mode(0644, target)

          Puppet::FileSystem::File.new(target).symlink(path)
        end

        it "should read links instead of returning their checksums" do
          metadata.destination.should == target
        end

        it "should validate against the schema", :unless => Puppet.features.microsoft_windows? do
          validate_json_for_file_metadata(metadata)
        end
      end
    end

    describe Puppet::FileServing::Metadata, " when finding the file to use for setting attributes" do
      let(:path) { tmpfile('file_serving_metadata_find_file') }

      before :each do
        File.open(path, "wb") {|f| f.print("some content\n")}
        set_mode(0755, path)
      end

      it "should accept a base path to which the file should be relative" do
        dir = tmpdir('metadata_dir')
        metadata = described_class.new(dir)
        metadata.relative_path = 'relative_path'

        FileUtils.touch(metadata.full_path)

        metadata.collect
      end

      it "should use the set base path if one is not provided" do
        metadata.collect
      end

      it "should raise an exception if the file does not exist" do
        File.delete(path)

        proc { metadata.collect}.should raise_error(Errno::ENOENT)
      end

      it "should validate against the schema", :unless => Puppet.features.microsoft_windows? do
        validate_json_for_file_metadata(metadata)
      end
    end
  end

  describe "on POSIX systems", :if => Puppet.features.posix? do
    let(:owner) {10}
    let(:group) {20}

    before :each do
      File::Stat.any_instance.stubs(:uid).returns owner
      File::Stat.any_instance.stubs(:gid).returns group
    end

    it_should_behave_like "metadata collector"
    it_should_behave_like "metadata collector symlinks"

    def set_mode(mode, path)
      File.chmod(mode, path)
    end
  end

  describe "on Windows systems", :if => Puppet.features.microsoft_windows? do
    let(:owner) {'S-1-1-50'}
    let(:group) {'S-1-1-51'}

    before :each do
      require 'puppet/util/windows/security'
      Puppet::Util::Windows::Security.stubs(:get_owner).returns owner
      Puppet::Util::Windows::Security.stubs(:get_group).returns group
    end

    it_should_behave_like "metadata collector"

    describe "if ACL metadata cannot be collected" do
      let(:path) { tmpdir('file_serving_metadata_acl') }
      let(:metadata) do
        data = described_class.new(path)
        data.collect
        data
      end

      it "should default owner" do
        Puppet::Util::Windows::Security.stubs(:get_owner).returns nil

        metadata.owner.should == 'S-1-5-32-544'
      end

      it "should default group" do
        Puppet::Util::Windows::Security.stubs(:get_group).returns nil

        metadata.group.should == 'S-1-0-0'
      end

      it "should default mode" do
        Puppet::Util::Windows::Security.stubs(:get_mode).returns nil

        metadata.mode.should == 0644
      end
    end

    def set_mode(mode, path)
      Puppet::Util::Windows::Security.set_mode(mode, path)
    end
  end
end


describe Puppet::FileServing::Metadata, " when pointing to a link", :if => Puppet::Type.type(:file).defaultprovider.feature?(:manages_symlinks) do
  describe "when links are managed" do
    before do
      @file = Puppet::FileServing::Metadata.new("/base/path/my/file", :links => :manage)
      File.expects(:lstat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "link", :mode => 0755)
      File.expects(:readlink).with("/base/path/my/file").returns "/some/other/path"

      @checksum = Digest::MD5.hexdigest("some content\n") # Remove these when :managed links are no longer checksumed.
      @file.stubs(:md5_file).returns(@checksum)           #
    end
    it "should store the destination of the link in :destination if links are :manage" do
      @file.collect
      @file.destination.should == "/some/other/path"
    end
    pending "should not collect the checksum if links are :manage" do
      # We'd like this to be true, but we need to always collect the checksum because in the server/client/server round trip we lose the distintion between manage and follow.
      @file.collect
      @file.checksum.should be_nil
    end
    it "should collect the checksum if links are :manage" do # see pending note above
      @file.collect
      @file.checksum.should == "{md5}#{@checksum}"
    end
  end

  describe "when links are followed" do
    before do
      @file = Puppet::FileServing::Metadata.new("/base/path/my/file", :links => :follow)
      File.expects(:stat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "file", :mode => 0755)
      File.expects(:readlink).with("/base/path/my/file").never
      @checksum = Digest::MD5.hexdigest("some content\n")
      @file.stubs(:md5_file).returns(@checksum)
    end
    it "should not store the destination of the link in :destination if links are :follow" do
      @file.collect
      @file.destination.should be_nil
    end
    it "should collect the checksum if links are :follow" do
      @file.collect
      @file.checksum.should == "{md5}#{@checksum}"
    end
  end
end
