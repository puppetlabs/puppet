#!/usr/bin/env rspec
require 'spec_helper'

content = Puppet::Type.type(:file).attrclass(:content)
describe content do
  include PuppetSpec::Files
  before do
    @filename = tmpfile('testfile')
    @resource = Puppet::Type.type(:file).new :path => @filename
    File.open(@filename, 'w') {|f| f.write "initial file content"}
    content.stubs(:standalone?).returns(false)
  end

  describe "when determining the checksum type" do
    it "should use the type specified in the source checksum if a source is set" do
      @resource[:source] = File.expand_path("/foo")
      @resource.parameter(:source).expects(:checksum).returns "{md5lite}eh"

      @content = content.new(:resource => @resource)
      @content.checksum_type.should == :md5lite
    end

    it "should use the type specified by the checksum parameter if no source is set" do
      @resource[:checksum] = :md5lite

      @content = content.new(:resource => @resource)
      @content.checksum_type.should == :md5lite
    end
  end

  describe "when determining the actual content to write" do
    it "should use the set content if available" do
      @content = content.new(:resource => @resource)
      @content.should = "ehness"
      @content.actual_content.should == "ehness"
    end

    it "should not use the content from the source if the source is set" do
      source = mock 'source'

      @resource.expects(:parameter).never.with(:source).returns source

      @content = content.new(:resource => @resource)
      @content.actual_content.should be_nil
    end
  end

  describe "when setting the desired content" do
    it "should make the actual content available via an attribute" do
      @content = content.new(:resource => @resource)
      @content.stubs(:checksum_type).returns "md5"
      @content.should = "this is some content"

      @content.actual_content.should == "this is some content"
    end

    it "should store the checksum as the desired content" do
      @content = content.new(:resource => @resource)
      digest = Digest::MD5.hexdigest("this is some content")

      @content.stubs(:checksum_type).returns "md5"
      @content.should = "this is some content"

      @content.should.must == "{md5}#{digest}"
    end

    it "should not checksum 'absent'" do
      @content = content.new(:resource => @resource)
      @content.should = :absent

      @content.should.must == :absent
    end

    it "should accept a checksum as the desired content" do
      @content = content.new(:resource => @resource)
      digest = Digest::MD5.hexdigest("this is some content")

      string = "{md5}#{digest}"
      @content.should = string

      @content.should.must == string
    end
  end

  describe "when retrieving the current content" do
    it "should return :absent if the file does not exist" do
      @content = content.new(:resource => @resource)
      @resource.expects(:stat).returns nil

      @content.retrieve.should == :absent
    end

    it "should not manage content on directories" do
      @content = content.new(:resource => @resource)

      stat = mock 'stat', :ftype => "directory"
      @resource.expects(:stat).returns stat

      @content.retrieve.should be_nil
    end

    it "should not manage content on links" do
      @content = content.new(:resource => @resource)

      stat = mock 'stat', :ftype => "link"
      @resource.expects(:stat).returns stat

      @content.retrieve.should be_nil
    end

    it "should always return the checksum as a string" do
      @content = content.new(:resource => @resource)
      @resource[:checksum] = :mtime

      stat = mock 'stat', :ftype => "file"
      @resource.expects(:stat).returns stat

      time = Time.now
      @resource.parameter(:checksum).expects(:mtime_file).with(@resource[:path]).returns time

      @content.retrieve.should == "{mtime}#{time}"
    end

    it "should return the checksum of the file if it exists and is a normal file" do
      @content = content.new(:resource => @resource)
      stat = mock 'stat', :ftype => "file"
      @resource.expects(:stat).returns stat
      @resource.parameter(:checksum).expects(:md5_file).with(@resource[:path]).returns "mysum"

      @content.retrieve.should == "{md5}mysum"
    end
  end

  describe "when testing whether the content is in sync" do
    before do
      @resource[:ensure] = :file
      @content = content.new(:resource => @resource)
    end

    it "should return true if the resource shouldn't be a regular file" do
      @resource.expects(:should_be_file?).returns false
      @content.should = "foo"
      @content.must be_safe_insync("whatever")
    end

    it "should return false if the current content is :absent" do
      @content.should = "foo"
      @content.should_not be_safe_insync(:absent)
    end

    it "should return false if the file should be a file but is not present" do
      @resource.expects(:should_be_file?).returns true
      @content.should = "foo"

      @content.should_not be_safe_insync(:absent)
    end

    describe "and the file exists" do
      before do
        @resource.stubs(:stat).returns mock("stat")
      end

      it "should return false if the current contents are different from the desired content" do
        @content.should = "some content"
        @content.should_not be_safe_insync("other content")
      end

      it "should return true if the sum for the current contents is the same as the sum for the desired content" do
        @content.should = "some content"
        @content.must be_safe_insync("{md5}" + Digest::MD5.hexdigest("some content"))
      end

      describe "and Puppet[:show_diff] is set" do
        before do
          Puppet[:show_diff] = true
        end

        it "should display a diff if the current contents are different from the desired content" do
          @content.should = "some content"
          @content.expects(:diff).returns("my diff").once
          @content.expects(:print).with("my diff").once

          @content.safe_insync?("other content")
        end

        it "should not display a diff if the sum for the current contents is the same as the sum for the desired content" do
          @content.should = "some content"
          @content.expects(:diff).never

          @content.safe_insync?("{md5}" + Digest::MD5.hexdigest("some content"))
        end
      end
    end

    describe "and :replace is false" do
      before do
        @resource.stubs(:replace?).returns false
      end

      it "should be insync if the file exists and the content is different" do
        @resource.stubs(:stat).returns mock('stat')

        @content.must be_safe_insync("whatever")
      end

      it "should be insync if the file exists and the content is right" do
        @resource.stubs(:stat).returns mock('stat')

        @content.must be_safe_insync("something")
      end

      it "should not be insync if the file does not exist" do
        @content.should = "foo"
        @content.should_not be_safe_insync(:absent)
      end
    end
  end

  describe "when changing the content" do
    before do
      @content = content.new(:resource => @resource)
      @content.should = "some content"

      @resource.stubs(:[]).with(:path).returns "/boo"
      @resource.stubs(:stat).returns "eh"
    end

    it "should use the file's :write method to write the content" do
      @resource.expects(:write).with(:content)

      @content.sync
    end

    it "should return :file_changed if the file already existed" do
      @resource.expects(:stat).returns "something"
      @resource.stubs(:write)
      @content.sync.should == :file_changed
    end

    it "should return :file_created if the file did not exist" do
      @resource.expects(:stat).returns nil
      @resource.stubs(:write)
      @content.sync.should == :file_created
    end
  end

  describe "when writing" do
    before do
      @content = content.new(:resource => @resource)
    end

    it "should attempt to read from the filebucket if no actual content nor source exists" do
      @fh = File.open(@filename, 'w')
      @content.should = "{md5}foo"
      @content.resource.bucket.class.any_instance.stubs(:getfile).returns "foo"
      @content.write(@fh)
      @fh.close
    end

    describe "from actual content" do
      before(:each) do
        @content.stubs(:actual_content).returns("this is content")
      end

      it "should write to the given file handle" do
        @fh.expects(:print).with("this is content")
        @content.write(@fh)
      end

      it "should return the current checksum value" do
        @resource.parameter(:checksum).expects(:sum_stream).returns "checksum"
        @content.write(@fh).should == "checksum"
      end
    end

    describe "from a file bucket" do
      it "should fail if a file bucket cannot be retrieved" do
        @content.should = "{md5}foo"
        @content.resource.expects(:bucket).returns nil
        lambda { @content.write(@fh) }.should raise_error(Puppet::Error)
      end

      it "should fail if the file bucket cannot find any content" do
        @content.should = "{md5}foo"
        bucket = stub 'bucket'
        @content.resource.expects(:bucket).returns bucket
        bucket.expects(:getfile).with("foo").raises "foobar"
        lambda { @content.write(@fh) }.should raise_error(Puppet::Error)
      end

      it "should write the returned content to the file" do
        @content.should = "{md5}foo"
        bucket = stub 'bucket'
        @content.resource.expects(:bucket).returns bucket
        bucket.expects(:getfile).with("foo").returns "mycontent"

        @fh.expects(:print).with("mycontent")
        @content.write(@fh)
      end
    end

    describe "from local source", :fails_on_windows => true do
      before(:each) do
        @sourcename = tmpfile('source')
        @resource = Puppet::Type.type(:file).new :path => @filename, :backup => false, :source => @sourcename

        @source_content = "source file content"*10000
        @sourcefile = File.open(@sourcename, 'w') {|f| f.write @source_content}

        @content = @resource.newattr(:content)
        @source = @resource.parameter :source #newattr(:source)
      end

      it "should copy content from the source to the file" do
        @resource.write(@source)
        File.read(@filename).should == @source_content
      end

      it "should return the checksum computed" do
        File.open(@filename, 'w') do |file|
          @content.write(file).should == "{md5}#{Digest::MD5.hexdigest(@source_content)}"
        end
      end
    end

    describe "from remote source" do
      before(:each) do
        @resource = Puppet::Type.type(:file).new :path => @filename, :backup => false
        @response = stub_everything 'response', :code => "200"
        @source_content = "source file content"*10000
        @response.stubs(:read_body).multiple_yields(*(["source file content"]*10000))

        @conn = stub_everything 'connection'
        @conn.stubs(:request_get).yields(@response)
        Puppet::Network::HttpPool.stubs(:http_instance).returns @conn

        @content = @resource.newattr(:content)
        @sourcename = "puppet:///test/foo"
        @source = @resource.newattr(:source)
        @source.stubs(:metadata).returns stub_everything('metadata', :source => @sourcename, :ftype => 'file')
      end

      it "should write the contents to the file" do
        @resource.write(@source)
        File.read(@filename).should == @source_content
      end

      it "should not write anything if source is not found" do
        @response.stubs(:code).returns("404")
        lambda {@resource.write(@source)}.should raise_error(Net::HTTPError) { |e| e.message =~ /404/ }
        File.read(@filename).should == "initial file content"
      end

      it "should raise an HTTP error in case of server error" do
        @response.stubs(:code).returns("500")
        lambda { @content.write(@fh) }.should raise_error { |e| e.message.include? @source_content }
      end

      it "should return the checksum computed" do
        File.open(@filename, 'w') do |file|
          @content.write(file).should == "{md5}#{Digest::MD5.hexdigest(@source_content)}"
        end
      end
    end

    # These are testing the implementation rather than the desired behaviour; while that bites, there are a whole
    # pile of other methods in the File type that depend on intimate details of this implementation and vice-versa.
    # If these blow up, you are gonna have to review the callers to make sure they don't explode! --daniel 2011-02-01
    describe "each_chunk_from should work" do
      before do
        @content = content.new(:resource => @resource)
      end

      it "when content is a string" do
        @content.each_chunk_from('i_am_a_string') { |chunk| chunk.should == 'i_am_a_string' }
      end

      # The following manifest is a case where source and content.should are both set
      # file { "/tmp/mydir" :
      #   source  => '/tmp/sourcedir',
      #   recurse => true,
      # }
      it "when content checksum comes from source" do
        source_param = Puppet::Type.type(:file).attrclass(:source)
        source = source_param.new(:resource => @resource)
        @content.should = "{md5}123abcd"

        @content.expects(:chunk_file_from_source).returns('from_source')
        @content.each_chunk_from(source) { |chunk| chunk.should == 'from_source' }
      end

      it "when no content, source, but ensure present" do
        @resource[:ensure] = :present
        @content.each_chunk_from(nil) { |chunk| chunk.should == '' }
      end

      # you might do this if you were just auditing
      it "when no content, source, but ensure file" do
        @resource[:ensure] = :file
        @content.each_chunk_from(nil) { |chunk| chunk.should == '' }
      end

      it "when source_or_content is nil and content not a checksum" do
        @content.each_chunk_from(nil) { |chunk| chunk.should == '' }
      end

      # the content is munged so that if it's a checksum nil gets passed in
      it "when content is a checksum it should try to read from filebucket" do
        @content.should = "{md5}123abcd"
        @content.expects(:read_file_from_filebucket).once.returns('im_a_filebucket')
        @content.each_chunk_from(nil) { |chunk| chunk.should == 'im_a_filebucket' }
      end

      it "when running as puppet apply" do
        @content.class.expects(:standalone?).returns true
        source_or_content = stubs('source_or_content')
        source_or_content.expects(:content).once.returns :whoo
        @content.each_chunk_from(source_or_content) { |chunk| chunk.should == :whoo }
      end

      it "when running from source with a local file" do
        source_or_content = stubs('source_or_content')
        source_or_content.expects(:local?).returns true
        @content.expects(:chunk_file_from_disk).with(source_or_content).once.yields 'woot'
        @content.each_chunk_from(source_or_content) { |chunk| chunk.should == 'woot' }
      end

      it "when running from source with a remote file" do
        source_or_content = stubs('source_or_content')
        source_or_content.expects(:local?).returns false
        @content.expects(:chunk_file_from_source).with(source_or_content).once.yields 'woot'
        @content.each_chunk_from(source_or_content) { |chunk| chunk.should == 'woot' }
      end
    end
  end
end
