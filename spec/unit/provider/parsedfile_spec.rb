#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/provider/parsedfile'

# Most of the tests for this are still in test/ral/provider/parsedfile.rb.
describe Puppet::Provider::ParsedFile do
  before do
    @class = Class.new(Puppet::Provider::ParsedFile)
  end

  describe "when looking up records loaded from disk" do
    it "should return nil if no records have been loaded" do
      @class.record?("foo").should be_nil
    end
  end

  describe "when generating a list of instances" do
    it "should return an instance for each record parsed from all of the registered targets" do
      @class.expects(:targets).returns %w{/one /two}
      @class.stubs(:skip_record?).returns false
      one = [:uno1, :uno2]
      two = [:dos1, :dos2]
      @class.expects(:prefetch_target).with("/one").returns one
      @class.expects(:prefetch_target).with("/two").returns two

      results = []
      (one + two).each do |inst|
        results << inst.to_s + "_instance"
        @class.expects(:new).with(inst).returns(results[-1])
      end

      @class.instances.should == results
    end

    it "should skip specified records" do
      @class.expects(:targets).returns %w{/one}
      @class.expects(:skip_record?).with(:uno).returns false
      @class.expects(:skip_record?).with(:dos).returns true
      one = [:uno, :dos]
      @class.expects(:prefetch_target).returns one

      @class.expects(:new).with(:uno).returns "eh"
      @class.expects(:new).with(:dos).never

      @class.instances
    end
  end

  describe "when flushing a file's records to disk" do
    before do
      # This way we start with some @records, like we would in real life.
      @class.stubs(:retrieve).returns []
      @class.default_target = "/foo/bar"
      @class.initvars
      @class.prefetch

      @filetype = Puppet::Util::FileType.filetype(:flat).new("/my/file")
      Puppet::Util::FileType.filetype(:flat).stubs(:new).with("/my/file").returns @filetype

      @filetype.stubs(:write)
    end

    it "should back up the file being written if the filetype can be backed up" do
      @filetype.expects(:backup)

      @class.flush_target("/my/file")
    end

    it "should not try to back up the file if the filetype cannot be backed up" do
      @filetype = Puppet::Util::FileType.filetype(:ram).new("/my/file")
      Puppet::Util::FileType.filetype(:flat).expects(:new).returns @filetype

      @filetype.stubs(:write)

      @class.flush_target("/my/file")
    end

    it "should not back up the file more than once between calls to 'prefetch'" do
      @filetype.expects(:backup).once

      @class.flush_target("/my/file")
      @class.flush_target("/my/file")
    end

    it "should back the file up again once the file has been reread" do
      @filetype.expects(:backup).times(2)

      @class.flush_target("/my/file")
      @class.prefetch
      @class.flush_target("/my/file")
    end
  end
end

describe "A very basic provider based on ParsedFile" do
  before :all do
    @input_text = File.read(my_fixture('simple.txt'))
  end

  def target
    File.expand_path("/tmp/test")
  end

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
      input_records = subject.parse(@input_text)
      subject.to_file(input_records).
        should match subject.header + @input_text
    end
  end

  context "rewriting a file containing a native header" do
    regex = /^# HEADER.*third party\.\n/
    it "should move the native header to the top" do
      input_records = subject.parse(@input_text)
      subject.stubs(:native_header_regex).returns(regex)
      subject.to_file(input_records).should_not match /\A#{subject.header}/
    end

    context "and dropping native headers found in input" do
      it "should not include the native header in the output" do
        input_records = subject.parse(@input_text)
        subject.stubs(:native_header_regex).returns(regex)
        subject.stubs(:drop_native_header).returns(true)
        subject.to_file(input_records).should_not match regex
      end
    end
  end
end
