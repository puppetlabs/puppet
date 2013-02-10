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

  describe "when writing file contents back to disk" do
    before do
      # convert the fixture to text - we will use this
      # to build our test criteria
      input = YAML.load(File.read(my_fixture('simple_header.yaml')))
      lines = input.collect { |r| r[:line] }
      @text = lines.join("\n")

      # uh oh - cargo cultist ahoy
      # I took this from an above example in good faith
      @class.stubs(:retrieve).returns [ ]
      @class.default_target = "/my/file"
      @class.initvars
      @class.prefetch

      @class.text_line :content, :match => %r{^\s*[^#]}
      @class.text_line :comment, :match => %r{^\s*#}

      # this is how the fixture is actually used (I'm proud ;-)
      @class.stubs(:target_records).with("/my/file").returns input

      # this is also lent from an existing example
      # it's needed for catching the provider's output
      @filetype = Puppet::Util::FileType.filetype(:flat).new("/my/file")
      Puppet::Util::FileType.filetype(:flat).stubs(:new).with("/my/file").returns @filetype
      @filetype.stubs(:write)
    end

    it "should not change anything apart from adding a header" do
      # this might be error prone on slow systems i fear - should probably
      # stub the header method too
      # note: the expecation even works - when not supplying the fixture,
      # one can expect "header + \n" successfully
      @filetype.expects(:write).with(@class.header + @text + "\n")
      @class.flush_target("/my/file")
    end

    it "should move an intermittent vendor header to the top" do
      true # NYI - gotta make step 1 work first
    end

    # TBI: it should drop a vendor header if so configured
  end
end

describe "A very basic provider based on ParsedFile", :focus => true do
  before :all do
    @example_crontab = File.read(my_fixture('vixie_crontab.txt'))
    @sorted_crontab = File.read(my_fixture('vixie_crontab_sorted.txt'))
    @output = Puppet::Util::FileType.filetype(:flat).new(target)
  end

  def target
    File.expand_path("/path/to/my/vixie/crontab")
  end

  def stub_target_file_type
    Puppet::Util::FileType.filetype(:flat).
      stubs(:new).with(target).returns(@output)
    @output.stubs(:read).returns(@example_crontab)
  end

  subject do
    stub_target_file_type
    example_provider_class = Class.new(Puppet::Provider::ParsedFile)
    example_provider_class.default_target = target
    # Setup some record rules
    example_provider_class.instance_eval do
      text_line :text, :match => %r{.}
    end
    example_provider_class.initvars
    example_provider_class.prefetch
    # evade a race between multiple invocations of the header method
    example_provider_class.stubs(:header).returns("# HEADER As added by puppet.\n")
    example_provider_class
  end

  context "writing file contents to disk" do
    it "should not change anything except from adding a header" do
      @output.expects(:write).with(subject.header + @example_crontab)
      subject.flush_target(target)
    end
  end

  context "rewriting a file containing a native header" do
    it "should move the native header to the top" do
      regex = /^# HEADER.*third party\.\n/
      subject.stubs(:native_header_regex).returns(regex)
      @output.expects(:write).with(@sorted_crontab)
      subject.flush_target(target)
    end
  end
end
