#!/usr/bin/env rspec
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
