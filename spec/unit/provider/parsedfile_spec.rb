#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'

require 'puppet'
require 'puppet/provider/parsedfile'

Puppet::Type.newtype(:parsedfile_type) do
  newparam(:name)
  newproperty(:target)
end

# Most of the tests for this are still in test/ral/provider/parsedfile.rb.
describe Puppet::Provider::ParsedFile do
  # The ParsedFile provider class is meant to be used as an abstract base class
  # but also stores a lot of state within the singleton class. To avoid
  # sharing data between classes we construct an anonymous class that inherits
  # the ParsedFile provider instead of directly working with the ParsedFile
  # provider itself.
  let(:parsed_type) do
    Puppet::Type.type(:parsedfile_type)
  end

  let!(:provider) { parsed_type.provide(:parsedfile_provider, :parent => described_class) }

  describe "when looking up records loaded from disk" do
    it "should return nil if no records have been loaded" do
      expect(provider.record?("foo")).to be_nil
    end
  end

  describe "when generating a list of instances" do
    it "should return an instance for each record parsed from all of the registered targets" do
      provider.expects(:targets).returns %w{/one /two}
      provider.stubs(:skip_record?).returns false
      one = [:uno1, :uno2]
      two = [:dos1, :dos2]
      provider.expects(:prefetch_target).with("/one").returns one
      provider.expects(:prefetch_target).with("/two").returns two

      results = []
      (one + two).each do |inst|
        results << inst.to_s + "_instance"
        provider.expects(:new).with(inst).returns(results[-1])
      end

      expect(provider.instances).to eq(results)
    end

    it "should ignore target when retrieve fails" do
      provider.expects(:targets).returns %w{/one /two /three}
      provider.stubs(:skip_record?).returns false
      provider.expects(:retrieve).with("/one").returns [
        {:name => 'target1_record1'},
        {:name => 'target1_record2'}
      ]
      provider.expects(:retrieve).with("/two").raises Puppet::Util::FileType::FileReadError, "some error"
      provider.expects(:retrieve).with("/three").returns [
        {:name => 'target3_record1'},
        {:name => 'target3_record2'}
      ]
      Puppet.expects(:err).with('Could not prefetch parsedfile_type provider \'parsedfile_provider\' target \'/two\': some error. Treating as empty')
      provider.expects(:new).with(:name => 'target1_record1', :on_disk => true, :target => '/one', :ensure => :present).returns 'r1'
      provider.expects(:new).with(:name => 'target1_record2', :on_disk => true, :target => '/one', :ensure => :present).returns 'r2'
      provider.expects(:new).with(:name => 'target3_record1', :on_disk => true, :target => '/three', :ensure => :present).returns 'r3'
      provider.expects(:new).with(:name => 'target3_record2', :on_disk => true, :target => '/three', :ensure => :present).returns 'r4'

      expect(provider.instances).to eq(%w{r1 r2 r3 r4})
    end

    it "should skip specified records" do
      provider.expects(:targets).returns %w{/one}
      provider.expects(:skip_record?).with(:uno).returns false
      provider.expects(:skip_record?).with(:dos).returns true
      one = [:uno, :dos]
      provider.expects(:prefetch_target).returns one

      provider.expects(:new).with(:uno).returns "eh"
      provider.expects(:new).with(:dos).never

      provider.instances
    end
  end

  describe "when matching resources to existing records" do
    let(:first_resource) { stub(:one, :name => :one) }
    let(:second_resource) { stub(:two, :name => :two) }

    let(:resources) {{:one => first_resource, :two => second_resource}}

    it "returns a resource if the record name matches the resource name" do
      record = {:name => :one}
      expect(provider.resource_for_record(record, resources)).to be first_resource
    end

    it "doesn't return a resource if the record name doesn't match any resource names" do
      record = {:name => :three}
      expect(provider.resource_for_record(record, resources)).to be_nil
    end
  end

  describe "when flushing a file's records to disk" do
    before do
      # This way we start with some @records, like we would in real life.
      provider.stubs(:retrieve).returns []
      provider.default_target = "/foo/bar"
      provider.initvars
      provider.prefetch

      @filetype = Puppet::Util::FileType.filetype(:flat).new("/my/file")
      Puppet::Util::FileType.filetype(:flat).stubs(:new).with("/my/file",nil).returns @filetype

      @filetype.stubs(:write)
    end

    it "should back up the file being written if the filetype can be backed up" do
      @filetype.expects(:backup)

      provider.flush_target("/my/file")
    end

    it "should not try to back up the file if the filetype cannot be backed up" do
      @filetype = Puppet::Util::FileType.filetype(:ram).new("/my/file")
      Puppet::Util::FileType.filetype(:flat).expects(:new).returns @filetype

      @filetype.stubs(:write)

      provider.flush_target("/my/file")
    end

    it "should not back up the file more than once between calls to 'prefetch'" do
      @filetype.expects(:backup).once

      provider.flush_target("/my/file")
      provider.flush_target("/my/file")
    end

    it "should back the file up again once the file has been reread" do
      @filetype.expects(:backup).times(2)

      provider.flush_target("/my/file")
      provider.prefetch
      provider.flush_target("/my/file")
    end
  end

  describe "when flushing multiple files" do
    describe "and an error is encountered" do
      it "the other file does not fail" do
        provider.stubs(:backup_target)

        bad_file = 'broken'
        good_file = 'writable'

        bad_writer = mock 'bad'
        bad_writer.expects(:write).raises(Exception, "Failed to write to bad file")

        good_writer = mock 'good'
        good_writer.expects(:write).returns(nil)

        provider.stubs(:target_object).with(bad_file).returns(bad_writer)
        provider.stubs(:target_object).with(good_file).returns(good_writer)

        bad_resource = parsed_type.new(:name => 'one', :target => bad_file)
        good_resource = parsed_type.new(:name => 'two', :target => good_file)

        expect {
          bad_resource.flush
        }.to raise_error(Exception, "Failed to write to bad file")

        good_resource.flush
      end
    end
  end
end

describe "A very basic provider based on ParsedFile" do
  include PuppetSpec::Files

  let(:input_text) { File.read(my_fixture('simple.txt')) }
  let(:target) { tmpfile('parsedfile_spec') }

  let(:provider) do
    example_provider_class = Class.new(Puppet::Provider::ParsedFile)
    example_provider_class.default_target = target
    # Setup some record rules
    example_provider_class.instance_eval do
      text_line :text, :match => %r{.}
    end
    example_provider_class.initvars
    example_provider_class.prefetch
    # evade a race between multiple invocations of the header method
    example_provider_class.stubs(:header).
      returns("# HEADER As added by puppet.\n")
    example_provider_class
  end

  context "writing file contents back to disk" do
    it "should not change anything except from adding a header" do
      input_records = provider.parse(input_text)
      expect(provider.to_file(input_records)).
        to match provider.header + input_text
    end
  end

  context "rewriting a file containing a native header" do
    let(:regex) { %r/^# HEADER.*third party\.\n/ }
    let(:input_records) { provider.parse(input_text) }

    before :each do
      provider.stubs(:native_header_regex).returns(regex)
    end

    it "should move the native header to the top" do
      expect(provider.to_file(input_records)).not_to match /\A#{provider.header}/
    end

    context "and dropping native headers found in input" do
      before :each do
        provider.stubs(:drop_native_header).returns(true)
      end

      it "should not include the native header in the output" do
        expect(provider.to_file(input_records)).not_to match regex
      end
    end
  end
end
