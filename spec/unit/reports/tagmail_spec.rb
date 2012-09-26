#! /usr/bin/env ruby
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

  describe "the behavior of tagmail.process" do
    before do
      Puppet[:tagmap] = my_fixture "tagmail_email.conf"
    end

    let(:processor) do
      processor = Puppet::Transaction::Report.new("apply")
      processor.extend(Puppet::Reports.report(:tagmail))
      processor
    end

    context "when any messages match a positive tag" do
      before do
        processor << log_entry
      end

      let(:log_entry) do
        Puppet::Util::Log.new(
          :level => :notice, :message => "Secure change", :tags => %w{secure})
      end

      let(:message) do
        "#{log_entry.time} Puppet (notice): Secure change"
      end

      it "should send email if there are changes" do
        processor.expects(:send).with([[['user@domain.com'], message]])
        processor.expects(:raw_summary).returns({
          "resources" => { "changed" => 1, "out_of_sync" => 0 }
        })

        processor.process
      end

      it "should send email if there are resources out of sync" do
        processor.expects(:send).with([[['user@domain.com'], message]])
        processor.expects(:raw_summary).returns({
          "resources" => { "changed" => 0, "out_of_sync" => 1 }
        })

        processor.process
      end

      it "should not send email if no changes or resources out of sync" do
        processor.expects(:send).never
        processor.expects(:raw_summary).returns({
          "resources" => { "changed" => 0, "out_of_sync" => 0 }
        })

        processor.process
      end

      it "should log a message if no changes or resources out of sync" do
        processor.expects(:send).never
        processor.expects(:raw_summary).returns({
          "resources" => { "changed" => 0, "out_of_sync" => 0 }
        })

        Puppet.expects(:notice).with("Not sending tagmail report; no changes")
        processor.process
      end

      it "should send email if raw_summary is not defined" do
        processor.expects(:send).with([[['user@domain.com'], message]])
        processor.expects(:raw_summary).returns(nil)
        processor.process
      end

      it "should send email if there are no resource metrics" do
        processor.expects(:send).with([[['user@domain.com'], message]])
        processor.expects(:raw_summary).returns({'resources' => nil})
        processor.process
      end
    end

    context "when no message match a positive tag" do
      before do
        processor << log_entry
      end

      let(:log_entry) do
        Puppet::Util::Log.new(
          :level   => :notice,
          :message => 'Unnotices change',
          :tags    => %w{not_present_in_tagmail.conf}
        )
      end

      it "should send no email if there are changes" do
        processor.expects(:send).never
        processor.expects(:raw_summary).returns({
          "resources" => { "changed" => 1, "out_of_sync" => 0 }
        })
        processor.process
      end

      it "should send no email if there are resources out of sync" do
        processor.expects(:send).never
        processor.expects(:raw_summary).returns({
          "resources" => { "changed" => 0, "out_of_sync" => 1 }
        })
        processor.process
      end

      it "should send no email if no changes or resources out of sync" do
        processor.expects(:send).never
        processor.expects(:raw_summary).returns({
          "resources" => { "changed" => 0, "out_of_sync" => 0 }
        })
        processor.process
      end

      it "should send no email if raw_summary is not defined" do
        processor.expects(:send).never
        processor.expects(:raw_summary).returns(nil)
        processor.process
      end

      it "should send no email if there are no resource metrics" do
        processor.expects(:send).never
        processor.expects(:raw_summary).returns({'resources' => nil})
        processor.process
      end
    end
  end
end

