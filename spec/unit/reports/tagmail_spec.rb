#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/reports'

tagmail = Puppet::Reports.report(:tagmail)

describe tagmail do
  before do
    @processor = Puppet::Transaction::Report.new("apply")
    @processor.extend(Puppet::Reports.report(:tagmail))
  end

  passers = my_fixture "tagmail_passers.conf"
  File.readlines(passers).each do |line|
    it "should be able to parse '#{line.inspect}'" do
      @processor.parse(line)
    end
  end

  failers = my_fixture "tagmail_failers.conf"
  File.readlines(failers).each do |line|
    it "should not be able to parse '#{line.inspect}'" do
      lambda { @processor.parse(line) }.should raise_error(ArgumentError)
    end
  end

  {
    "tag: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag}, []],
    "tag.localhost: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag.localhost}, []],
    "tag, other: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag other}, []],
    "tag-other: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag-other}, []],
    "tag, !other: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag}, %w{other}],
    "tag, !other, one, !two: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag one}, %w{other two}],
    "tag: abuse@domain.com, other@domain.com" => [%w{abuse@domain.com other@domain.com}, %w{tag}, []]

  }.each do |line, results|
    it "should parse '#{line}' as #{results.inspect}" do
      @processor.parse(line).shift.should == results
    end
  end

  describe "when matching logs" do
    before do
      @processor << Puppet::Util::Log.new(:level => :notice, :message => "first", :tags => %w{one})
      @processor << Puppet::Util::Log.new(:level => :notice, :message => "second", :tags => %w{one two})
      @processor << Puppet::Util::Log.new(:level => :notice, :message => "third", :tags => %w{one two three})
    end

    def match(pos = [], neg = [])
      pos = Array(pos)
      neg = Array(neg)
      result = @processor.match([[%w{abuse@domain.com}, pos, neg]])
      actual_result = result.shift
      if actual_result
        actual_result[1]
      else
        nil
      end
    end

    it "should match all messages when provided the 'all' tag as a positive matcher" do
      results = match("all")
      %w{first second third}.each do |str|
        results.should be_include(str)
      end
    end

    it "should remove messages that match a negated tag" do
      match("all", "three").should_not be_include("third")
    end

    it "should find any messages tagged with a provided tag" do
      results = match("two")
      results.should be_include("second")
      results.should be_include("third")
      results.should_not be_include("first")
    end

    it "should allow negation of specific tags from a specific tag list" do
      results = match("two", "three")
      results.should be_include("second")
      results.should_not be_include("third")
    end

    it "should allow a tag to negate all matches" do
      results = match([], "one")
      results.should be_nil
    end
  end
end
