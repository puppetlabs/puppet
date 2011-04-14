#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/util/checksums'

describe Puppet::Util::Checksums do
  before do
    @summer = Object.new
    @summer.extend(Puppet::Util::Checksums)
  end

  content_sums = [:md5, :md5lite, :sha1, :sha1lite]
  file_only = [:ctime, :mtime, :none]

  content_sums.each do |sumtype|
    it "should be able to calculate #{sumtype} sums from strings" do
      @summer.should be_respond_to(sumtype)
    end
  end

  [content_sums, file_only].flatten.each do |sumtype|
    it "should be able to calculate #{sumtype} sums from files" do
      @summer.should be_respond_to(sumtype.to_s + "_file")
    end
  end

  [content_sums, file_only].flatten.each do |sumtype|
    it "should be able to calculate #{sumtype} sums from stream" do
      @summer.should be_respond_to(sumtype.to_s + "_stream")
    end
  end

  it "should have a method for determining whether a given string is a checksum" do
    @summer.should respond_to(:checksum?)
  end

  %w{{md5}asdfasdf {sha1}asdfasdf {ctime}asdasdf {mtime}asdfasdf}.each do |sum|
    it "should consider #{sum} to be a checksum" do
      @summer.should be_checksum(sum)
    end
  end

  %w{{nosuchsum}asdfasdf {a}asdfasdf {ctime}}.each do |sum|
    it "should not consider #{sum} to be a checksum" do
      @summer.should_not be_checksum(sum)
    end
  end

  it "should have a method for stripping a sum type from an existing checksum" do
    @summer.sumtype("{md5}asdfasdfa").should == "md5"
  end

  it "should have a method for stripping the data from a checksum" do
    @summer.sumdata("{md5}asdfasdfa").should == "asdfasdfa"
  end

  it "should return a nil sumtype if the checksum does not mention a checksum type" do
    @summer.sumtype("asdfasdfa").should be_nil
  end

  {:md5 => Digest::MD5, :sha1 => Digest::SHA1}.each do |sum, klass|
    describe("when using #{sum}") do
      it "should use #{klass} to calculate string checksums" do
        klass.expects(:hexdigest).with("mycontent").returns "whatever"
        @summer.send(sum, "mycontent").should == "whatever"
      end

      it "should use incremental #{klass} sums to calculate file checksums" do
        digest = mock 'digest'
        klass.expects(:new).returns digest

        file = "/path/to/my/file"

        fh = mock 'filehandle'
        fh.expects(:read).with(4096).times(3).returns("firstline").then.returns("secondline").then.returns(nil)
        #fh.expects(:read).with(512).returns("secondline")
        #fh.expects(:read).with(512).returns(nil)

        File.expects(:open).with(file, "r").yields(fh)

        digest.expects(:<<).with "firstline"
        digest.expects(:<<).with "secondline"
        digest.expects(:hexdigest).returns :mydigest

        @summer.send(sum.to_s + "_file", file).should == :mydigest
      end

      it "should yield #{klass} to the given block to calculate stream checksums" do
        digest = mock 'digest'
        klass.expects(:new).returns digest
        digest.expects(:hexdigest).returns :mydigest

        @summer.send(sum.to_s + "_stream") do |sum|
          sum.should == digest
        end.should == :mydigest
      end
    end
  end

  {:md5lite => Digest::MD5, :sha1lite => Digest::SHA1}.each do |sum, klass|
    describe("when using #{sum}") do
      it "should use #{klass} to calculate string checksums from the first 512 characters of the string" do
        content = "this is a test" * 100
        klass.expects(:hexdigest).with(content[0..511]).returns "whatever"
        @summer.send(sum, content).should == "whatever"
      end

      it "should use #{klass} to calculate a sum from the first 512 characters in the file" do
        digest = mock 'digest'
        klass.expects(:new).returns digest

        file = "/path/to/my/file"

        fh = mock 'filehandle'
        fh.expects(:read).with(512).returns('my content')

        File.expects(:open).with(file, "r").yields(fh)

        digest.expects(:<<).with "my content"
        digest.expects(:hexdigest).returns :mydigest

        @summer.send(sum.to_s + "_file", file).should == :mydigest
      end
    end
  end

  [:ctime, :mtime].each do |sum|
    describe("when using #{sum}") do
      it "should use the '#{sum}' on the file to determine the ctime" do
        file = "/my/file"
        stat = mock 'stat', sum => "mysum"

        File.expects(:stat).with(file).returns(stat)

        @summer.send(sum.to_s + "_file", file).should == "mysum"
      end

      it "should return nil for streams" do
        expectation = stub "expectation"
        expectation.expects(:do_something!).at_least_once
        @summer.send(sum.to_s + "_stream"){ |checksum| checksum << "anything" ; expectation.do_something!  }.should be_nil
      end
    end
  end

  describe "when using the none checksum" do
    it "should return an empty string" do
      @summer.none_file("/my/file").should == ""
    end

    it "should return an empty string for streams" do
      expectation = stub "expectation"
      expectation.expects(:do_something!).at_least_once
      @summer.none_stream{ |checksum| checksum << "anything" ; expectation.do_something!  }.should == ""
    end
  end
end
