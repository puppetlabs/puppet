#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_bucket_file/file'
require 'puppet/util/platform'

describe Puppet::FileBucketFile::File, :uses_checksums => true do
  include PuppetSpec::Files

  describe "non-stubbing tests" do
    include PuppetSpec::Files

    def save_bucket_file(contents, path = "/who_cares")
      bucket_file = Puppet::FileBucket::File.new(contents)
      Puppet::FileBucket::File.indirection.save(bucket_file, "#{bucket_file.name}#{path}")
      bucket_file.checksum_data
    end

    describe "when servicing a save request" do
      it "should return a result whose content is empty" do
        bucket_file = Puppet::FileBucket::File.new('stuff')
        result = Puppet::FileBucket::File.indirection.save(bucket_file, "md5/c13d88cb4cb02003daedb8a84e5d272a")
        expect(result.contents).to be_empty
      end

      it "deals with multiple processes saving at the same time", :unless => Puppet::Util::Platform.windows? do
        bucket_file = Puppet::FileBucket::File.new("contents")

        children = []
        5.times do |count|
          children << Kernel.fork do
            save_bucket_file("contents", "/testing")
            exit(0)
          end
        end
        children.each { |child| Process.wait(child) }

        paths = File.read("#{Puppet[:bucketdir]}/9/8/b/f/7/d/8/c/98bf7d8c15784f0a3d63204441e1e2aa/paths").lines.to_a
        expect(paths.length).to eq(1)
        expect(Puppet::FileBucket::File.indirection.head("#{bucket_file.checksum_type}/#{bucket_file.checksum_data}/testing")).to be_truthy
      end

      it "fails if the contents collide with existing contents" do
        # This is the shortest known MD5 collision (little endian). See https://eprint.iacr.org/2010/643.pdf
        first_contents = [0x6165300e,0x87a79a55,0xf7c60bd0,0x34febd0b,
                          0x6503cf04,0x854f709e,0xfb0fc034,0x874c9c65,
                          0x2f94cc40,0x15a12deb,0x5c15f4a3,0x490786bb,
                          0x6d658673,0xa4341f7d,0x8fd75920,0xefd18d5a].pack("V" * 16)

        collision_contents = [0x6165300e,0x87a79a55,0xf7c60bd0,0x34febd0b,
                              0x6503cf04,0x854f749e,0xfb0fc034,0x874c9c65,
                              0x2f94cc40,0x15a12deb,0xdc15f4a3,0x490786bb,
                              0x6d658673,0xa4341f7d,0x8fd75920,0xefd18d5a].pack("V" * 16)

        checksum_value = save_bucket_file(first_contents, "/foo/bar")

        # We expect Puppet to log an error with the path to the file
        Puppet.expects(:err).with(regexp_matches(/Unable to verify existing FileBucket backup at '#{Puppet[:bucketdir]}.*#{checksum_value}\/contents'/))

        # But the exception should not contain it
        expect do
          save_bucket_file(collision_contents, "/foo/bar")
        end.to raise_error(Puppet::FileBucket::BucketError, /\AExisting backup and new file have different content but same checksum, {md5}#{checksum_value}\. Verify existing backup and remove if incorrect\.\Z/)
      end

      # See PUP-1334
      context "when the contents file exists but is corrupted and does not match the expected checksum" do
        let(:original_contents) { "a file that will get corrupted" }
        let(:bucket_file) { Puppet::FileBucket::File.new(original_contents) }
        let(:contents_file) { "#{Puppet[:bucketdir]}/8/e/6/4/f/8/5/d/8e64f85dd54a412f65edabcafe44d491/contents" }

        before(:each) do
          # Ensure we're starting with a clean slate - no pre-existing backup
          Puppet::FileSystem.unlink(contents_file) if Puppet::FileSystem.exist?(contents_file)
          # Create initial "correct" backup
          Puppet::FileBucket::File.indirection.save(bucket_file)
          # Modify the contents file so that it no longer matches the SHA, simulating a corrupt backup
          Puppet::FileSystem.unlink(contents_file) # bucket_files are read-only
          Puppet::Util.replace_file(contents_file, 0600) { |fh| fh.puts "now with corrupted content" }
        end

        it "issues a warning that the backup will be overwritten" do
          Puppet.expects(:warning).with(regexp_matches(/Existing backup does not match its expected sum, #{bucket_file.checksum}/))
          Puppet::FileBucket::File.indirection.save(bucket_file)
        end

        it "overwrites the existing contents file (backup)" do
          Puppet::FileBucket::File.indirection.save(bucket_file)
          expect(Puppet::FileSystem.read(contents_file)).to eq(original_contents)
        end
      end

      describe "when supplying a path" do
        with_digest_algorithms do
            it "should store the path if not already stored" do
              if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
                skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
              else
                save_bucket_file(plaintext, "/foo/bar")
  
                dir_path = "#{Puppet[:bucketdir]}/#{bucket_dir}"
                contents_file = "#{dir_path}/contents"
                paths_file = "#{dir_path}/paths"
                expect(Puppet::FileSystem.binread(contents_file)).to eq(plaintext)
                expect(Puppet::FileSystem.read(paths_file)).to eq("foo/bar\n")
              end
            end
  
            it "should leave the paths file alone if the path is already stored" do
              if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
                skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
              else
                checksum = save_bucket_file(plaintext, "/foo/bar")
                checksum = save_bucket_file(plaintext, "/foo/bar")
                dir_path = "#{Puppet[:bucketdir]}/#{bucket_dir}"
                expect(Puppet::FileSystem.binread("#{dir_path}/contents")).to eq(plaintext)
                expect(File.read("#{dir_path}/paths")).to eq("foo/bar\n")
              end
            end
  
            it "should store an additional path if the new path differs from those already stored" do
              if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
                skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
              else
                checksum = save_bucket_file(plaintext, "/foo/bar")
                checksum = save_bucket_file(plaintext, "/foo/baz")
                dir_path = "#{Puppet[:bucketdir]}/#{bucket_dir}"
                expect(Puppet::FileSystem.binread("#{dir_path}/contents")).to eq(plaintext)
                expect(File.read("#{dir_path}/paths")).to eq("foo/bar\nfoo/baz\n")
              end
            end
          # end
        end
      end

      describe "when not supplying a path" do
        with_digest_algorithms do
          it "should save the file and create an empty paths file" do
            if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
              skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
            else
              save_bucket_file(plaintext, "")
  
              dir_path = "#{Puppet[:bucketdir]}/#{bucket_dir}"
              expect(Puppet::FileSystem.binread("#{dir_path}/contents")).to eq(plaintext)
              expect(File.read("#{dir_path}/paths")).to eq("")
            end
          end
        end
      end
    end

    describe "when servicing a head/find request" do
      with_digest_algorithms do
        let(:not_bucketed_plaintext) { "other stuff" }
        let(:not_bucketed_checksum) { digest(not_bucketed_plaintext) }

        describe "when listing the filebucket" do
          it "should return false/nil when the bucket is empty" do
            expect(Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{not_bucketed_checksum}/foo/bar", :list_all => true)).to eq(nil)
          end

          it "raises when the request is remote" do
            Puppet[:bucketdir] = tmpdir('bucket')

            request = Puppet::Indirector::Request.new(:file_bucket_file, :find, "#{digest_algorithm}/#{checksum}/foo/bar", nil, :list_all => true)
            request.node = 'client.example.com'

            expect {
              Puppet::FileBucketFile::File.new.find(request)
            }.to raise_error(Puppet::Error, "Listing remote file buckets is not allowed")
          end

          it "should return the list of bucketed files in a human readable way" do
            if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
              skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
            else
              checksum1 = save_bucket_file("I'm the contents of a file", '/foo/bar1')
              checksum2 = save_bucket_file("I'm the contents of another file", '/foo/bar2')
              checksum3 = save_bucket_file("I'm the modified content of a existing file", '/foo/bar1')
  
              # Use the first checksum as we know it's stored in the bucket
              find_result = Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{checksum1}/foo/bar1", :list_all => true)
  
              # The list is sort order from date and file name, so first and third checksums come before the second
              date_pattern = '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
              expect(find_result.to_s).to match(Regexp.new("^(#{checksum1}|#{checksum3}) #{date_pattern} foo/bar1\\n(#{checksum3}|#{checksum1}) #{date_pattern} foo/bar1\\n#{checksum2} #{date_pattern} foo/bar2\\n$"))
            end
          end

          it "should fail in an informative way when provided dates are not in the right format" do
            if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
              skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
            else
              contents = "I'm the contents of a file"
              save_bucket_file(contents, '/foo/bar1')
              expect {
                Puppet::FileBucket::File.indirection.find(
                  "#{digest_algorithm}/#{not_bucketed_checksum}/foo/bar",
                  :list_all => true,
                  :todate => "0:0:0 1-1-1970",
                  :fromdate => "WEIRD"
                )
              }.to raise_error(Puppet::Error, /fromdate/)
              expect {
                Puppet::FileBucket::File.indirection.find(
                  "#{digest_algorithm}/#{not_bucketed_checksum}/foo/bar",
                  :list_all => true,
                  :todate => "WEIRD",
                  :fromdate => Time.now
                )
              }.to raise_error(Puppet::Error, /todate/)
            end
          end
        end

        describe "when supplying a path" do
          it "should return false/nil if the file isn't bucketed" do
            expect(Puppet::FileBucket::File.indirection.head("#{digest_algorithm}/#{not_bucketed_checksum}/foo/bar")).to eq(false)
            expect(Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{not_bucketed_checksum}/foo/bar")).to eq(nil)
          end

          it "should return false/nil if the file is bucketed but with a different path" do

            if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
              skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
            else
              checksum = save_bucket_file("I'm the contents of a file", '/foo/bar')
  
              expect(Puppet::FileBucket::File.indirection.head("#{digest_algorithm}/#{checksum}/foo/baz")).to eq(false)
              expect(Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{checksum}/foo/baz")).to eq(nil)
            end
          end

          it "should return true/file if the file is already bucketed with the given path" do
            if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
              skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
            else
              contents = "I'm the contents of a file"
  
              checksum = save_bucket_file(contents, '/foo/bar')
  
              expect(Puppet::FileBucket::File.indirection.head("#{digest_algorithm}/#{checksum}/foo/bar")).to eq(true)
              find_result = Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{checksum}/foo/bar")
              expect(find_result.checksum).to eq("{#{digest_algorithm}}#{checksum}")
              expect(find_result.to_s).to eq(contents)
            end
          end
        end

        describe "when not supplying a path" do
          [false, true].each do |trailing_slash|
            describe "#{trailing_slash ? 'with' : 'without'} a trailing slash" do
              trailing_string = trailing_slash ? '/' : ''

              it "should return false/nil if the file isn't bucketed" do
                expect(Puppet::FileBucket::File.indirection.head("#{digest_algorithm}/#{not_bucketed_checksum}#{trailing_string}")).to eq(false)
                expect(Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{not_bucketed_checksum}#{trailing_string}")).to eq(nil)
              end

              it "should return true/file if the file is already bucketed" do
    
                # this one replaces most of the lets in the "when
                # digest_digest_algorithm is set..." shared context, but it still needs digest_algorithm
                if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
                  skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
                else
                  contents = "I'm the contents of a file"
  
                  checksum = save_bucket_file(contents, '/foo/bar')
  
                  expect(Puppet::FileBucket::File.indirection.head("#{digest_algorithm}/#{checksum}#{trailing_string}")).to eq(true)
                  find_result = Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{checksum}#{trailing_string}")
                  expect(find_result.checksum).to eq("{#{digest_algorithm}}#{checksum}")
                  expect(find_result.to_s).to eq(contents)
                end
              end
            end
          end
        end
      end
    end

    describe "when diffing files", :unless => Puppet.features.microsoft_windows? do
      with_digest_algorithms do
        let(:not_bucketed_plaintext) { "other stuff" }
        let(:not_bucketed_checksum) { digest(not_bucketed_plaintext) }

        it "should generate an empty string if there is no diff" do
          if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
            skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
          else
            checksum = save_bucket_file("I'm the contents of a file")
            expect(Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{checksum}", :diff_with => checksum)).to eq('')
          end
        end

        it "should generate a proper diff if there is a diff" do
          if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
            skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
          else
            checksum1 = save_bucket_file("foo\nbar\nbaz")
            checksum2 = save_bucket_file("foo\nbiz\nbaz")
  
            diff = Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{checksum1}", :diff_with => checksum2)
            expect(diff).to include("-bar\n+biz\n")
          end
        end

        it "should raise an exception if the hash to diff against isn't found" do
          if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
            skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
          else
            checksum = save_bucket_file("whatever")
  
            expect do
              Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{checksum}", :diff_with => not_bucketed_checksum)
            end.to raise_error "could not find diff_with #{not_bucketed_checksum}"
          end
        end

        it "should return nil if the hash to diff from isn't found" do
          if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
            skip "PUP-8257: Skip file bucket test on windows for #{digest_algorithm} due to long path names"
          else
            checksum = save_bucket_file("whatever")
  
            expect(Puppet::FileBucket::File.indirection.find("#{digest_algorithm}/#{not_bucketed_checksum}", :diff_with => checksum)).to eq(nil)
          end
        end
      end
    end
  end

  [true, false].each do |override_bucket_path|
    describe "when bucket path #{override_bucket_path ? 'is' : 'is not'} overridden" do
      [true, false].each do |supply_path|
        describe "when #{supply_path ? 'supplying' : 'not supplying'} a path" do
          with_digest_algorithms do
            before :each do
              Puppet.settings.stubs(:use)
              @store = Puppet::FileBucketFile::File.new

              @bucket_top_dir = tmpdir("bucket")

              if override_bucket_path
                Puppet[:bucketdir] = "/bogus/path" # should not be used
              else
                Puppet[:bucketdir] = @bucket_top_dir
              end

              @dir = "#{@bucket_top_dir}/#{bucket_dir}"
              @contents_path = "#{@dir}/contents"
            end

            describe "when retrieving files" do
              before :each do

                request_options = {}
                if override_bucket_path
                  request_options[:bucket_path] = @bucket_top_dir
                end

                key = "#{digest_algorithm}/#{checksum}"
                if supply_path
                  key += "/path/to/file"
                end

                @request = Puppet::Indirector::Request.new(:indirection_name, :find, key, nil, request_options)
              end

              def make_bucketed_file
                FileUtils.mkdir_p(@dir)
                File.open(@contents_path, 'wb') { |f| f.write plaintext }
              end

              it "should return an instance of Puppet::FileBucket::File created with the content if the file exists" do
                make_bucketed_file

                if supply_path
                  expect(@store.find(@request)).to eq(nil)
                  expect(@store.head(@request)).to eq(false) # because path didn't match
                else
                  bucketfile = @store.find(@request)
                  expect(bucketfile).to be_a(Puppet::FileBucket::File)
                  expect(bucketfile.contents).to eq(plaintext)
                  expect(@store.head(@request)).to eq(true)
                end
              end

              it "should return nil if no file is found" do
                expect(@store.find(@request)).to be_nil
                expect(@store.head(@request)).to eq(false)
              end
            end

            describe "when saving files" do
              it "should save the contents to the calculated path" do
                skip("Windows Long File Name support is incomplete PUP-8257, this doesn't fail reliably so it should be skipped.") if Puppet::Util::Platform.windows? && (['sha512', 'sha384'].include? digest_algorithm)
                options = {}
                if override_bucket_path
                  options[:bucket_path] = @bucket_top_dir
                end

                key = "#{digest_algorithm}/#{checksum}"
                if supply_path
                  key += "//path/to/file"
                end

                file_instance = Puppet::FileBucket::File.new(plaintext, options)
                request = Puppet::Indirector::Request.new(:indirection_name, :save, key, file_instance)

                @store.save(request)
                expect(Puppet::FileSystem.binread("#{@dir}/contents")).to eq(plaintext)
              end
            end
          end
        end
      end
    end
  end
end
