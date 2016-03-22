#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http_pool'

require 'puppet/network/resolver'

describe Puppet::Type.type(:file).attrclass(:content), :uses_checksums => true do
  include PuppetSpec::Files

  let(:filename) { tmpfile('testfile') }

  let(:catalog) { Puppet::Resource::Catalog.new }

  let(:resource) { Puppet::Type.type(:file).new :path => filename, :catalog => catalog }

  before do
    File.open(filename, 'w') {|f| f.write "initial file content"}
    described_class.stubs(:standalone?).returns(false)
  end

  describe "when determining the checksum type" do
    let(:content) { described_class.new(:resource => resource) }

    it "should use the type specified in the source checksum if a source is set" do
      resource[:source] = File.expand_path("/foo")
      resource.parameter(:source).expects(:checksum).returns "{md5lite}eh"

      content.checksum_type.should == :md5lite
    end

    it "should use the type specified by the checksum parameter if no source is set" do
      resource[:checksum] = :md5lite

      content.checksum_type.should == :md5lite
    end

    with_digest_algorithms do
      it "should use the type specified by digest_algorithm by default" do
        content.checksum_type.should == digest_algorithm.intern
      end
    end
  end

  describe "when determining the actual content to write" do
    let(:content) { described_class.new(:resource => resource) }

    it "should use the set content if available" do
      content.should = "ehness"
      content.actual_content.should == "ehness"
    end

    it "should not use the content from the source if the source is set" do
      source = mock 'source'

      resource.expects(:parameter).never.with(:source).returns source

      content.actual_content.should be_nil
    end
  end

  describe "when setting the desired content" do
    let(:content) { described_class.new(:resource => resource) }

    it "should make the actual content available via an attribute" do
      content.stubs(:checksum_type).returns "md5"
      content.should = "this is some content"

      content.actual_content.should == "this is some content"
    end

    with_digest_algorithms do
      it "should store the checksum as the desired content" do
        d = digest("this is some content")

        content.stubs(:checksum_type).returns digest_algorithm
        content.should = "this is some content"

        content.should.must == "{#{digest_algorithm}}#{d}"
      end

      it "should not checksum 'absent'" do
        content.should = :absent

        content.should.must == :absent
      end

      it "should accept a checksum as the desired content" do
        d = digest("this is some content")

        string = "{#{digest_algorithm}}#{d}"
        content.should = string

        content.should.must == string
      end
    end

    it "should convert the value to ASCII-8BIT", :if => "".respond_to?(:encode) do
      content.should= "Let's make a \u{2603}"

      content.actual_content.should == "Let's make a \xE2\x98\x83".force_encoding(Encoding::ASCII_8BIT)
    end
  end

  describe "when retrieving the current content" do
    let(:content) { described_class.new(:resource => resource) }

    it "should return :absent if the file does not exist" do
      resource.expects(:stat).returns nil

      content.retrieve.should == :absent
    end

    it "should not manage content on directories" do
      stat = mock 'stat', :ftype => "directory"
      resource.expects(:stat).returns stat

      content.retrieve.should be_nil
    end

    it "should not manage content on links" do
      stat = mock 'stat', :ftype => "link"
      resource.expects(:stat).returns stat

      content.retrieve.should be_nil
    end

    it "should always return the checksum as a string" do
      resource[:checksum] = :mtime

      stat = mock 'stat', :ftype => "file"
      resource.expects(:stat).returns stat

      time = Time.now
      resource.parameter(:checksum).expects(:mtime_file).with(resource[:path]).returns time

      content.retrieve.should == "{mtime}#{time}"
    end

    with_digest_algorithms do
      it "should return the checksum of the file if it exists and is a normal file" do
        stat = mock 'stat', :ftype => "file"
        resource.expects(:stat).returns stat
        resource.parameter(:checksum).expects("#{digest_algorithm}_file".intern).with(resource[:path]).returns "mysum"

        content.retrieve.should == "{#{digest_algorithm}}mysum"
      end
    end
  end

  describe "when testing whether the content is in sync" do
    let(:content) { described_class.new(:resource => resource) }

    before do
      resource[:ensure] = :file
    end

    it "should return true if the resource shouldn't be a regular file" do
      resource.expects(:should_be_file?).returns false
      content.should = "foo"
      content.must be_safe_insync("whatever")
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
      content.should_not be_safe_insync(:absent)
    end

    it "should return false if the file should be a file but is not present" do
      resource.expects(:should_be_file?).returns true
      content.should = "foo"

      content.should_not be_safe_insync(:absent)
    end

    describe "and the file exists" do
      with_digest_algorithms do
        before do
          resource.stubs(:stat).returns mock("stat")
          resource[:checksum] = digest_algorithm
          content.should = "some content"
        end

        it "should return false if the current contents are different from the desired content" do
          content.should_not be_safe_insync("other content")
        end

        it "should return true if the sum for the current contents is the same as the sum for the desired content" do
          content.must be_safe_insync("{#{digest_algorithm}}" + digest("some content"))
        end

        [true, false].product([true, false]).each do |cfg, param|
          describe "and Puppet[:show_diff] is #{cfg} and show_diff => #{param}" do
            before do
              Puppet[:show_diff] = cfg
              resource.stubs(:show_diff?).returns param
              resource[:loglevel] = "debug"
            end

            if cfg and param
              it "should display a diff" do
                content.expects(:diff).returns("my diff").once
                content.expects(:debug).with("\nmy diff").once
                content.should_not be_safe_insync("other content")
              end
            else
              it "should not display a diff" do
                content.expects(:diff).never
                content.should_not be_safe_insync("other content")
              end
            end
          end
        end
      end
    end

    describe "and :replace is false" do
      before do
        resource.stubs(:replace?).returns false
      end

      it "should be insync if the file exists and the content is different" do
        resource.stubs(:stat).returns mock('stat')

        content.must be_safe_insync("whatever")
      end

      it "should be insync if the file exists and the content is right" do
        resource.stubs(:stat).returns mock('stat')

        content.must be_safe_insync("something")
      end

      it "should not be insync if the file does not exist" do
        content.should = "foo"
        content.should_not be_safe_insync(:absent)
      end
    end
  end

 describe "when changing the content" do
    let(:content) { described_class.new(:resource => resource) }

    before do
      resource.stubs(:[]).with(:path).returns "/boo"
      resource.stubs(:stat).returns "eh"
    end

    it "should use the file's :write method to write the content" do
      resource.expects(:write).with(:content)

      content.sync
    end

    it "should return :file_changed if the file already existed" do
      resource.expects(:stat).returns "something"
      resource.stubs(:write)
      content.sync.should == :file_changed
    end

    it "should return :file_created if the file did not exist" do
      resource.expects(:stat).returns nil
      resource.stubs(:write)
      content.sync.should == :file_created
    end
  end

  describe "when writing" do
    let(:content) { described_class.new(:resource => resource) }

    let(:fh) { File.open(filename, 'wb') }

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
        content.write(fh).should == "checksum"
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

    describe "from local source" do
      let(:source_content) { "source file content\r\n"*10 }
      before(:each) do
        sourcename = tmpfile('source')
        resource[:backup] = false
        resource[:source] = sourcename

        File.open(sourcename, 'wb') {|f| f.write source_content}

        # This needs to be invoked to properly initialize the content property,
        # or attempting to write a file will fail.
        resource.newattr(:content)
      end

      it "should copy content from the source to the file" do
        source = resource.parameter(:source)
        resource.write(source)

        Puppet::FileSystem.binread(filename).should == source_content
      end

      with_digest_algorithms do
        it "should return the checksum computed" do
          File.open(filename, 'wb') do |file|
            resource[:checksum] = digest_algorithm
            content.write(file).should == "{#{digest_algorithm}}#{digest(source_content)}"
          end
        end
      end
    end

    describe 'from remote source' do
      let(:source_content) { "source file content\n"*10 }
      let(:source) { resource.newattr(:source) }
      let(:response) { stub_everything('response') }
      let(:conn) { mock('connection') }

      before(:each) do
        resource[:backup] = false
        # This needs to be invoked to properly initialize the content property,
        # or attempting to write a file will fail.
        resource.newattr(:content)

        response.stubs(:read_body).multiple_yields(*source_content.lines)
        conn.stubs(:request_get).yields(response)
      end

      it 'should use an explicit fileserver if source starts with puppet://' do
        response.stubs(:code).returns('200')
        source.stubs(:metadata).returns stub_everything('metadata', :source => 'puppet://somehostname/test/foo', :ftype => 'file')
        Puppet::Network::HttpPool.expects(:http_instance).with('somehostname', anything).returns(conn)

        resource.write(source)
      end

      it 'should use the default fileserver if source starts with puppet:///' do
        response.stubs(:code).returns('200')
        source.stubs(:metadata).returns stub_everything('metadata', :source => 'puppet:///test/foo', :ftype => 'file')
        Puppet::Network::HttpPool.expects(:http_instance).with(Puppet.settings[:server], anything).returns(conn)

        resource.write(source)
      end

      it 'should percent encode reserved characters' do
        response.stubs(:code).returns('200')
        Puppet::Network::HttpPool.stubs(:http_instance).returns(conn)
        source.stubs(:metadata).returns stub_everything('metadata', :source => 'puppet:///test/foo bar', :ftype => 'file')

        conn.unstub(:request_get)
        conn.expects(:request_get).with('/none/file_content/test/foo%20bar', anything).yields(response)

        resource.write(source)
      end

      describe 'when handling file_content responses' do
        before(:each) do
          Puppet::Network::HttpPool.stubs(:http_instance).returns(conn)
          source.stubs(:metadata).returns stub_everything('metadata', :source => 'puppet:///test/foo', :ftype => 'file')
        end

        it 'should not write anything if source is not found' do
          response.stubs(:code).returns('404')

          expect { resource.write(source) }.to raise_error(Net::HTTPError, /404/)
          expect(File.read(filename)).to eq('initial file content')
        end

        it 'should raise an HTTP error in case of server error' do
          response.stubs(:code).returns('500')

          expect { resource.write(source) }.to raise_error(Net::HTTPError, /500/)
        end

        context 'and the request was successful' do
          before(:each) { response.stubs(:code).returns '200' }

          it 'should write the contents to the file' do
            resource.write(source)
            expect(Puppet::FileSystem.binread(filename)).to eq(source_content)
          end

          with_digest_algorithms do
            it 'should return the checksum computed' do
              File.open(filename, 'w') do |file|
                resource[:checksum] = digest_algorithm
                expect(content.write(file)).to eq("{#{digest_algorithm}}#{digest(source_content)}")
              end
            end
          end

        end

      end
    end

    # These are testing the implementation rather than the desired behaviour; while that bites, there are a whole
    # pile of other methods in the File type that depend on intimate details of this implementation and vice-versa.
    # If these blow up, you are gonna have to review the callers to make sure they don't explode! --daniel 2011-02-01
    describe "each_chunk_from should work" do

      it "when content is a string" do
        content.each_chunk_from('i_am_a_string') { |chunk| chunk.should == 'i_am_a_string' }
      end

      # The following manifest is a case where source and content.should are both set
      # file { "/tmp/mydir" :
      #   source  => '/tmp/sourcedir',
      #   recurse => true,
      # }
      it "when content checksum comes from source" do
        source_param = Puppet::Type.type(:file).attrclass(:source)
        source = source_param.new(:resource => resource)
        content.should = "{md5}123abcd"

        content.expects(:chunk_file_from_source).returns('from_source')
        content.each_chunk_from(source) { |chunk| chunk.should == 'from_source' }
      end

      it "when no content, source, but ensure present" do
        resource[:ensure] = :present
        content.each_chunk_from(nil) { |chunk| chunk.should == '' }
      end

      # you might do this if you were just auditing
      it "when no content, source, but ensure file" do
        resource[:ensure] = :file
        content.each_chunk_from(nil) { |chunk| chunk.should == '' }
      end

      it "when source_or_content is nil and content not a checksum" do
        content.each_chunk_from(nil) { |chunk| chunk.should == '' }
      end

      # the content is munged so that if it's a checksum nil gets passed in
      it "when content is a checksum it should try to read from filebucket" do
        content.should = "{md5}123abcd"
        content.expects(:read_file_from_filebucket).once.returns('im_a_filebucket')
        content.each_chunk_from(nil) { |chunk| chunk.should == 'im_a_filebucket' }
      end

      it "when running as puppet apply" do
        Puppet[:default_file_terminus] = "file_server"
        source_or_content = stubs('source_or_content')
        source_or_content.expects(:content).once.returns :whoo
        content.each_chunk_from(source_or_content) { |chunk| chunk.should == :whoo }
      end

      it "when running from source with a local file" do
        source_or_content = stubs('source_or_content')
        source_or_content.expects(:local?).returns true
        content.expects(:chunk_file_from_disk).with(source_or_content).once.yields 'woot'
        content.each_chunk_from(source_or_content) { |chunk| chunk.should == 'woot' }
      end

      it "when running from source with a remote file" do
        source_or_content = stubs('source_or_content')
        source_or_content.expects(:local?).returns false
        content.expects(:chunk_file_from_source).with(source_or_content).once.yields 'woot'
        content.each_chunk_from(source_or_content) { |chunk| chunk.should == 'woot' }
      end
    end
  end
end
