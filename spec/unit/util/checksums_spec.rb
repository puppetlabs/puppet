#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/checksums'

describe Puppet::Util::Checksums do
  include PuppetSpec::Files

  before do
    @summer = Puppet::Util::Checksums
  end

  content_sums = [:md5, :md5lite, :sha1, :sha1lite, :sha256, :sha256lite, :sha512, :sha384, :sha224]
  file_only = [:ctime, :mtime, :none]

  content_sums.each do |sumtype|
    it "should be able to calculate #{sumtype} sums from strings" do
      expect(@summer).to be_respond_to(sumtype)
    end
  end

  content_sums.each do |sumtype|
    it "should know the expected length of #{sumtype} sums" do
      expect(@summer).to be_respond_to(sumtype.to_s + "_hex_length")
    end
  end

  [content_sums, file_only].flatten.each do |sumtype|
    it "should be able to calculate #{sumtype} sums from files" do
      expect(@summer).to be_respond_to(sumtype.to_s + "_file")
    end
  end

  [content_sums, file_only].flatten.each do |sumtype|
    it "should be able to calculate #{sumtype} sums from stream" do
      expect(@summer).to be_respond_to(sumtype.to_s + "_stream")
    end
  end

  it "should have a method for determining whether a given string is a checksum" do
    expect(@summer).to respond_to(:checksum?)
  end

  %w{{md5}asdfasdf {sha1}asdfasdf {ctime}asdasdf {mtime}asdfasdf 
     {sha256}asdfasdf {sha256lite}asdfasdf {sha512}asdfasdf {sha384}asdfasdf {sha224}asdfasdf}.each do |sum|
    it "should consider #{sum} to be a checksum" do
      expect(@summer).to be_checksum(sum)
    end
  end

  %w{{nosuchsumthislong}asdfasdf {a}asdfasdf {ctime}}.each do |sum|
    it "should not consider #{sum} to be a checksum" do
      expect(@summer).not_to be_checksum(sum)
    end
  end

  it "should have a method for stripping a sum type from an existing checksum" do
    expect(@summer.sumtype("{md5}asdfasdfa")).to eq("md5")
  end

  it "should have a method for stripping the data from a checksum" do
    expect(@summer.sumdata("{md5}asdfasdfa")).to eq("asdfasdfa")
  end

  it "should return a nil sumtype if the checksum does not mention a checksum type" do
    expect(@summer.sumtype("asdfasdfa")).to be_nil
  end

  {:md5 => Digest::MD5, :sha1 => Digest::SHA1, :sha256 => Digest::SHA256, :sha512 => Digest::SHA512, :sha384 => Digest::SHA384}.each do |sum, klass|
    describe("when using #{sum}") do
      it "should use #{klass} to calculate string checksums" do
        klass.expects(:hexdigest).with("mycontent").returns "whatever"
        expect(@summer.send(sum, "mycontent")).to eq("whatever")
      end

      it "should use incremental #{klass} sums to calculate file checksums" do
        digest = mock 'digest'
        klass.expects(:new).returns digest

        file = "/path/to/my/file"

        fh = mock 'filehandle'
        fh.expects(:read).with(4096).times(3).returns("firstline").then.returns("secondline").then.returns(nil)

        File.expects(:open).with(file, "rb").yields(fh)

        digest.expects(:<<).with "firstline"
        digest.expects(:<<).with "secondline"
        digest.expects(:hexdigest).returns :mydigest

        expect(@summer.send(sum.to_s + "_file", file)).to eq(:mydigest)
      end

      it "should behave like #{klass} to calculate stream checksums" do
        digest = mock 'digest'
        klass.expects(:new).returns digest
        digest.expects(:<<).with "firstline"
        digest.expects(:<<).with "secondline"
        digest.expects(:hexdigest).returns :mydigest

        expect(@summer.send(sum.to_s + "_stream") do |checksum|
          checksum << "firstline"
          checksum << "secondline"
        end).to eq(:mydigest)
      end
    end
  end

  {:md5lite => Digest::MD5, :sha1lite => Digest::SHA1, :sha256lite => Digest::SHA256}.each do |sum, klass|
    describe("when using #{sum}") do
      it "should use #{klass} to calculate string checksums from the first 512 characters of the string" do
        content = "this is a test" * 100
        klass.expects(:hexdigest).with(content[0..511]).returns "whatever"
        expect(@summer.send(sum, content)).to eq("whatever")
      end

      it "should use #{klass} to calculate a sum from the first 512 characters in the file" do
        digest = mock 'digest'
        klass.expects(:new).returns digest

        file = "/path/to/my/file"

        fh = mock 'filehandle'
        fh.expects(:read).with(512).returns('my content')

        File.expects(:open).with(file, "rb").yields(fh)

        digest.expects(:<<).with "my content"
        digest.expects(:hexdigest).returns :mydigest

        expect(@summer.send(sum.to_s + "_file", file)).to eq(:mydigest)
      end

      it "should use #{klass} to calculate a sum from the first 512 characters in a stream" do
        digest = mock 'digest'
        content = "this is a test" * 100
        klass.expects(:new).returns digest
        digest.expects(:<<).with content[0..511]
        digest.expects(:hexdigest).returns :mydigest

        expect(@summer.send(sum.to_s + "_stream") do |checksum|
          checksum << content
        end).to eq(:mydigest)
      end

      it "should use #{klass} to calculate a sum from the first 512 characters in a multi-part stream" do
        digest = mock 'digest'
        content = "this is a test" * 100
        klass.expects(:new).returns digest
        digest.expects(:<<).with content[0..5]
        digest.expects(:<<).with content[6..510]
        digest.expects(:<<).with content[511..511]
        digest.expects(:hexdigest).returns :mydigest

        expect(@summer.send(sum.to_s + "_stream") do |checksum|
          checksum << content[0..5]
          checksum << content[6..510]
          checksum << content[511..-1]
        end).to eq(:mydigest)
      end
    end
  end

  [:ctime, :mtime].each do |sum|
    describe("when using #{sum}") do
      it "should use the '#{sum}' on the file to determine the ctime" do
        file = "/my/file"
        stat = mock 'stat', sum => "mysum"
        Puppet::FileSystem.expects(:stat).with(file).returns(stat)

        expect(@summer.send(sum.to_s + "_file", file)).to eq("mysum")
      end

      it "should return nil for streams" do
        expectation = stub "expectation"
        expectation.expects(:do_something!).at_least_once
        expect(@summer.send(sum.to_s + "_stream"){ |checksum| checksum << "anything" ; expectation.do_something!  }).to be_nil
      end
    end
  end

  describe "when using the none checksum" do
    it "should return an empty string" do
      expect(@summer.none_file("/my/file")).to eq("")
    end

    it "should return an empty string for streams" do
      expectation = stub "expectation"
      expectation.expects(:do_something!).at_least_once
      expect(@summer.none_stream{ |checksum| checksum << "anything" ; expectation.do_something!  }).to eq("")
    end
  end

  {:md5 => Digest::MD5, :sha1 => Digest::SHA1}.each do |sum, klass|
    describe "when using #{sum}" do
      let(:content) { "hello\r\nworld" }
      let(:path) do
        path = tmpfile("checksum_#{sum}")
        File.open(path, 'wb') {|f| f.write(content)}
        path
      end

      it "should preserve nl/cr sequences" do
        expect(@summer.send(sum.to_s + "_file", path)).to eq(klass.hexdigest(content))
      end
    end
  end
end
