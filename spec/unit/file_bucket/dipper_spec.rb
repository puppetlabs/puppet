#! /usr/bin/env ruby
require 'spec_helper'

require 'pathname'

require 'puppet/file_bucket/dipper'
require 'puppet/indirector/file_bucket_file/rest'
require 'puppet/indirector/file_bucket_file/file'
require 'puppet/util/checksums'

shared_examples_for "a restorable file" do
  let(:dest) { tmpfile('file_bucket_dest') }

  describe "restoring the file" do
    with_digest_algorithms do
      it "should restore the file" do
        request = nil

        klass.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new(plaintext))

        expect(dipper.restore(dest, checksum)).to eq(checksum)
        expect(digest(Puppet::FileSystem.binread(dest))).to eq(checksum)

        expect(request.key).to eq("#{digest_algorithm}/#{checksum}")
        expect(request.server).to eq(server)
        expect(request.port).to eq(port)
      end

      it "should skip restoring if existing file has the same checksum" do
        File.open(dest, 'wb') {|f| f.print(plaintext) }

        dipper.expects(:getfile).never
        expect(dipper.restore(dest, checksum)).to be_nil
      end

      it "should overwrite existing file if it has different checksum" do
        klass.any_instance.expects(:find).returns(Puppet::FileBucket::File.new(plaintext))

        File.open(dest, 'wb') {|f| f.print('other contents') }

        expect(dipper.restore(dest, checksum)).to eq(checksum)
      end
    end
  end
end

