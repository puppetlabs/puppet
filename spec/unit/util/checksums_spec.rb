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

  it "has a list of known checksum types" do
    expect(@summer.known_checksum_types).to match_array(content_sums + file_only)
  end

  it "returns true if the checksum is valid" do
    expect(@summer).to be_valid_checksum('sha1', 'fcc1715b22278a9dae322b0a34935f10d1608b9f')
  end

  it "returns false if the checksum is known but invalid" do
    expect(@summer).to_not be_valid_checksum('sha1', 'wronglength')
  end

  it "raises if the checksum type is unknown" do
    expect {
      @summer.valid_checksum?('rot13', 'doesntmatter')
    }.to raise_error(NoMethodError, /undefined method/)
  end

  {:md5 => Digest::MD5, :sha1 => Digest::SHA1, :sha256 => Digest::SHA256, :sha512 => Digest::SHA512, :sha384 => Digest::SHA384}.each do |sum, klass|
    describe("when using #{sum}") do
      it "should use #{klass} to calculate string checksums" do
        expect(klass).to receive(:hexdigest).with("mycontent").and_return("whatever")
        expect(@summer.send(sum, "mycontent")).to eq("whatever")
      end

      it "should use incremental #{klass} sums to calculate file checksums" do
        digest = double('digest')
        expect(klass).to receive(:new).and_return(digest)

        file = "/path/to/my/file"

        fh = double('filehandle')
        expect(fh).to receive(:read).with(4096).exactly(3).times().and_return("firstline", "secondline", nil)

        expect(File).to receive(:open).with(file, "rb").and_yield(fh)

        expect(digest).to receive(:<<).with("firstline")
        expect(digest).to receive(:<<).with("secondline")
        expect(digest).to receive(:hexdigest).and_return(:mydigest)

        expect(@summer.send(sum.to_s + "_file", file)).to eq(:mydigest)
      end

      it "should behave like #{klass} to calculate stream checksums" do
        digest = double('digest')
        expect(klass).to receive(:new).and_return(digest)
        expect(digest).to receive(:<<).with "firstline"
        expect(digest).to receive(:<<).with "secondline"
        expect(digest).to receive(:hexdigest).and_return(:mydigest)

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
        expect(klass).to receive(:hexdigest).with(content[0..511]).and_return("whatever")
        expect(@summer.send(sum, content)).to eq("whatever")
      end

      it "should use #{klass} to calculate a sum from the first 512 characters in the file" do
        digest = double('digest')
        expect(klass).to receive(:new).and_return(digest)

        file = "/path/to/my/file"

        fh = double('filehandle')
        expect(fh).to receive(:read).with(512).and_return('my content')

        expect(File).to receive(:open).with(file, "rb").and_yield(fh)

        expect(digest).to receive(:<<).with("my content")
        expect(digest).to receive(:hexdigest).and_return(:mydigest)

        expect(@summer.send(sum.to_s + "_file", file)).to eq(:mydigest)
      end

      it "should use #{klass} to calculate a sum from the first 512 characters in a stream" do
        digest = double('digest')
        content = "this is a test" * 100
        expect(klass).to receive(:new).and_return(digest)
        expect(digest).to receive(:<<).with(content[0..511])
        expect(digest).to receive(:hexdigest).and_return(:mydigest)

        expect(@summer.send(sum.to_s + "_stream") do |checksum|
          checksum << content
        end).to eq(:mydigest)
      end

      it "should use #{klass} to calculate a sum from the first 512 characters in a multi-part stream" do
        digest = double('digest')
        content = "this is a test" * 100
        expect(klass).to receive(:new).and_return(digest)
        expect(digest).to receive(:<<).with(content[0..5])
        expect(digest).to receive(:<<).with(content[6..510])
        expect(digest).to receive(:<<).with(content[511..511])
        expect(digest).to receive(:hexdigest).and_return(:mydigest)

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
        stat = double('stat', sum => "mysum")
        expect(Puppet::FileSystem).to receive(:stat).with(file).and_return(stat)

        expect(@summer.send(sum.to_s + "_file", file)).to eq("mysum")
      end

      it "should return nil for streams" do
        expectation = double("expectation")
        expect(expectation).to receive(:do_something!).at_least(:once)
        expect(@summer.send(sum.to_s + "_stream"){ |checksum| checksum << "anything" ; expectation.do_something!  }).to be_nil
      end
    end
  end

  describe "when using the none checksum" do
    it "should return an empty string" do
      expect(@summer.none_file("/my/file")).to eq("")
    end

    it "should return an empty string for streams" do
      expectation = double("expectation")
      expect(expectation).to receive(:do_something!).at_least(:once)
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
