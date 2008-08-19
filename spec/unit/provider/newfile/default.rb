#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider = Puppet::Type.type(:newfile).provider(:default)

describe provider do
    %w{content owner group mode}.each do |attr|
        it "should be able to determine the '#{attr}'" do
            provider.new({}).should respond_to(attr)
        end

        it "should be able to set the '#{attr}'" do
            provider.new({}).should respond_to(attr + "=")
        end
    end

    it "should be able to determine the 'type'" do
        provider.new({}).should respond_to(:type)
    end

    it "should be able to tell if the file exists" do
        provider.new({}).should respond_to(:exist?)
    end

    it "should be able to create a file" do
        provider.new({}).should respond_to(:mkfile)
    end

    it "should be able to create a directory" do
        provider.new({}).should respond_to(:mkdir)
    end

    it "should be able to create a symlink" do
        provider.new({}).should respond_to(:mklink)
    end

    it "should be able to destroy the file" do
        provider.new({}).should respond_to(:destroy)
    end

    describe "when retrieving current state" do
        before do
            @file = provider.new :name => "/foo/bar"
        end

        it "should not stat() the file more than once per transaction" do
            stat = mock('stat')
            File.expects(:stat).with("/foo/bar").returns stat
            @file.exist?
            @file.exist?
        end

        it "should remove the cached stat after it has been flushed" do
            File.expects(:stat).times(2).with("/foo/bar").returns "foo"
            @file.exist?
            @file.flush
            @file.exist?
        end

        describe "and the file does not exist" do
            before do
                File.stubs(:stat).with("/foo/bar").returns nil
            end

            it "should correctly detect the file's absence" do
                @file.should_not be_exist
            end

            it "should consider the type to be absent" do
                @file.type.should == :absent
            end

            it "should consider the owner to be absent" do
                @file.owner.should == :absent
            end

            it "should consider the group to be absent" do
                @file.group.should == :absent
            end

            it "should consider the mode to be absent" do
                @file.mode.should == :absent
            end

            it "should consider the content to be absent" do
                @file.content.should == :absent
            end
        end

        describe "and the file exists" do
            before do
                @stat = mock 'stat'
                File.stubs(:stat).with("/foo/bar").returns @stat
            end

            it "should correctly detect the file's presence" do
                @file.should be_exist
            end

            it "should return the filetype as the type" do
                @stat.expects(:ftype).returns "file"
                @file.type.should == "file"
            end

            it "should return the Stat UID as the owner" do
                @stat.expects(:uid).returns 50
                @file.owner.should == 50
            end

            it "should return the Stat GID as the group" do
                @stat.expects(:gid).returns 50
                @file.group.should == 50
            end

            it "should return the Stat mode, shifted accordingly, as the mode" do
                @stat.expects(:mode).returns 16877
                @file.mode.should == 493 # 755 in decimal
            end

            it "should return the contents of the file as the content" do
                File.expects(:read).with("/foo/bar").returns "fooness"
                @file.content.should == "fooness"
            end

            it "should fail appropriately when reading the file's content fails" do
                File.expects(:read).with("/foo/bar").raises RuntimeError
                lambda { @file.content }.should raise_error(Puppet::Error)
            end
        end
    end

    describe "when creating the file" do
        before do
            @file = provider.new :name => "/foo/bar"
        end

        it "should create a directory when asked" do
            Dir.expects(:mkdir).with("/foo/bar")
            @file.mkdir
        end

        it "should indicate a problem with the parent directory if Errno::ENOENT is thrown when creating the directory" do
            Dir.expects(:mkdir).with("/foo/bar").raises Errno::ENOENT
            lambda { @file.mkdir }.should raise_error(Puppet::Error)
        end

        it "should fail helpfully if a different problem creating the directory is encountered" do
            Dir.expects(:mkdir).with("/foo/bar").raises RuntimeError
            lambda { @file.mkdir }.should raise_error(Puppet::Error)
        end
    end

    describe "when changing the file" do
        before do
            @file = provider.new :name => "/foo/bar"
        end

        it "should chown the file to the provided UID when setting the owner" do
            File.expects(:chown).with(50, nil, "/foo/bar")
            @file.owner = 50
        end

        it "should chown the file to the provided GID when setting the group" do
            File.expects(:chown).with(nil, 50, "/foo/bar")
            @file.group = 50
        end

        it "should chmod the file to the provided mode when setting the mode" do
            File.expects(:chmod).with(493, "/foo/bar") # decimal, not octal
            @file.mode = 493
        end

        it "should write the provided contents to the file when the content is set" do
            fh = mock 'fh'
            File.expects(:open).with("/foo/bar", "w").yields fh
            fh.expects(:print).with "foo"
            @file.content = "foo"
        end
    end
end
