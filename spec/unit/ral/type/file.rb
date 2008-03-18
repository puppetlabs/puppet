#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Type.type(:file) do
    before do
        @path = Tempfile.new("puppetspec")
        @path.close!()
        @path = @path.path
        @file = Puppet::Type::File.create(:name => @path)
    end

    describe "when used with content and replace=>false" do
        before do
            @file[:content] = "foo"
            @file[:replace] = false
        end

        it "should be insync if the file exists and the content is different" do
            File.open(@path, "w") do |f| f.puts "bar" end
            @file.property(:content).insync?("bar").should be_true
        end

        it "should be insync if the file exists and the content is right" do
            File.open(@path, "w") do |f| f.puts "foo" end
            @file.property(:content).insync?("foo").should be_true
        end

        it "should not be insync if the file does not exist" do
            @file.property(:content).insync?(:nil).should be_false
        end
    end

    describe "when retrieving remote files" do
        before do
            @filesource = Puppet::Type::File::FileSource.new
            @filesource.server = mock 'fileserver'

            @file.stubs(:uri2obj).returns(@filesource)

            @file[:source] = "puppet:///test"
        end

        it "should fail without writing if it cannot retrieve remote contents" do
            # create the file, because we only get the problem when it starts
            # out absent.
            File.open(@file[:path], "w") { |f| f.puts "a" }
            @file.expects(:write).never

            @filesource.server.stubs(:describe).returns("493\tfile\t100\t0\t{md5}3f5fef3bddbc4398c46a7bd7ba7b3af7")
            @filesource.server.stubs(:retrieve).raises(RuntimeError)
            @file.property(:source).retrieve
            lambda { @file.property(:source).sync }.should raise_error(Puppet::Error)
        end
    end

    describe "when managing links" do
        require 'puppettest/support/assertions'
        include PuppetTest
        require 'tempfile'

        before do
            @basedir = tempfile
            Dir.mkdir(@basedir)
            @file = File.join(@basedir, "file")
            @link = File.join(@basedir, "link")

            File.open(@file, "w", 0644) { |f| f.puts "yayness"; f.flush }
            File.symlink(@file, @link)

            @resource = Puppet.type(:file).create(
                :path => @link,
                :mode => "755"
            )
            @catalog = Puppet::Node::Catalog.new
            @catalog.add_resource @resource
        end

        after do
            remove_tmp_files
        end

        it "should default to managing the link" do
            @catalog.apply
            # I convert them to strings so they display correctly if there's an error.
            ("%o" % (File.stat(@file).mode & 007777)).should == "%o" % 0644
        end

        it "should be able to follow links" do
            @resource[:links] = :follow
            @catalog.apply

            ("%o" % (File.stat(@file).mode & 007777)).should == "%o" % 0755
        end
    end

    after do
        Puppet::Type::File.clear
    end
end
