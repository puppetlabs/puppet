#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/type/file'

describe Puppet::Type::File do
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

    after do
        Puppet::Type::File.clear
    end
end