describe Puppet::FileBucket::Dipper, :uses_checksums => true do
  include PuppetSpec::Files

  def make_tmp_file(contents)
    file = tmpfile("file_bucket_file")
    File.open(file, 'wb') { |f| f.write(contents) }
    file
  end

  it "should fail in an informative way when there are failures checking for the file on the server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => make_absolute("/my/bucket"))

    file = make_tmp_file('contents')
    Puppet::FileBucket::File.indirection.expects(:head).raises ArgumentError

    expect { @dipper.backup(file) }.to raise_error(Puppet::Error)
  end

  it "should fail in an informative way when there are failures backing up to the server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => make_absolute("/my/bucket"))

    file = make_tmp_file('contents')
    Puppet::FileBucket::File.indirection.expects(:head).returns false
    Puppet::FileBucket::File.indirection.expects(:save).raises ArgumentError

    expect { @dipper.backup(file) }.to raise_error(Puppet::Error)
  end

  describe "when diffing on a local filebucket" do
    describe "in non-windows environments", :unless => Puppet.features.microsoft_windows? do
      with_digest_algorithms do

        it "should fail in an informative way when one or more checksum doesn't exists" do
          @dipper = Puppet::FileBucket::Dipper.new(:Path => tmpdir("bucket"))
          wrong_checksum = "DEADBEEF"

          # First checksum fails
          expect { @dipper.diff(wrong_checksum, "WEIRDCKSM", nil, nil) }.to raise_error(RuntimeError, "Invalid checksum #{wrong_checksum.inspect}")

          file = make_tmp_file(plaintext)
          @dipper.backup(file)

          #Diff_with checksum fails
          expect { @dipper.diff(checksum, wrong_checksum, nil, nil) }.to raise_error(RuntimeError, "could not find diff_with #{wrong_checksum}")
        end

        it "should properly diff files on the filebucket" do
          file1 = make_tmp_file("OriginalContent")
          file2 = make_tmp_file("ModifiedContent")
          @dipper = Puppet::FileBucket::Dipper.new(:Path => tmpdir("bucket"))
          checksum1 = @dipper.backup(file1)
          checksum2 = @dipper.backup(file2)

          # Diff without the context
          diff12 = `diff -uN #{file1} #{file2} | sed '1,2d'`
          diff21 = `diff -uN #{file2} #{file1} | sed '1,2d'`

          expect(@dipper.diff(checksum1, checksum2, nil, nil)).to include(diff12)
          expect(@dipper.diff(checksum1, nil, nil, file2)).to include(diff12)
          expect(@dipper.diff(nil, checksum2, file1, nil)).to include(diff12)
          expect(@dipper.diff(nil, nil, file1, file2)).to include(diff12)
          expect(@dipper.diff(checksum2, checksum1, nil, nil)).to include(diff21)
          expect(@dipper.diff(checksum2, nil, nil, file1)).to include(diff21)
          expect(@dipper.diff(nil, checksum1, file2, nil)).to include(diff21)
          expect(@dipper.diff(nil, nil, file2, file1)).to include(diff21)

        end
      end
      describe "in windows environment", :if => Puppet.features.microsoft_windows? do
        it "should fail in an informative way when trying to diff" do
          @dipper = Puppet::FileBucket::Dipper.new(:Path => tmpdir("bucket"))
          wrong_checksum = "DEADBEEF"

          # First checksum fails
          expect { @dipper.diff(wrong_checksum, "WEIRDCKSM", nil, nil) }.to raise_error(RuntimeError, "Diff is not supported on this platform")

          # Diff_with checksum fails
          expect { @dipper.diff(checksum, wrong_checksum, nil, nil) }.to raise_error(RuntimeError, "Diff is not supported on this platform")
        end
      end
    end
  end

  describe "when diffing on a remote filebucket" do
    describe "in non-windows environments", :unless => Puppet.features.microsoft_windows? do
      with_digest_algorithms do

        it "should fail in an informative way when one or more checksum doesn't exists" do
          @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")
          wrong_checksum = "DEADBEEF"

          Puppet::FileBucketFile::Rest.any_instance.expects(:find).returns(nil)
          expect { @dipper.diff(wrong_checksum, "WEIRDCKSM", nil, nil) }.to raise_error(Puppet::Error, "Failed to diff files")

        end

        it "should properly diff files on the filebucket" do

          @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

          Puppet::FileBucketFile::Rest.any_instance.expects(:find).returns("Probably valid diff")

          expect(@dipper.diff("checksum1", "checksum2", nil, nil)).to eq("Probably valid diff")
        end
      end
    end
    describe "in windows environment", :if => Puppet.features.microsoft_windows? do
      it "should fail in an informative way when trying to diff" do
        @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")
        wrong_checksum = "DEADBEEF"

        expect { @dipper.diff(wrong_checksum, "WEIRDCKSM", nil, nil) }.to raise_error(RuntimeError, "Diff is not supported on this platform")

        expect { @dipper.diff(wrong_checksum, nil, nil, nil) }.to raise_error(RuntimeError, "Diff is not supported on this platform")
      end
    end

  end

  describe "backing up and retrieving local files" do
    with_digest_algorithms do
      it "should backup files to a local bucket" do
        Puppet[:bucketdir] = "/non/existent/directory"
        file_bucket = tmpdir("bucket")

        @dipper = Puppet::FileBucket::Dipper.new(:Path => file_bucket)

        file = make_tmp_file(plaintext)
        expect(digest(plaintext)).to eq(checksum)

        expect(@dipper.backup(file)).to eq(checksum)
        expect(Puppet::FileSystem.exist?("#{file_bucket}/#{bucket_dir}/contents")).to eq(true)
      end

      it "should not backup a file that is already in the bucket" do
        @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

        file = make_tmp_file(plaintext)

        Puppet::FileBucket::File.indirection.expects(:head).returns true
        Puppet::FileBucket::File.indirection.expects(:save).never
        expect(@dipper.backup(file)).to eq(checksum)
      end

      it "should retrieve files from a local bucket" do
        @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

        request = nil

        Puppet::FileBucketFile::File.any_instance.expects(:find).with{ |r| request = r }.once.returns(Puppet::FileBucket::File.new(plaintext))

        expect(@dipper.getfile(checksum)).to eq(plaintext)

        expect(request.key).to eq("#{digest_algorithm}/#{checksum}")
      end
    end
  end

  describe "backing up and retrieving remote files" do
    with_digest_algorithms do
      it "should backup files to a remote server" do
        @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

        file = make_tmp_file(plaintext)

        real_path = Pathname.new(file).realpath

        request1 = nil
        request2 = nil

        Puppet::FileBucketFile::Rest.any_instance.expects(:head).with { |r| request1 = r }.once.returns(nil)
        Puppet::FileBucketFile::Rest.any_instance.expects(:save).with { |r| request2 = r }.once

        expect(@dipper.backup(file)).to eq(checksum)
        [request1, request2].each do |r|
          expect(r.server).to eq('puppetmaster')
          expect(r.port).to eq(31337)
          expect(r.key).to eq("#{digest_algorithm}/#{checksum}/#{real_path}")
        end
      end

      it "should retrieve files from a remote server" do
        @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

        request = nil

        Puppet::FileBucketFile::Rest.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new(plaintext))

        expect(@dipper.getfile(checksum)).to eq(plaintext)

        expect(request.server).to eq('puppetmaster')
        expect(request.port).to eq(31337)
        expect(request.key).to eq("#{digest_algorithm}/#{checksum}")
      end
    end
  end

  describe "#restore" do

    describe "when restoring from a remote server" do
      let(:klass) { Puppet::FileBucketFile::Rest }
      let(:server) { "puppetmaster" }
      let(:port) { 31337 }

      it_behaves_like "a restorable file" do
        let (:dipper) { Puppet::FileBucket::Dipper.new(:Server => server, :Port => port.to_s) }
      end
    end

    describe "when restoring from a local server" do
      let(:klass) { Puppet::FileBucketFile::File }
      let(:server) { nil }
      let(:port) { nil }

      it_behaves_like "a restorable file" do
        let (:dipper) { Puppet::FileBucket::Dipper.new(:Path => "/my/bucket") }
      end
    end
  end
end
