#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/provider/parsedfile'

# Most of the tests for this are still in test/ral/provider/parsedfile.rb.
describe Puppet::Provider::ParsedFile do

  # The ParsedFile provider class is meant to be used as an abstract base class
  # but also stores a lot of state within the singleton class. To avoid
  # sharing data between classes we construct an anonymous class that inherits
  # the ParsedFile provider instead of directly working with the ParsedFile
  # provider itself.
  subject { Puppet::Type.newtype(:parsedfile_type).provide(:parsedfile_provider, :parent => described_class) }

  describe "when looking up records loaded from disk" do
    it "should return nil if no records have been loaded" do
      subject.record?("foo").should be_nil
    end
  end

  describe "when generating a list of instances" do
    it "should return an instance for each record parsed from all of the registered targets" do
      subject.expects(:targets).returns %w{/one /two}
      subject.stubs(:skip_record?).returns false
      one = [:uno1, :uno2]
      two = [:dos1, :dos2]
      subject.expects(:prefetch_target).with("/one").returns one
      subject.expects(:prefetch_target).with("/two").returns two

      results = []
      (one + two).each do |inst|
        results << inst.to_s + "_instance"
        subject.expects(:new).with(inst).returns(results[-1])
      end

      subject.instances.should == results
    end

    it "should ignore target when retrieve fails" do
      subject.expects(:targets).returns %w{/one /two /three}
      subject.stubs(:skip_record?).returns false
      subject.expects(:retrieve).with("/one").returns [
        {:name => 'target1_record1'},
        {:name => 'target1_record2'}
      ]
      subject.expects(:retrieve).with("/two").raises Puppet::Util::FileType::FileReadError, "some error"
      subject.expects(:retrieve).with("/three").returns [
        {:name => 'target3_record1'},
        {:name => 'target3_record2'}
      ]
      Puppet.expects(:err).with('Could not prefetch parsedfile_type provider \'parsedfile_provider\' target \'/two\': some error. Treating as empty')
      subject.expects(:new).with(:name => 'target1_record1', :on_disk => true, :target => '/one', :ensure => :present).returns 'r1'
      subject.expects(:new).with(:name => 'target1_record2', :on_disk => true, :target => '/one', :ensure => :present).returns 'r2'
      subject.expects(:new).with(:name => 'target3_record1', :on_disk => true, :target => '/three', :ensure => :present).returns 'r3'
      subject.expects(:new).with(:name => 'target3_record2', :on_disk => true, :target => '/three', :ensure => :present).returns 'r4'

      subject.instances.should == %w{r1 r2 r3 r4}
    end

    it "should skip specified records" do
      subject.expects(:targets).returns %w{/one}
      subject.expects(:skip_record?).with(:uno).returns false
      subject.expects(:skip_record?).with(:dos).returns true
      one = [:uno, :dos]
      subject.expects(:prefetch_target).returns one

      subject.expects(:new).with(:uno).returns "eh"
      subject.expects(:new).with(:dos).never

      subject.instances
    end
  end

  describe "when matching resources to existing records" do
    let(:first_resource) { stub(:one, :name => :one) }
    let(:second_resource) { stub(:two, :name => :two) }

    let(:resources) {{:one => first_resource, :two => second_resource}}

    it "returns a resource if the record name matches the resource name" do
      record = {:name => :one}
      subject.resource_for_record(record, resources).should be first_resource
    end

    it "doesn't return a resource if the record name doesn't match any resource names" do
      record = {:name => :three}
      subject.resource_for_record(record, resources).should be_nil
    end
  end

  describe "when flushing a file's records to disk" do
    before do
      # This way we start with some @records, like we would in real life.
      subject.stubs(:retrieve).returns []
      subject.default_target = "/foo/bar"
      subject.initvars
      subject.prefetch

      @filetype = Puppet::Util::FileType.filetype(:flat).new("/my/file")
      Puppet::Util::FileType.filetype(:flat).stubs(:new).with("/my/file").returns @filetype

      @filetype.stubs(:write)
    end

    it "should back up the file being written if the filetype can be backed up" do
      @filetype.expects(:backup)

      subject.flush_target("/my/file")
    end

    it "should not try to back up the file if the filetype cannot be backed up" do
      @filetype = Puppet::Util::FileType.filetype(:ram).new("/my/file")
      Puppet::Util::FileType.filetype(:flat).expects(:new).returns @filetype

      @filetype.stubs(:write)

      subject.flush_target("/my/file")
    end

    it "should not back up the file more than once between calls to 'prefetch'" do
      @filetype.expects(:backup).once

      subject.flush_target("/my/file")
      subject.flush_target("/my/file")
    end

    it "should back the file up again once the file has been reread" do
      @filetype.expects(:backup).times(2)

      subject.flush_target("/my/file")
      subject.prefetch
      subject.flush_target("/my/file")
    end
  end
end

describe "A very basic provider based on ParsedFile" do

  let(:input_text) { File.read(my_fixture('simple.txt')) }
  let(:target) { File.expand_path("/tmp/test") }

  subject do
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
      input_records = subject.parse(input_text)
      subject.to_file(input_records).
        should match subject.header + input_text
    end
  end

  context "rewriting a file containing a native header" do
    let(:regex) { %r/^# HEADER.*third party\.\n/ }
    let(:input_records) { subject.parse(input_text) }

    before :each do
      subject.stubs(:native_header_regex).returns(regex)
    end

    it "should move the native header to the top" do
      subject.to_file(input_records).should_not match /\A#{subject.header}/
    end

    context "and dropping native headers found in input" do
      before :each do
        subject.stubs(:drop_native_header).returns(true)
      end

      it "should not include the native header in the output" do
        subject.to_file(input_records).should_not match regex
      end
    end
  end
end
