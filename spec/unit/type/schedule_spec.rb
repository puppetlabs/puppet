#!/usr/bin/env rspec
require 'spec_helper'

module ScheduleTesting

  def diff(unit, incr, method, count)
    diff = Time.now.to_i.send(method, incr * count)
    Time.at(diff)
  end

  def day(method, count)
    diff(:hour, 3600 * 24, method, count)
  end

  def hour(method, count)
    diff(:hour, 3600, method, count)
  end

  def min(method, count)
    diff(:min, 60, method, count)
  end

end

describe Puppet::Type.type(:schedule) do
  before :each do
    Puppet[:ignoreschedules] = false

    @schedule = Puppet::Type.type(:schedule).new(:name => "testing")
  end

  describe Puppet::Type.type(:schedule) do
    include ScheduleTesting

    it "should apply to device" do
      @schedule.should be_appliable_to_device
    end

    it "should apply to host" do
      @schedule.should be_appliable_to_host
    end

    it "should default to :distance for period-matching" do
      @schedule[:periodmatch].should == :distance
    end

    it "should default to a :repeat of 1" do
      @schedule[:repeat].should == 1
    end

    it "should never match when the period is :never" do
      @schedule[:period] = :never
      @schedule.should_not be_match
    end
  end

  describe Puppet::Type.type(:schedule), "when producing default schedules" do
    include ScheduleTesting

    %w{hourly daily weekly monthly never}.each do |period|
      period = period.to_sym
      it "should produce a #{period} schedule with the period set appropriately" do
        schedules = Puppet::Type.type(:schedule).mkdefaultschedules
        schedules.find { |s| s[:name] == period.to_s and s[:period] == period }.should be_instance_of(Puppet::Type.type(:schedule))
      end
    end

    it "should produce a schedule named puppet with a period of hourly and a repeat of 2" do
      schedules = Puppet::Type.type(:schedule).mkdefaultschedules
      schedules.find { |s|
        s[:name] == "puppet" and s[:period] == :hourly and s[:repeat] == 2
      }.should be_instance_of(Puppet::Type.type(:schedule))
    end
  end

  describe Puppet::Type.type(:schedule), "when matching ranges" do
    include ScheduleTesting

    before do
      Time.stubs(:now).returns(Time.local(2011, "may", 23, 11, 0, 0))
    end

    it "should match when the start time is before the current time and the end time is after the current time" do
      @schedule[:range] = "10:59:50 - 11:00:10"
      @schedule.must be_match
    end

    it "should not match when the start time is after the current time" do
      @schedule[:range] = "11:00:05 - 11:00:10"
      @schedule.must_not be_match
    end

    it "should not match when the end time is previous to the current time" do
      @schedule[:range] = "10:59:50 - 10:59:55"
      @schedule.must_not be_match
    end

    it "should throw an error if the upper limit is less than the lower limit" do
      pending "bug #7639"
      @schedule[:range] = "01:02:03 - 01:00:00"
      @schedule.should_throw Puppet::Error
    end

    it "should not match the current time fails between an array of ranges" do
      @schedule[:range] = ["4-6", "20-23"]
      @schedule.must_not be_match
    end

    it "should match the lower array of ranges" do
      @schedule[:range] = ["9-11", "14-16"]
      @schedule.must be_match
    end

    it "should match the upper array of ranges" do
      @schedule[:range] = ["4-6", "11-12"]
      @schedule.must be_match
    end
  end

  describe Puppet::Type.type(:schedule), "when matching hourly by distance", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :hourly
      @schedule[:periodmatch] = :distance

      Time.stubs(:now).returns(Time.local(2011, "may", 23, 11, 0, 0))
    end

    it "should match when the previous time was an hour ago" do
      @schedule.should be_match(hour("-", 1))
    end

    it "should not match when the previous time was now" do
      @schedule.should_not be_match(Time.now)
    end

    it "should not match when the previous time was 59 minutes ago" do
      @schedule.should_not be_match(min("-", 59))
    end
  end

  describe Puppet::Type.type(:schedule), "when matching daily by distance", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :daily
      @schedule[:periodmatch] = :distance

      Time.stubs(:now).returns(Time.local(2011, "may", 23, 11, 0, 0))
    end

    it "should match when the previous time was one day ago" do
      @schedule.should be_match(day("-", 1))
    end

    it "should not match when the previous time is now" do
      @schedule.should_not be_match(Time.now)
    end

    it "should not match when the previous time was 23 hours ago" do
      @schedule.should_not be_match(hour("-", 23))
    end
  end

  describe Puppet::Type.type(:schedule), "when matching weekly by distance", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :weekly
      @schedule[:periodmatch] = :distance

      Time.stubs(:now).returns(Time.local(2011, "may", 23, 11, 0, 0))
    end

    it "should match when the previous time was seven days ago" do
      @schedule.should be_match(day("-", 7))
    end

    it "should not match when the previous time was now" do
      @schedule.should be_match(Time.now)
    end

    it "should not match when the previous time was six days ago" do
      @schedule.should_not be_match(day("-", 6))
    end
  end

  describe Puppet::Type.type(:schedule), "when matching monthly by distance", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :monthly
      @schedule[:periodmatch] = :distance

      Time.stubs(:now).returns(Time.local(2011, "may", 23, 11, 0, 0))
    end

    it "should match when the previous time was 32 days ago" do
      @schedule.should be_match(day("-", 32))
    end

    it "should not match when the previous time was now" do
      @schedule.should_not be_match(Time.now)
    end

    it "should not match when the previous time was 27 days ago" do
      @schedule.should_not be_match(day("-", 27))
    end
  end

  describe Puppet::Type.type(:schedule), "when matching hourly by number", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :hourly
      @schedule[:periodmatch] = :number
    end

    it "should match if the times are one minute apart and the current minute is 0" do
      current = Time.utc(2008, 1, 1, 0, 0, 0)
      previous = Time.utc(2007, 12, 31, 23, 59, 0)

      Time.stubs(:now).returns(current)
      @schedule.should be_match(previous)
    end

    it "should not match if the times are 59 minutes apart and the current minute is 59" do
      current = Time.utc(2009, 2, 1, 12, 59, 0)
      previous = Time.utc(2009, 2, 1, 12, 0, 0)

      Time.stubs(:now).returns(current)
      @schedule.should_not be_match(previous)
    end
  end

  describe Puppet::Type.type(:schedule), "when matching daily by number", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :daily
      @schedule[:periodmatch] = :number
    end

    it "should match if the times are one minute apart and the current minute and hour are 0" do
      current = Time.utc(2010, "nov", 7, 0, 0, 0)

      # Now set the previous time to one minute before that
      previous = current - 60

      Time.stubs(:now).returns(current)
      @schedule.should be_match(previous)
    end

    it "should not match if the times are 23 hours and 58 minutes apart and the current hour is 23 and the current minute is 59" do

      # Reset the previous time to 00:00:00
      previous = Time.utc(2010, "nov", 7, 0, 0, 0)

      # Set the current time to 23:59
      now = previous + (23 * 3600) + (59 * 60)

      Time.stubs(:now).returns(now)
      @schedule.should_not be_match(previous)
    end
  end

  describe Puppet::Type.type(:schedule), "when matching weekly by number", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :weekly
      @schedule[:periodmatch] = :number
    end

    it "should match if the previous time is prior to the most recent Sunday" do
      now = Time.utc(2010, "nov", 11, 0, 0, 0) # Thursday
      Time.stubs(:now).returns(now)
      previous = Time.utc(2010, "nov", 6, 23, 59, 59) # Sat

      @schedule.should be_match(previous)
    end

    it "should not match if the previous time is after the most recent Saturday" do
      now = Time.utc(2010, "nov", 11, 0, 0, 0) # Thursday
      Time.stubs(:now).returns(now)
      previous = Time.utc(2010, "nov", 7, 0, 0, 0) # Sunday

      @schedule.should_not be_match(previous)
    end
  end

  describe Puppet::Type.type(:schedule), "when matching monthly by number", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :monthly
      @schedule[:periodmatch] = :number
    end

    it "should match when the previous time is prior to the first day of this month" do
      now = Time.utc(2010, "nov", 8, 00, 59, 59)
      Time.stubs(:now).returns(now)
      previous = Time.utc(2010, "oct", 31, 23, 59, 59)

      @schedule.should be_match(previous)
    end

    it "should not match when the previous time is after the last day of last month" do
      now = Time.utc(2010, "nov", 8, 00, 59, 59)
      Time.stubs(:now).returns(now)
      previous = Time.utc(2010, "nov", 1, 0, 0, 0)

      @schedule.should_not be_match(previous)
    end
  end

  describe Puppet::Type.type(:schedule), "when matching with a repeat greater than one", :'fails_on_ruby_1.9.2' => true do
    include ScheduleTesting

    before do
      @schedule[:period] = :daily
      @schedule[:repeat] = 2

      Time.stubs(:now).returns(Time.local(2011, "may", 23, 11, 0, 0))
    end

    it "should fail if the periodmatch is 'number'" do
      @schedule[:periodmatch] = :number
      proc { @schedule[:repeat] = 2 }.should raise_error(Puppet::Error)
    end

    it "should match if the previous run was further away than the distance divided by the repeat" do
      previous = Time.now - (3600 * 13)
      @schedule.should be_match(previous)
    end

    it "should not match if the previous run was closer than the distance divided by the repeat" do
      previous = Time.now - (3600 * 11)
      @schedule.should_not be_match(previous)
    end
  end
end
