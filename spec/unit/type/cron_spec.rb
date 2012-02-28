#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Type.type(:cron), :unless => Puppet.features.microsoft_windows? do
  before do
    @provider_class = described_class.provide(:simple) { mk_resource_methods }
    @provider_class.stubs(:suitable?).returns true
    described_class.stubs(:defaultprovider).returns @provider_class
  end

  it "should have :name be its namevar" do
    described_class.key_attributes.should == [:name]
  end

  describe "when validating attributes" do
    [:name, :provider].each do |param|
      it "should have a #{param} parameter" do
        described_class.attrtype(param).should == :param
      end
    end

    [:command, :special, :minute, :hour, :weekday, :month, :monthday, :environment, :user, :target].each do |property|
      it "should have a #{property} property" do
        described_class.attrtype(property).should == :property
      end
    end

    [:command, :minute, :hour, :weekday, :month, :monthday].each do |cronparam|
      it "should have #{cronparam} of type CronParam" do
        described_class.attrclass(cronparam).ancestors.should include CronParam
      end
    end
  end


  describe "when validating attribute" do
    describe "ensure" do
      it "should support present as a value for ensure" do
        proc { described_class.new(:name => 'foo', :ensure => :present) }.should_not raise_error
      end

      it "should support absent as a value for ensure" do
        proc { described_class.new(:name => 'foo', :ensure => :present) }.should_not raise_error
      end

      it "should not support other values" do
        proc { described_class.new(:name => 'foo', :ensure => :foo) }.should raise_error(Puppet::Error, /Invalid value/)
      end
    end

    describe "minute" do
      it "should support absent" do
        proc { described_class.new(:name => 'foo', :minute => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { described_class.new(:name => 'foo', :minute => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :minute => 'absent')[:minute].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :minute => '*')[:minute].should == :absent
      end

      it "should support valid single values" do
        proc { described_class.new(:name => 'foo', :minute => '0') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :minute => '1') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :minute => '59') }.should_not raise_error
      end

      it "should not support non numeric characters" do
        proc { described_class.new(:name => 'foo', :minute => 'z59') }.should raise_error(Puppet::Error, /z59 is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => '5z9') }.should raise_error(Puppet::Error, /5z9 is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => '59z') }.should raise_error(Puppet::Error, /59z is not a valid minute/)
      end

      it "should not support single values out of range" do

        proc { described_class.new(:name => 'foo', :minute => '-1') }.should raise_error(Puppet::Error, /-1 is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => '60') }.should raise_error(Puppet::Error, /60 is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => '61') }.should raise_error(Puppet::Error, /61 is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => '120') }.should raise_error(Puppet::Error, /120 is not a valid minute/)
      end

      it "should support valid multiple values" do
        proc { described_class.new(:name => 'foo', :minute => ['0','1','59'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :minute => ['40','30','20'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :minute => ['10','30','20'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { described_class.new(:name => 'foo', :minute => ['0','1','60'] ) }.should raise_error(Puppet::Error, /60 is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => ['0','120','59'] ) }.should raise_error(Puppet::Error, /120 is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => ['-1','1','59'] ) }.should raise_error(Puppet::Error, /-1 is not a valid minute/)
        # two invalid
        proc { described_class.new(:name => 'foo', :minute => ['0','61','62'] ) }.should raise_error(Puppet::Error, /(61|62) is not a valid minute/)
        # all invalid
        proc { described_class.new(:name => 'foo', :minute => ['-1','61','62'] ) }.should raise_error(Puppet::Error, /(-1|61|62) is not a valid minute/)
      end

      it "should support valid step syntax" do
        proc { described_class.new(:name => 'foo', :minute => '*/2' ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :minute => '10-16/2' ) }.should_not raise_error
      end

      it "should not support invalid steps" do
        proc { described_class.new(:name => 'foo', :minute => '*/A' ) }.should raise_error(Puppet::Error, /\*\/A is not a valid minute/)
        proc { described_class.new(:name => 'foo', :minute => '*/2A' ) }.should raise_error(Puppet::Error, /\*\/2A is not a valid minute/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # proc { described_class.new(:name => 'foo', :minute => '*/120' ) }.should raise_error(Puppet::Error, /is not a valid minute/)
      end
    end

    describe "hour" do
      it "should support absent" do
        proc { described_class.new(:name => 'foo', :hour => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { described_class.new(:name => 'foo', :hour => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :hour => 'absent')[:hour].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :hour => '*')[:hour].should == :absent
      end

      it "should support valid single values" do
        proc { described_class.new(:name => 'foo', :hour => '0') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :hour => '11') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :hour => '12') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :hour => '13') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :hour => '23') }.should_not raise_error
      end

      it "should not support non numeric characters" do
        proc { described_class.new(:name => 'foo', :hour => 'z15') }.should raise_error(Puppet::Error, /z15 is not a valid hour/)
        proc { described_class.new(:name => 'foo', :hour => '1z5') }.should raise_error(Puppet::Error, /1z5 is not a valid hour/)
        proc { described_class.new(:name => 'foo', :hour => '15z') }.should raise_error(Puppet::Error, /15z is not a valid hour/)
      end

      it "should not support single values out of range" do
        proc { described_class.new(:name => 'foo', :hour => '-1') }.should raise_error(Puppet::Error, /-1 is not a valid hour/)
        proc { described_class.new(:name => 'foo', :hour => '24') }.should raise_error(Puppet::Error, /24 is not a valid hour/)
        proc { described_class.new(:name => 'foo', :hour => '120') }.should raise_error(Puppet::Error, /120 is not a valid hour/)
      end

      it "should support valid multiple values" do
        proc { described_class.new(:name => 'foo', :hour => ['0','1','23'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :hour => ['5','16','14'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :hour => ['16','13','9'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { described_class.new(:name => 'foo', :hour => ['0','1','24'] ) }.should raise_error(Puppet::Error, /24 is not a valid hour/)
        proc { described_class.new(:name => 'foo', :hour => ['0','-1','5'] ) }.should raise_error(Puppet::Error, /-1 is not a valid hour/)
        proc { described_class.new(:name => 'foo', :hour => ['-1','1','23'] ) }.should raise_error(Puppet::Error, /-1 is not a valid hour/)
        # two invalid
        proc { described_class.new(:name => 'foo', :hour => ['0','25','26'] ) }.should raise_error(Puppet::Error, /(25|26) is not a valid hour/)
        # all invalid
        proc { described_class.new(:name => 'foo', :hour => ['-1','24','120'] ) }.should raise_error(Puppet::Error, /(-1|24|120) is not a valid hour/)
      end

      it "should support valid step syntax" do
        proc { described_class.new(:name => 'foo', :hour => '*/2' ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :hour => '10-18/4' ) }.should_not raise_error
      end

      it "should not support invalid steps" do
        proc { described_class.new(:name => 'foo', :hour => '*/A' ) }.should raise_error(Puppet::Error, /\*\/A is not a valid hour/)
        proc { described_class.new(:name => 'foo', :hour => '*/2A' ) }.should raise_error(Puppet::Error, /\*\/2A is not a valid hour/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # proc { described_class.new(:name => 'foo', :hour => '*/26' ) }.should raise_error(Puppet::Error, /is not a valid hour/)
      end
    end

    describe "weekday" do
      it "should support absent" do
        proc { described_class.new(:name => 'foo', :weekday => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { described_class.new(:name => 'foo', :weekday => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :weekday => 'absent')[:weekday].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :weekday => '*')[:weekday].should == :absent
      end

      it "should support valid numeric weekdays" do
        proc { described_class.new(:name => 'foo', :weekday => '0') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => '1') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => '6') }.should_not raise_error
        # According to http://www.manpagez.com/man/5/crontab 7 is also valid (Sunday)
        proc { described_class.new(:name => 'foo', :weekday => '7') }.should_not raise_error
      end

      it "should support valid weekdays as words (long version)" do
        proc { described_class.new(:name => 'foo', :weekday => 'Monday') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Tuesday') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Wednesday') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Thursday') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Friday') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Saturday') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Sunday') }.should_not raise_error
      end

      it "should support valid weekdays as words (3 character version)" do
        proc { described_class.new(:name => 'foo', :weekday => 'Mon') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Tue') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Wed') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Thu') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Fri') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Sat') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => 'Sun') }.should_not raise_error
      end

      it "should not support numeric values out of range" do
        proc { described_class.new(:name => 'foo', :weekday => '-1') }.should raise_error(Puppet::Error, /-1 is not a valid weekday/)
        proc { described_class.new(:name => 'foo', :weekday => '8') }.should raise_error(Puppet::Error, /8 is not a valid weekday/)
      end

      it "should not support invalid weekday names" do
        proc { described_class.new(:name => 'foo', :weekday => 'Sar') }.should raise_error(Puppet::Error, /Sar is not a valid weekday/)
      end

      it "should support valid multiple values" do
        proc { described_class.new(:name => 'foo', :weekday => ['0','1','6'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => ['Mon','Wed','Friday'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { described_class.new(:name => 'foo', :weekday => ['0','1','8'] ) }.should raise_error(Puppet::Error, /8 is not a valid weekday/)
        proc { described_class.new(:name => 'foo', :weekday => ['Mon','Fii','Sat'] ) }.should raise_error(Puppet::Error, /Fii is not a valid weekday/)
        # two invalid
        proc { described_class.new(:name => 'foo', :weekday => ['Mos','Fii','Sat'] ) }.should raise_error(Puppet::Error, /(Mos|Fii) is not a valid weekday/)
        # all invalid
        proc { described_class.new(:name => 'foo', :weekday => ['Mos','Fii','Saa'] ) }.should raise_error(Puppet::Error, /(Mos|Fii|Saa) is not a valid weekday/)
        proc { described_class.new(:name => 'foo', :weekday => ['-1','8','11'] ) }.should raise_error(Puppet::Error, /(-1|8|11) is not a valid weekday/)
      end

      it "should support valid step syntax" do
        proc { described_class.new(:name => 'foo', :weekday => '*/2' ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :weekday => '0-4/2' ) }.should_not raise_error
      end

      it "should not support invalid steps" do
        proc { described_class.new(:name => 'foo', :weekday => '*/A' ) }.should raise_error(Puppet::Error, /\*\/A is not a valid weekday/)
        proc { described_class.new(:name => 'foo', :weekday => '*/2A' ) }.should raise_error(Puppet::Error, /\*\/2A is not a valid weekday/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # proc { described_class.new(:name => 'foo', :weekday => '*/9' ) }.should raise_error(Puppet::Error, /is not a valid weekday/)
      end
    end

    describe "month" do
      it "should support absent" do
        proc { described_class.new(:name => 'foo', :month => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { described_class.new(:name => 'foo', :month => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :month => 'absent')[:month].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :month => '*')[:month].should == :absent
      end

      it "should support valid numeric values" do
        proc { described_class.new(:name => 'foo', :month => '1') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => '12') }.should_not raise_error
      end

      it "should support valid months as words" do
        proc { described_class.new(:name => 'foo', :month => 'January') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'February') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'March') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'April') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'May') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'June') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'July') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'August') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'September') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'October') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'November') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'December') }.should_not raise_error
      end

      it "should support valid months as words (3 character short version)" do
        proc { described_class.new(:name => 'foo', :month => 'Jan') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Feb') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Mar') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Apr') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'May') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Jun') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Jul') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Aug') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Sep') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Oct') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Nov') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => 'Dec') }.should_not raise_error
      end

      it "should not support numeric values out of range" do
        proc { described_class.new(:name => 'foo', :month => '-1') }.should raise_error(Puppet::Error, /-1 is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => '0') }.should raise_error(Puppet::Error, /0 is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => '13') }.should raise_error(Puppet::Error, /13 is not a valid month/)
      end

      it "should not support words that are not valid months" do
        proc { described_class.new(:name => 'foo', :month => 'Jal') }.should raise_error(Puppet::Error, /Jal is not a valid month/)
      end

      it "should not support single values out of range" do

        proc { described_class.new(:name => 'foo', :month => '-1') }.should raise_error(Puppet::Error, /-1 is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => '60') }.should raise_error(Puppet::Error, /60 is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => '61') }.should raise_error(Puppet::Error, /61 is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => '120') }.should raise_error(Puppet::Error, /120 is not a valid month/)
      end

      it "should support valid multiple values" do
        proc { described_class.new(:name => 'foo', :month => ['1','9','12'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => ['Jan','March','Jul'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { described_class.new(:name => 'foo', :month => ['0','1','12'] ) }.should raise_error(Puppet::Error, /0 is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => ['1','13','10'] ) }.should raise_error(Puppet::Error, /13 is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => ['Jan','Feb','Jxx'] ) }.should raise_error(Puppet::Error, /Jxx is not a valid month/)
        # two invalid
        proc { described_class.new(:name => 'foo', :month => ['Jan','Fex','Jux'] ) }.should raise_error(Puppet::Error, /(Fex|Jux) is not a valid month/)
        # all invalid
        proc { described_class.new(:name => 'foo', :month => ['-1','0','13'] ) }.should raise_error(Puppet::Error, /(-1|0|13) is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => ['Jax','Fex','Aux'] ) }.should raise_error(Puppet::Error, /(Jax|Fex|Aux) is not a valid month/)
      end

      it "should support valid step syntax" do
        proc { described_class.new(:name => 'foo', :month => '*/2' ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :month => '1-12/3' ) }.should_not raise_error
      end

      it "should not support invalid steps" do
        proc { described_class.new(:name => 'foo', :month => '*/A' ) }.should raise_error(Puppet::Error, /\*\/A is not a valid month/)
        proc { described_class.new(:name => 'foo', :month => '*/2A' ) }.should raise_error(Puppet::Error, /\*\/2A is not a valid month/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # proc { described_class.new(:name => 'foo', :month => '*/13' ) }.should raise_error(Puppet::Error, /is not a valid month/)
      end
    end

    describe "monthday" do
      it "should support absent" do
        proc { described_class.new(:name => 'foo', :monthday => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { described_class.new(:name => 'foo', :monthday => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :monthday => 'absent')[:monthday].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :monthday => '*')[:monthday].should == :absent
      end

      it "should support valid single values" do
        proc { described_class.new(:name => 'foo', :monthday => '1') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :monthday => '30') }.should_not raise_error
        proc { described_class.new(:name => 'foo', :monthday => '31') }.should_not raise_error
      end

      it "should not support non numeric characters" do
        proc { described_class.new(:name => 'foo', :monthday => 'z23') }.should raise_error(Puppet::Error, /z23 is not a valid monthday/)
        proc { described_class.new(:name => 'foo', :monthday => '2z3') }.should raise_error(Puppet::Error, /2z3 is not a valid monthday/)
        proc { described_class.new(:name => 'foo', :monthday => '23z') }.should raise_error(Puppet::Error, /23z is not a valid monthday/)
      end

      it "should not support single values out of range" do
        proc { described_class.new(:name => 'foo', :monthday => '-1') }.should raise_error(Puppet::Error, /-1 is not a valid monthday/)
        proc { described_class.new(:name => 'foo', :monthday => '0') }.should raise_error(Puppet::Error, /0 is not a valid monthday/)
        proc { described_class.new(:name => 'foo', :monthday => '32') }.should raise_error(Puppet::Error, /32 is not a valid monthday/)
      end

      it "should support valid multiple values" do
        proc { described_class.new(:name => 'foo', :monthday => ['1','23','31'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :monthday => ['31','23','1'] ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :monthday => ['1','31','23'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { described_class.new(:name => 'foo', :monthday => ['1','23','32'] ) }.should raise_error(Puppet::Error, /32 is not a valid monthday/)
        proc { described_class.new(:name => 'foo', :monthday => ['-1','12','23'] ) }.should raise_error(Puppet::Error, /-1 is not a valid monthday/)
        proc { described_class.new(:name => 'foo', :monthday => ['13','32','30'] ) }.should raise_error(Puppet::Error, /32 is not a valid monthday/)
        # two invalid
        proc { described_class.new(:name => 'foo', :monthday => ['-1','0','23'] ) }.should raise_error(Puppet::Error, /(-1|0) is not a valid monthday/)
        # all invalid
        proc { described_class.new(:name => 'foo', :monthday => ['-1','0','32'] ) }.should raise_error(Puppet::Error, /(-1|0|32) is not a valid monthday/)
      end

      it "should support valid step syntax" do
        proc { described_class.new(:name => 'foo', :monthday => '*/2' ) }.should_not raise_error
        proc { described_class.new(:name => 'foo', :monthday => '10-16/2' ) }.should_not raise_error
      end

      it "should not support invalid steps" do
        proc { described_class.new(:name => 'foo', :monthday => '*/A' ) }.should raise_error(Puppet::Error, /\*\/A is not a valid monthday/)
        proc { described_class.new(:name => 'foo', :monthday => '*/2A' ) }.should raise_error(Puppet::Error, /\*\/2A is not a valid monthday/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # proc { described_class.new(:name => 'foo', :monthday => '*/32' ) }.should raise_error(Puppet::Error, /is not a valid monthday/)
      end
    end

    describe "environment" do
      it "it should accept an :environment that looks like a path" do
        lambda do
          described_class.new(:name => 'foo',:environment => 'PATH=/bin:/usr/bin:/usr/sbin')
        end.should_not raise_error
      end

      it "should not accept environment variables that do not contain '='" do
        lambda do
          described_class.new(:name => 'foo',:environment => 'INVALID')
        end.should raise_error(Puppet::Error, /Invalid environment setting "INVALID"/)
      end

      it "should accept empty environment variables that do not contain '='" do
        lambda do
          described_class.new(:name => 'foo',:environment => 'MAILTO=')
        end.should_not raise_error(Puppet::Error)
      end

      it "should accept 'absent'" do
        lambda do
          described_class.new(:name => 'foo',:environment => 'absent')
        end.should_not raise_error(Puppet::Error)
      end

    end
  end

  it "should require a command when adding an entry" do
    entry = described_class.new(:name => "test_entry", :ensure => :present)
    expect { entry.value(:command) }.should raise_error(Puppet::Error, /No command/)
  end

  it "should not require a command when removing an entry" do
    entry = described_class.new(:name => "test_entry", :ensure => :absent)
    entry.value(:command).should == nil
  end

  it "should default to user => root if Etc.getpwuid(Process.uid) returns nil (#12357)" do
    Etc.expects(:getpwuid).returns(nil)
    entry = described_class.new(:name => "test_entry", :ensure => :present)
    entry.value(:user).should eql "root"
  end
end
