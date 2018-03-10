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
          file1 = make_tmp_file("OriginalContent\n")
          file2 = make_tmp_file("ModifiedContent\n")
          @dipper = Puppet::FileBucket::Dipper.new(:Path => tmpdir("bucket"))
          checksum1 = @dipper.backup(file1)
          checksum2 = @dipper.backup(file2)

          # Diff without the context
          # Lines we need to see match 'Content' instead of trimming diff output filter out
          # surrounding noise...or hard code the check values
          if Facter.value(:osfamily) == 'Solaris' &&
            Puppet::Util::Package.versioncmp(Facter.value(:operatingsystemrelease), '11.0') >= 0
            # Use gdiff on Solaris
            diff12 = Puppet::Util::Execution.execute("gdiff -uN #{file1} #{file2}| grep Content")
            diff21 = Puppet::Util::Execution.execute("gdiff -uN #{file2} #{file1}| grep Content")
          else
            diff12 = Puppet::Util::Execution.execute("diff -uN #{file1} #{file2}| grep Content")
            diff21 = Puppet::Util::Execution.execute("diff -uN #{file2} #{file1}| grep Content")
          end

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
  it "should fail in an informative way when there are failures listing files on the server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/unexistent/bucket")
    Puppet::FileBucket::File.indirection.expects(:find).returns nil

    expect { @dipper.list(nil, nil) }.to raise_error(Puppet::Error)
  end

  describe "listing files in local filebucket" do
    with_digest_algorithms do
      it "should list all files present" do
        if Puppet::Util::Platform.windows? && digest_algorithm == "sha512"
          skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
        end
        Puppet[:bucketdir] =  "/my/bucket"
        file_bucket = tmpdir("bucket")

        @dipper = Puppet::FileBucket::Dipper.new(:Path => file_bucket)

        #First File
        file1 = make_tmp_file(plaintext)
        real_path = Pathname.new(file1).realpath
        expect(digest(plaintext)).to eq(checksum)
        expect(@dipper.backup(file1)).to eq(checksum)
        expected_list1_1 = /#{checksum} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} #{real_path}\n/

        File.open(file1, 'w') {|f| f.write("Blahhhh")}
        new_checksum = digest("Blahhhh")
        expect(@dipper.backup(file1)).to eq(new_checksum)
        expected_list1_2 = /#{new_checksum} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} #{real_path}\n/

        #Second File
        content = "DummyFileWithNonSenseTextInIt"
        file2 = make_tmp_file(content)
        real_path = Pathname.new(file2).realpath
        checksum = digest(content)
        expect(@dipper.backup(file2)).to eq(checksum)
        expected_list2 = /#{checksum} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} #{real_path}\n/

        #Third file : Same as the first one with a different path
        file3 = make_tmp_file(plaintext)
        real_path = Pathname.new(file3).realpath
        checksum = digest(plaintext)
        expect(digest(plaintext)).to eq(checksum)
        expect(@dipper.backup(file3)).to eq(checksum)
        expected_list3 = /#{checksum} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} #{real_path}\n/

        result = @dipper.list(nil, nil)
        expect(result).to match(expected_list1_1)
        expect(result).to match(expected_list1_2)
        expect(result).to match(expected_list2)
        expect(result).to match(expected_list3)
      end

      it "should filter with the provided dates" do
        if Puppet::Util::Platform.windows? && digest_algorithm == "sha512"
          skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
        end
        Puppet[:bucketdir] =  "/my/bucket"
        file_bucket = tmpdir("bucket")

        twentyminutes=60*20
        thirtyminutes=60*30
        onehour=60*60
        twohours=onehour*2
        threehours=onehour*3

        # First File created now
        @dipper = Puppet::FileBucket::Dipper.new(:Path => file_bucket)
        file1 = make_tmp_file(plaintext)
        real_path = Pathname.new(file1).realpath

        expect(digest(plaintext)).to eq(checksum)
        expect(@dipper.backup(file1)).to eq(checksum)
        expected_list1 = /#{checksum} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} #{real_path}\n/

        # Second File created an hour ago
        content = "DummyFileWithNonSenseTextInIt"
        file2 = make_tmp_file(content)
        real_path = Pathname.new(file2).realpath
        checksum = digest(content)
        expect(@dipper.backup(file2)).to eq(checksum)

        # Modify mtime of the second file to be an hour ago
        onehourago = Time.now - onehour
        bucketed_paths_file = Dir.glob("#{file_bucket}/**/#{checksum}/paths")
        FileUtils.touch(bucketed_paths_file, :mtime => onehourago)
        expected_list2 = /#{checksum} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} #{real_path}\n/

        now = Time.now

        #Future
        expect(@dipper.list((now + threehours).strftime("%F %T"), nil )).to eq("")

        #Epoch -> Future = Everything (Sorted (desc) by date)
        expect(@dipper.list(nil, (now + twohours).strftime("%F %T"))).to match(expected_list1)
        expect(@dipper.list(nil, (now + twohours).strftime("%F %T"))).to match(expected_list2)

        #Now+1sec -> Future = Nothing
        expect(@dipper.list((now + 1).strftime("%F %T"), (now + twohours).strftime("%F %T"))).to eq("")

        #Now-30mins -> Now-20mins = Nothing
        expect(@dipper.list((now - thirtyminutes).strftime("%F %T"), (now - twentyminutes).strftime("%F %T"))).to eq("")

        #Now-2hours -> Now-30mins = Second file only
        expect(@dipper.list((now - twohours).strftime("%F %T"), (now - thirtyminutes).strftime("%F %T"))).to match(expected_list2)
        expect(@dipper.list((now - twohours).strftime("%F %T"), (now - thirtyminutes).strftime("%F %T"))).not_to match(expected_list1)

        #Now-30minutes -> Now = First file only
        expect(@dipper.list((now - thirtyminutes).strftime("%F %T"), now.strftime("%F %T"))).to match(expected_list1)
        expect(@dipper.list((now - thirtyminutes).strftime("%F %T"), now.strftime("%F %T"))).not_to match(expected_list2)
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

  describe "listing files in remote filebucket" do
    it "is not allowed" do
      @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port=> "31337")

      expect {
        @dipper.list(nil, nil)
      }.to raise_error(Puppet::Error, "Listing remote file buckets is not allowed")
    end
  end

  describe "backing up and retrieving local files" do
    with_digest_algorithms do
      it "should backup files to a local bucket" do
        if Puppet::Util::Platform.windows? && digest_algorithm == "sha512"
          skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
        end
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

        Puppet::FileBucket::File.indirection.expects(:head).with(
          regexp_matches(%r{#{digest_algorithm}/#{checksum}}), :bucket_path => "/my/bucket"
        ).returns true
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
