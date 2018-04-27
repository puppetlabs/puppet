#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:content), :uses_checksums => true do
  include PuppetSpec::Files
  include_context 'with supported checksum types'

  let(:filename) { tmpfile('testfile') }
  let(:environment) { Puppet::Node::Environment.create(:testing, []) }
  let(:catalog) { Puppet::Resource::Catalog.new(:test, environment) }
  let(:resource) { Puppet::Type.type(:file).new :path => filename, :catalog => catalog }

  before do
    File.open(filename, 'w') {|f| f.write "initial file content"}
    described_class.stubs(:standalone?).returns(false)
  end

  around do |example|
    Puppet.override(:environments => Puppet::Environments::Static.new(environment)) do
      example.run
    end
  end

  describe "when determining the actual content to write" do
    let(:content) { described_class.new(:resource => resource) }

    it "should use the set content if available" do
      content.should = "ehness"
      expect(content.actual_content).to eq("ehness")
    end

    it "should not use the content from the source if the source is set" do
      source = mock 'source'

      resource.expects(:parameter).never.with(:source).returns source

      expect(content.actual_content).to be_nil
    end
  end

  describe "when setting the desired content" do
    let(:content) { described_class.new(:resource => resource) }

    before do
      Puppet::Type.type(:file).any_instance.stubs(:file).returns('my/file.pp')
      Puppet::Type.type(:file).any_instance.stubs(:line).returns 5
    end

    it "should make the actual content available via an attribute" do
      content.should = "this is some content"

      expect(content.actual_content).to eq("this is some content")
    end

    with_digest_algorithms do
      it "should store the checksum as the desired content" do
        d = digest("this is some content")

        content.should = "this is some content"

        expect(content.should).to eq("{#{digest_algorithm}}#{d}")
      end

      it "should not checksum 'absent'" do
        content.should = :absent

        expect(content.should).to eq(:absent)
      end

      it "should accept a checksum as the desired content" do
        d = digest("this is some content")

        string = "{#{digest_algorithm}}#{d}"
        content.should = string

        expect(content.should).to eq(string)
      end
    end

    it "should convert the value to ASCII-8BIT", :if => "".respond_to?(:encode) do
      content.should= "Let's make a \u{2603}"

      expect(content.actual_content).to eq("Let's make a \xE2\x98\x83".force_encoding(Encoding::ASCII_8BIT))
    end
  end

  describe "when retrieving the current content" do
    let(:content) { described_class.new(:resource => resource) }

    it "should return :absent if the file does not exist" do
      resource.expects(:stat).returns nil

      expect(content.retrieve).to eq(:absent)
    end

    it "should not manage content on directories" do
      stat = mock 'stat', :ftype => "directory"
      resource.expects(:stat).returns stat

      expect(content.retrieve).to be_nil
    end

    it "should not manage content on links" do
      stat = mock 'stat', :ftype => "link"
      resource.expects(:stat).returns stat

      expect(content.retrieve).to be_nil
    end

    it "should always return the checksum as a string" do
      resource[:checksum] = :mtime

      stat = mock 'stat', :ftype => "file"
      resource.expects(:stat).returns stat

      time = Time.now
      resource.parameter(:checksum).expects(:mtime_file).with(resource[:path]).returns time

      expect(content.retrieve).to eq("{mtime}#{time}")
    end

    with_digest_algorithms do
      it "should return the checksum of the file if it exists and is a normal file" do
        stat = mock 'stat', :ftype => "file"
        resource.expects(:stat).returns stat
        resource.parameter(:checksum).expects("#{digest_algorithm}_file".intern).with(resource[:path]).returns "mysum"

        expect(content.retrieve).to eq("{#{digest_algorithm}}mysum")
      end
    end
  end

  describe "when testing whether the content is in sync" do
    let(:content) { described_class.new(:resource => resource) }

    before do
      resource[:ensure] = :file
    end

    with_digest_algorithms do
      before(:each) do
        resource[:checksum] = digest_algorithm
      end

      it "should return true if the resource shouldn't be a regular file" do
        resource.expects(:should_be_file?).returns false
        content.should = "foo"
        expect(content).to be_safe_insync("whatever")
      end

      it "should warn that no content will be synced to links when ensure is :present" do
        resource[:ensure] = :present
        resource[:content] = 'foo'
        resource.stubs(:should_be_file?).returns false
        resource.stubs(:stat).returns mock("stat", :ftype => "link")

        resource.expects(:warning).with {|msg| msg =~ /Ensure set to :present but file type is/}

        content.insync? :present
      end

      it "should return false if the current content is :absent" do
        content.should = "foo"
        expect(content).not_to be_safe_insync(:absent)
      end

      it "should return false if the file should be a file but is not present" do
        resource.expects(:should_be_file?).returns true
        content.should = "foo"

        expect(content).not_to be_safe_insync(:absent)
      end

      describe "and the file exists" do
        before do
          resource.stubs(:stat).returns mock("stat")
          content.should = "some content"
        end

        it "should return false if the current contents are different from the desired content" do
          expect(content).not_to be_safe_insync("other content")
        end

        it "should return true if the sum for the current contents is the same as the sum for the desired content" do
          expect(content).to be_safe_insync("{#{digest_algorithm}}" + digest("some content"))
        end

        it "should include the diff module" do
          expect(content.respond_to?("diff")).to eq(false)
        end

        describe "showing the diff" do
          it "doesn't show the diff when #show_diff? is false" do
            content.expects(:show_diff?).returns false
            content.expects(:diff).never
            expect(content).not_to be_safe_insync("other content")
          end

          describe "and #show_diff? is true" do
            before do
              content.expects(:show_diff?).returns true
              resource[:loglevel] = "debug"
            end

            it "prints the diff" do
              content.expects(:diff).returns("my diff").once
              content.expects(:debug).with("\nmy diff").once
              expect(content).not_to be_safe_insync("other content")
            end

            it "redacts the diff when the property is sensitive" do
              content.sensitive = true
              content.expects(:diff).returns("my diff").never
              content.expects(:debug).with("[diff redacted]").once
              expect(content).not_to be_safe_insync("other content")
            end
          end
        end
      end
    end

    let(:saved_time) { Time.now }
    [:ctime, :mtime].each do |time_stat|
      [["older", -1, false], ["same", 0, true], ["newer", 1, true]].each do
        |compare, target_time, success|
        describe "with #{compare} target #{time_stat} compared to source" do
          before do
            resource[:checksum] = time_stat
            resource[:source] = make_absolute('/temp/foo')
            content.should = "{#{time_stat}}#{saved_time}"
          end

          it "should return #{success}" do
            if success
              expect(content).to be_safe_insync("{#{time_stat}}#{saved_time+target_time}")
            else
              expect(content).not_to be_safe_insync("{#{time_stat}}#{saved_time+target_time}")
            end
          end
        end
      end

      describe "with #{time_stat}" do
        before do
          resource[:checksum] = time_stat
          resource[:source] = make_absolute('/temp/foo')
        end

        it "should not be insync if trying to create it" do
          content.should = "{#{time_stat}}#{saved_time}"
          expect(content).not_to be_safe_insync(:absent)
        end

        it "should raise an error if content is not a checksum" do
          content.should = "some content"
          expect {
            content.safe_insync?("{#{time_stat}}#{saved_time}")
          }.to raise_error(/Resource with checksum_type #{time_stat} didn't contain a date in/)
        end

        it "should not be insync even if content is the absent symbol" do
          content.should = :absent
          expect(content).not_to be_safe_insync(:absent)
        end

        it "should warn that no content will be synced to links when ensure is :present" do
          resource[:ensure] = :present
          resource[:content] = 'foo'
          resource.stubs(:should_be_file?).returns false
          resource.stubs(:stat).returns mock("stat", :ftype => "link")

          resource.expects(:warning).with {|msg| msg =~ /Ensure set to :present but file type is/}

          content.insync? :present
        end
      end
    end

    describe "and :replace is false" do
      before do
        resource.stubs(:replace?).returns false
      end

      it "should be insync if the file exists and the content is different" do
        resource.stubs(:stat).returns mock('stat')

        expect(content).to be_safe_insync("whatever")
      end

      it "should be insync if the file exists and the content is right" do
        resource.stubs(:stat).returns mock('stat')

        expect(content).to be_safe_insync("something")
      end

      it "should not be insync if the file does not exist" do
        content.should = "foo"
        expect(content).not_to be_safe_insync(:absent)
      end
    end
  end

  describe "when testing whether the content is initialized in the resource and in sync" do
    CHECKSUM_TYPES_TO_TRY.each do |checksum_type, checksum|
      describe "sync with checksum type #{checksum_type} and the file exists" do
        before do
          @new_resource = Puppet::Type.type(:file).new :ensure => :file, :path => filename, :catalog => catalog,
            :content => CHECKSUM_PLAINTEXT, :checksum => checksum_type
          @new_resource.stubs(:stat).returns mock('stat')
        end

        it "should return false if the sum for the current contents are different from the desired content" do
          expect(@new_resource.parameters[:content]).not_to be_safe_insync("other content")
        end

        it "should return true if the sum for the current contents is the same as the sum for the desired content" do
          expect(@new_resource.parameters[:content]).to be_safe_insync("{#{checksum_type}}#{checksum}")
        end
      end
    end
  end

  describe "determining if a diff should be shown" do
    let(:content) { described_class.new(:resource => resource) }

    before do
      Puppet[:show_diff] = true
      resource[:show_diff] = true
    end

    it "is true if there are changes and the global and per-resource show_diff settings are true" do
      expect(content.show_diff?(true)).to be_truthy
    end

    it "is false if there are no changes" do
      expect(content.show_diff?(false)).to be_falsey
    end

    it "is false if show_diff is globally disabled" do
      Puppet[:show_diff] = false
      expect(content.show_diff?(false)).to be_falsey
    end

    it "is false if show_diff is disabled on the resource" do
      resource[:show_diff] = false
      expect(content.show_diff?(false)).to be_falsey
    end
  end

  describe "when changing the content" do
    let(:content) { described_class.new(:resource => resource) }

    before do
      resource.stubs(:[]).with(:path).returns "/boo"
      resource.stubs(:stat).returns "eh"
    end

    it "should use the file's :write method to write the content" do
      resource.expects(:write).with(content)

      content.sync
    end

    it "should return :file_changed if the file already existed" do
      resource.expects(:stat).returns "something"
      resource.stubs(:write)
      expect(content.sync).to eq(:file_changed)
    end

    it "should return :file_created if the file did not exist" do
      resource.expects(:stat).returns nil
      resource.stubs(:write)
      expect(content.sync).to eq(:file_created)
    end
  end

  describe "when writing" do
    let(:content) { described_class.new(:resource => resource) }

    let(:fh) { File.open(filename, 'wb') }

    before do
      Puppet::Type.type(:file).any_instance.stubs(:file).returns('my/file.pp')
      Puppet::Type.type(:file).any_instance.stubs(:line).returns 5
    end

    it "should attempt to read from the filebucket if no actual content nor source exists" do
      content.should = "{md5}foo"
      content.resource.bucket.class.any_instance.stubs(:getfile).returns "foo"
      content.write(fh)
      fh.close
    end

    describe "from actual content" do
      before(:each) do
        content.stubs(:actual_content).returns("this is content")
      end

      it "should write to the given file handle" do
        fh = mock 'filehandle'
        fh.expects(:print).with("this is content")
        content.write(fh)
      end

      it "should return the current checksum value" do
        resource.parameter(:checksum).expects(:sum_stream).returns "checksum"
        expect(content.write(fh)).to eq("checksum")
      end
    end

    describe "from a file bucket" do
      it "should fail if a file bucket cannot be retrieved" do
        content.should = "{md5}foo"
        content.resource.expects(:bucket).returns nil
        expect { content.write(fh) }.to raise_error(Puppet::Error)
      end

      it "should fail if the file bucket cannot find any content" do
        content.should = "{md5}foo"
        bucket = stub 'bucket'
        content.resource.expects(:bucket).returns bucket
        bucket.expects(:getfile).with("foo").raises "foobar"
        expect { content.write(fh) }.to raise_error(Puppet::Error)
      end

      it "should write the returned content to the file" do
        content.should = "{md5}foo"
        bucket = stub 'bucket'
        content.resource.expects(:bucket).returns bucket
        bucket.expects(:getfile).with("foo").returns "mycontent"

        fh = mock 'filehandle'
        fh.expects(:print).with("mycontent")
        content.write(fh)
      end
    end
  end
end
