#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

content = Puppet::Type.type(:file).attrclass(:content)
describe content do
    before do
        @resource = Puppet::Type.type(:file).new :path => "/foo/bar"
    end

    it "should be a subclass of Property" do
        content.superclass.must == Puppet::Property
    end

    describe "when determining the checksum type" do
        before do
            @resource = Puppet::Type.type(:file).new :path => "/foo/bar"
        end

        it "should use the type specified in the source checksum if a source is set" do
            @resource[:source] = "/foo"
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
        before do
            @resource = Puppet::Type.type(:file).new :path => "/foo/bar"
        end

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

            @content.retrieve.should == "{mtime}%s" % time
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
            @content.must be_insync("whatever")
        end

        it "should return false if the current content is :absent" do
            @content.should_not be_insync(:absent)
        end

        it "should return false if the file should be a file but is not present" do
            @resource.expects(:should_be_file?).returns true

            @content.should_not be_insync(:absent)
        end

        describe "and the file exists" do
            before do
                @resource.stubs(:stat).returns mock("stat")
            end

            it "should return false if the current contents are different from the desired content" do
                @content.should = "some content"
                @content.should_not be_insync("other content")
            end

            it "should return true if the sum for the current contents is the same as the sum for the desired content" do
                @content.should = "some content"
                @content.must be_insync("{md5}" + Digest::MD5.hexdigest("some content"))
            end

            describe "and Puppet[:show_diff] is set" do
                before do
                    Puppet[:show_diff] = true
                end

                it "should display a diff if the current contents are different from the desired content" do 
                    @content.should = "some content"
                    @content.expects(:string_file_diff).once

                    @content.insync?("other content")
                end

                it "should not display a diff if the sum for the current contents is the same as the sum for the desired content" do 
                    @content.should = "some content"
                    @content.expects(:string_file_diff).never

                    @content.insync?("{md5}" + Digest::MD5.hexdigest("some content"))
                end
            end
        end

        describe "and :replace is false" do
            before do
                @resource.stubs(:replace?).returns false
            end

            it "should be insync if the file exists and the content is different" do
                @resource.stubs(:stat).returns mock('stat')

                @content.must be_insync("whatever")
            end

            it "should be insync if the file exists and the content is right" do
                @resource.stubs(:stat).returns mock('stat')

                @content.must be_insync("something")
            end

            it "should not be insync if the file does not exist" do
                @content.should_not be_insync(:absent)
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
            @fh = stub_everything
        end

        it "should fail if no actual content nor source exists" do
            lambda { @content.write(@fh) }.should raise_error
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

        describe "from local source" do
            before(:each) do
                @content.stubs(:actual_content).returns(nil)
                @source = stub_everything 'source', :local? => true, :full_path => "/path/to/source"
                @resource.stubs(:parameter).with(:source).returns @source

                @sum = stub_everything 'sum'
                @resource.stubs(:parameter).with(:checksum).returns(@sum)

                @digest = stub_everything 'digest'
                @sum.stubs(:sum_stream).yields(@digest)

                @file = stub_everything 'file'
                File.stubs(:open).yields(@file)
                @file.stubs(:read).with(8192).returns("chunk1").then.returns("chunk2").then.returns(nil)
            end

            it "should open the local file" do
                File.expects(:open).with("/path/to/source", "r")
                @content.write(@fh)
            end

            it "should read the local file by chunks" do
                @file.expects(:read).with(8192).returns("chunk1").then.returns(nil)
                @content.write(@fh)
            end

            it "should write each chunk to the file" do
                @fh.expects(:print).with("chunk1").then.with("chunk2")
                @content.write(@fh)
            end

            it "should pass each chunk to the current sum stream" do
                @digest.expects(:<<).with("chunk1").then.with("chunk2")
                @content.write(@fh)
            end

            it "should return the checksum computed" do
                @sum.stubs(:sum_stream).yields(@digest).returns("checksum")
                @content.write(@fh).should == "checksum"
            end
        end

        describe "from remote source" do
            before(:each) do
                @response = stub_everything 'mock response', :code => "404"
                @conn = stub_everything 'connection'
                @conn.stubs(:request_get).yields(@response)
                Puppet::Network::HttpPool.stubs(:http_instance).returns @conn

                @content.stubs(:actual_content).returns(nil)
                @source = stub_everything 'source', :local? => false, :full_path => "/path/to/source", :server => "server", :port => 1234
                @resource.stubs(:parameter).with(:source).returns @source

                @sum = stub_everything 'sum'
                @resource.stubs(:parameter).with(:checksum).returns(@sum)

                @digest = stub_everything 'digest'
                @sum.stubs(:sum_stream).yields(@digest)
            end

            it "should open a network connection to source server and port" do
                Puppet::Network::HttpPool.expects(:http_instance).with("server", 1234).returns @conn
                @content.write(@fh)
            end

            it "should send the correct indirection uri" do
                @conn.expects(:request_get).with { |uri,headers| uri == "/production/file_content//path/to/source" }.yields(@response)
                @content.write(@fh)
            end

            it "should return nil if source is not found" do
                @response.expects(:code).returns("404")
                @content.write(@fh).should == nil
            end

            it "should not write anything if source is not found" do
                @response.expects(:code).returns("404")
                @fh.expects(:print).never
                @content.write(@fh).should == nil
            end

            it "should raise an HTTP error in case of server error" do
                @response.expects(:code).returns("500")
                lambda { @content.write(@fh) }.should raise_error
            end

            it "should write content by chunks" do
                @response.expects(:code).returns("200")
                @response.expects(:read_body).multiple_yields("chunk1","chunk2")
                @fh.expects(:print).with("chunk1").then.with("chunk2")
                @content.write(@fh)
            end

            it "should pass each chunk to the current sum stream" do
                @response.expects(:code).returns("200")
                @response.expects(:read_body).multiple_yields("chunk1","chunk2")
                @digest.expects(:<<).with("chunk1").then.with("chunk2")
                @content.write(@fh)
            end

            it "should return the checksum computed" do
                @response.expects(:code).returns("200")
                @response.expects(:read_body).multiple_yields("chunk1","chunk2")
                @sum.expects(:sum_stream).yields(@digest).returns("checksum")
                @content.write(@fh).should == "checksum"
            end

            it "should get the current accept encoding header value" do
                @content.expects(:add_accept_encoding)
                @content.write(@fh)
            end

            it "should uncompress body on error" do
                @response.expects(:code).returns("500")
                @response.expects(:body).returns("compressed body")
                @content.expects(:uncompress_body).with(@response).returns("uncompressed")
                lambda { @content.write(@fh) }.should raise_error { |e| e.message =~ /uncompressed/ }
            end

            it "should uncompress chunk by chunk" do
                uncompressor = stub_everything 'uncompressor'
                @content.expects(:uncompress).with(@response).yields(uncompressor)
                @response.expects(:code).returns("200")
                @response.expects(:read_body).multiple_yields("chunk1","chunk2")

                uncompressor.expects(:uncompress).with("chunk1").then.with("chunk2")
                @content.write(@fh)
            end

            it "should write uncompressed chunks to the file" do
                uncompressor = stub_everything 'uncompressor'
                @content.expects(:uncompress).with(@response).yields(uncompressor)
                @response.expects(:code).returns("200")
                @response.expects(:read_body).multiple_yields("chunk1","chunk2")

                uncompressor.expects(:uncompress).with("chunk1").returns("uncompressed1")
                uncompressor.expects(:uncompress).with("chunk2").returns("uncompressed2")

                @fh.expects(:print).with("uncompressed1")
                @fh.expects(:print).with("uncompressed2")

                @content.write(@fh)
            end

            it "should pass each uncompressed chunk to the current sum stream" do
                uncompressor = stub_everything 'uncompressor'
                @content.expects(:uncompress).with(@response).yields(uncompressor)
                @response.expects(:code).returns("200")
                @response.expects(:read_body).multiple_yields("chunk1","chunk2")

                uncompressor.expects(:uncompress).with("chunk1").returns("uncompressed1")
                uncompressor.expects(:uncompress).with("chunk2").returns("uncompressed2")

                @digest.expects(:<<).with("uncompressed1").then.with("uncompressed2")
                @content.write(@fh)
            end
        end
    end
end
