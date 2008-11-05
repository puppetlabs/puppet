#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

content = Puppet::Type.type(:file).attrclass(:content)
describe content do
    before do
        # Wow that's a messy interface to the resource.
        @resource = stub 'resource', :[] => nil, :[]= => nil, :property => nil, :newattr => nil, :parameter => nil
    end

    it "should be a subclass of Property" do
        content.superclass.must == Puppet::Property
    end

    describe "when retrieving the current content" do
        it "should return :absent if the file does not exist" do
            @content = content.new(:resource => @resource)
            @resource.expects(:stat).returns nil

            @content.retrieve.should == :absent
        end

        it "should not manage content on non-files" do
            pending "Haven't decided how this should behave"

            @content = content.new(:resource => @resource)

            stat = mock 'stat', :ftype => "directory"
            @resource.expects(:stat).returns stat

            @content.retrieve.should be_nil
        end

        it "should return the current content of the file if it exists and is a normal file" do
            @content = content.new(:resource => @resource)

            stat = mock 'stat', :ftype => "file"
            @resource.expects(:stat).returns stat

            @resource.expects(:[]).with(:path).returns "/my/file"
            File.expects(:read).with("/my/file").returns "some content"

            @content.retrieve.should == "some content"
        end
    end

    describe "when testing whether the content is in sync" do
        before do
            @resource.stubs(:[]).with(:ensure).returns :file
            @resource.stubs(:replace?).returns true
            @resource.stubs(:should_be_file?).returns true
            @content = content.new(:resource => @resource)
            @content.should = "something"
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

            it "should return true if the current contents are the same as the desired content" do
                @content.should = "some content"
                @content.must be_insync("some content")
            end

            describe "and the content is specified via a remote source" do
                before do
                    @metadata = stub 'metadata'
                    @source = stub 'source', :metadata => @metadata
                    @resource.stubs(:parameter).with(:source).returns @source

                    @content.should = nil
                end

                it "should use checksums to compare remote content, rather than downloading the content" do
                    @content.expects(:md5).with("some content").returns "whatever"
                    @source.stubs(:checksum).returns "{md5}whatever"

                    @content.insync?("some content")
                end

                it "should return false if the current content is different from the remote content" do
                    @source.stubs(:checksum).returns "{md5}whatever"

                    @content.should_not be_insync("some content")
                end

                it "should return true if the current content is the same as the remote content" do
                    sum = @content.md5("some content")
                    @source.stubs(:checksum).returns("{md5}%s" % sum)

                    @content.must be_insync("some content")
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

            @resource.stubs(:[]).with(:path).returns "/boo"
        end

        it "should use the file's :write method to write the content" do
            pending "not switched from :source yet"
            @resource.expects(:write).with("foobar", :content, 123)

            @content.sync
        end

        it "should return :file_changed if the file already existed" do
            pending "not switched from :source yet"
            @resource.stubs(:write)
            FileTest.expects(:exist?).with("/boo").returns true
            @content.sync.should == :file_changed
        end

        it "should return :file_created if the file already existed" do
            pending "not switched from :source yet"
            @resource.stubs(:write)
            FileTest.expects(:exist?).with("/boo").returns false
            @content.sync.should == :file_created
        end
    end
end
