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

        it "should use the content from the source if the source is set" do
            source = mock 'source'
            source.expects(:content).returns "scont"

            @resource.expects(:parameter).with(:source).returns source

            @content = content.new(:resource => @resource)
            @content.actual_content.should == "scont"
        end

        it "should fail if no source is available and no content is set" do
            @content = content.new(:resource => @resource)
            lambda { @content.actual_content }.should raise_error(Puppet::Error)
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
            @resource.expects(:write).with("some content", :content)

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
end
