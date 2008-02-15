#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/util/checksums'

describe Puppet::Util::Checksums do
    before do
        @summer = Object.new
        @summer.extend(Puppet::Util::Checksums)
    end

    class LineYielder
        def initialize(content)
            @content = content
        end

        def each_line
            @content.split("\n").each { |line| yield line }
        end
    end

    content_sums = [:md5, :md5lite, :sha1, :sha1lite]
    file_only = [:timestamp, :mtime]

    content_sums.each do |sumtype|
        it "should be able to calculate %s sums from strings" % sumtype do
            @summer.should be_respond_to(sumtype)
        end
    end

    [content_sums, file_only].flatten.each do |sumtype|
        it "should be able to calculate %s sums from files" % sumtype do
            @summer.should be_respond_to(sumtype.to_s + "_file")
        end
    end

    {:md5 => Digest::MD5, :sha1 => Digest::SHA1}.each do |sum, klass|
        describe("when using %s" % sum) do
            it "should use #{klass} to calculate string checksums" do
                klass.expects(:hexdigest).with("mycontent").returns "whatever"
                @summer.send(sum, "mycontent").should == "whatever"
            end

            it "should use incremental #{klass} sums to calculate file checksums" do
                digest = mock 'digest'
                klass.expects(:new).returns digest

                file = "/path/to/my/file"

                # Mocha doesn't seem to be able to mock multiple yields, yay.
                fh = LineYielder.new("firstline\nsecondline")

                File.expects(:open).with(file, "r").yields(fh)

                digest.expects(:<<).with "firstline"
                digest.expects(:<<).with "secondline"
                digest.expects(:hexdigest).returns :mydigest

                @summer.send(sum.to_s + "_file", file).should == :mydigest
            end
        end
    end

    {:md5lite => Digest::MD5, :sha1lite => Digest::SHA1}.each do |sum, klass|
        describe("when using %s" % sum) do
            it "should use #{klass} to calculate string checksums from the first 500 characters of the string" do
                content = "this is a test" * 100
                klass.expects(:hexdigest).with(content[0..499]).returns "whatever"
                @summer.send(sum, content).should == "whatever"
            end

            it "should use #{klass} to calculate a sum from the first 500 characters in the file" do
                digest = mock 'digest'

                file = "/path/to/my/file"

                fh = mock 'filehandle'
                File.expects(:open).with(file, "r").yields(fh)

                fh.expects(:read).with(500).returns('my content')

                klass.expects(:hexdigest).with("my content").returns :mydigest

                @summer.send(sum.to_s + "_file", file).should == :mydigest
            end
        end
    end

    {:timestamp => :ctime, :mtime => :mtime}.each do |sum, method|
        describe("when using %s" % sum) do
            it "should use the '#{method}' on the file to determine the timestamp" do
                file = "/my/file"
                stat = mock 'stat', method => "mysum"

                File.expects(:stat).with(file).returns(stat)

                @summer.send(sum.to_s + "_file", file).should == "mysum"
            end
        end
    end
end
