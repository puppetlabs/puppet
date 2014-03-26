#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:cron), :unless => Puppet.features.microsoft_windows? do
  let(:simple_provider) do
    @provider_class = described_class.provide(:simple) { mk_resource_methods }
    @provider_class.stubs(:suitable?).returns true
    @provider_class
  end

  before :each do
    described_class.stubs(:defaultprovider).returns @provider_class
  end

  after :each do
    described_class.unprovide(:simple)
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


  describe "when validating values" do

    describe "ensure" do
      it "should support present as a value for ensure" do
        expect { described_class.new(:name => 'foo', :ensure => :present) }.to_not raise_error
      end

      it "should support absent as a value for ensure" do
        expect { described_class.new(:name => 'foo', :ensure => :present) }.to_not raise_error
      end

      it "should not support other values" do
        expect { described_class.new(:name => 'foo', :ensure => :foo) }.to raise_error(Puppet::Error, /Invalid value/)
      end
    end

    describe "command" do
      it "should discard leading spaces" do
        described_class.new(:name => 'foo', :command => " /bin/true")[:command].should_not match Regexp.new(" ")
      end
      it "should discard trailing spaces" do
        described_class.new(:name => 'foo', :command => "/bin/true ")[:command].should_not match Regexp.new(" ")
      end
    end

    describe "minute" do
      it "should support absent" do
        expect { described_class.new(:name => 'foo', :minute => 'absent') }.to_not raise_error
      end

      it "should support *" do
        expect { described_class.new(:name => 'foo', :minute => '*') }.to_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :minute => 'absent')[:minute].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :minute => '*')[:minute].should == :absent
      end

      it "should support valid single values" do
        expect { described_class.new(:name => 'foo', :minute => '0') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :minute => '1') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :minute => '59') }.to_not raise_error
      end

      it "should not support non numeric characters" do
        expect { described_class.new(:name => 'foo', :minute => 'z59') }.to raise_error(Puppet::Error, /z59 is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => '5z9') }.to raise_error(Puppet::Error, /5z9 is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => '59z') }.to raise_error(Puppet::Error, /59z is not a valid minute/)
      end

      it "should not support single values out of range" do

        expect { described_class.new(:name => 'foo', :minute => '-1') }.to raise_error(Puppet::Error, /-1 is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => '60') }.to raise_error(Puppet::Error, /60 is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => '61') }.to raise_error(Puppet::Error, /61 is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => '120') }.to raise_error(Puppet::Error, /120 is not a valid minute/)
      end

      it "should support valid multiple values" do
        expect { described_class.new(:name => 'foo', :minute => ['0','1','59'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :minute => ['40','30','20'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :minute => ['10','30','20'] ) }.to_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        expect { described_class.new(:name => 'foo', :minute => ['0','1','60'] ) }.to raise_error(Puppet::Error, /60 is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => ['0','120','59'] ) }.to raise_error(Puppet::Error, /120 is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => ['-1','1','59'] ) }.to raise_error(Puppet::Error, /-1 is not a valid minute/)
        # two invalid
        expect { described_class.new(:name => 'foo', :minute => ['0','61','62'] ) }.to raise_error(Puppet::Error, /(61|62) is not a valid minute/)
        # all invalid
        expect { described_class.new(:name => 'foo', :minute => ['-1','61','62'] ) }.to raise_error(Puppet::Error, /(-1|61|62) is not a valid minute/)
      end

      it "should support valid step syntax" do
        expect { described_class.new(:name => 'foo', :minute => '*/2' ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :minute => '10-16/2' ) }.to_not raise_error
      end

      it "should not support invalid steps" do
        expect { described_class.new(:name => 'foo', :minute => '*/A' ) }.to raise_error(Puppet::Error, /\*\/A is not a valid minute/)
        expect { described_class.new(:name => 'foo', :minute => '*/2A' ) }.to raise_error(Puppet::Error, /\*\/2A is not a valid minute/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # expect { described_class.new(:name => 'foo', :minute => '*/120' ) }.to raise_error(Puppet::Error, /is not a valid minute/)
      end
    end

    describe "hour" do
      it "should support absent" do
        expect { described_class.new(:name => 'foo', :hour => 'absent') }.to_not raise_error
      end

      it "should support *" do
        expect { described_class.new(:name => 'foo', :hour => '*') }.to_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :hour => 'absent')[:hour].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :hour => '*')[:hour].should == :absent
      end

      it "should support valid single values" do
        expect { described_class.new(:name => 'foo', :hour => '0') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :hour => '11') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :hour => '12') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :hour => '13') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :hour => '23') }.to_not raise_error
      end

      it "should not support non numeric characters" do
        expect { described_class.new(:name => 'foo', :hour => 'z15') }.to raise_error(Puppet::Error, /z15 is not a valid hour/)
        expect { described_class.new(:name => 'foo', :hour => '1z5') }.to raise_error(Puppet::Error, /1z5 is not a valid hour/)
        expect { described_class.new(:name => 'foo', :hour => '15z') }.to raise_error(Puppet::Error, /15z is not a valid hour/)
      end

      it "should not support single values out of range" do
        expect { described_class.new(:name => 'foo', :hour => '-1') }.to raise_error(Puppet::Error, /-1 is not a valid hour/)
        expect { described_class.new(:name => 'foo', :hour => '24') }.to raise_error(Puppet::Error, /24 is not a valid hour/)
        expect { described_class.new(:name => 'foo', :hour => '120') }.to raise_error(Puppet::Error, /120 is not a valid hour/)
      end

      it "should support valid multiple values" do
        expect { described_class.new(:name => 'foo', :hour => ['0','1','23'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :hour => ['5','16','14'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :hour => ['16','13','9'] ) }.to_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        expect { described_class.new(:name => 'foo', :hour => ['0','1','24'] ) }.to raise_error(Puppet::Error, /24 is not a valid hour/)
        expect { described_class.new(:name => 'foo', :hour => ['0','-1','5'] ) }.to raise_error(Puppet::Error, /-1 is not a valid hour/)
        expect { described_class.new(:name => 'foo', :hour => ['-1','1','23'] ) }.to raise_error(Puppet::Error, /-1 is not a valid hour/)
        # two invalid
        expect { described_class.new(:name => 'foo', :hour => ['0','25','26'] ) }.to raise_error(Puppet::Error, /(25|26) is not a valid hour/)
        # all invalid
        expect { described_class.new(:name => 'foo', :hour => ['-1','24','120'] ) }.to raise_error(Puppet::Error, /(-1|24|120) is not a valid hour/)
      end

      it "should support valid step syntax" do
        expect { described_class.new(:name => 'foo', :hour => '*/2' ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :hour => '10-18/4' ) }.to_not raise_error
      end

      it "should not support invalid steps" do
        expect { described_class.new(:name => 'foo', :hour => '*/A' ) }.to raise_error(Puppet::Error, /\*\/A is not a valid hour/)
        expect { described_class.new(:name => 'foo', :hour => '*/2A' ) }.to raise_error(Puppet::Error, /\*\/2A is not a valid hour/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # expect { described_class.new(:name => 'foo', :hour => '*/26' ) }.to raise_error(Puppet::Error, /is not a valid hour/)
      end
    end

    describe "weekday" do
      it "should support absent" do
        expect { described_class.new(:name => 'foo', :weekday => 'absent') }.to_not raise_error
      end

      it "should support *" do
        expect { described_class.new(:name => 'foo', :weekday => '*') }.to_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :weekday => 'absent')[:weekday].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :weekday => '*')[:weekday].should == :absent
      end

      it "should support valid numeric weekdays" do
        expect { described_class.new(:name => 'foo', :weekday => '0') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => '1') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => '6') }.to_not raise_error
        # According to http://www.manpagez.com/man/5/crontab 7 is also valid (Sunday)
        expect { described_class.new(:name => 'foo', :weekday => '7') }.to_not raise_error
      end

      it "should support valid weekdays as words (long version)" do
        expect { described_class.new(:name => 'foo', :weekday => 'Monday') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Tuesday') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Wednesday') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Thursday') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Friday') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Saturday') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Sunday') }.to_not raise_error
      end

      it "should support valid weekdays as words (3 character version)" do
        expect { described_class.new(:name => 'foo', :weekday => 'Mon') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Tue') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Wed') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Thu') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Fri') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Sat') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => 'Sun') }.to_not raise_error
      end

      it "should not support numeric values out of range" do
        expect { described_class.new(:name => 'foo', :weekday => '-1') }.to raise_error(Puppet::Error, /-1 is not a valid weekday/)
        expect { described_class.new(:name => 'foo', :weekday => '8') }.to raise_error(Puppet::Error, /8 is not a valid weekday/)
      end

      it "should not support invalid weekday names" do
        expect { described_class.new(:name => 'foo', :weekday => 'Sar') }.to raise_error(Puppet::Error, /Sar is not a valid weekday/)
      end

      it "should support valid multiple values" do
        expect { described_class.new(:name => 'foo', :weekday => ['0','1','6'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => ['Mon','Wed','Friday'] ) }.to_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        expect { described_class.new(:name => 'foo', :weekday => ['0','1','8'] ) }.to raise_error(Puppet::Error, /8 is not a valid weekday/)
        expect { described_class.new(:name => 'foo', :weekday => ['Mon','Fii','Sat'] ) }.to raise_error(Puppet::Error, /Fii is not a valid weekday/)
        # two invalid
        expect { described_class.new(:name => 'foo', :weekday => ['Mos','Fii','Sat'] ) }.to raise_error(Puppet::Error, /(Mos|Fii) is not a valid weekday/)
        # all invalid
        expect { described_class.new(:name => 'foo', :weekday => ['Mos','Fii','Saa'] ) }.to raise_error(Puppet::Error, /(Mos|Fii|Saa) is not a valid weekday/)
        expect { described_class.new(:name => 'foo', :weekday => ['-1','8','11'] ) }.to raise_error(Puppet::Error, /(-1|8|11) is not a valid weekday/)
      end

      it "should support valid step syntax" do
        expect { described_class.new(:name => 'foo', :weekday => '*/2' ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :weekday => '0-4/2' ) }.to_not raise_error
      end

      it "should not support invalid steps" do
        expect { described_class.new(:name => 'foo', :weekday => '*/A' ) }.to raise_error(Puppet::Error, /\*\/A is not a valid weekday/)
        expect { described_class.new(:name => 'foo', :weekday => '*/2A' ) }.to raise_error(Puppet::Error, /\*\/2A is not a valid weekday/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # expect { described_class.new(:name => 'foo', :weekday => '*/9' ) }.to raise_error(Puppet::Error, /is not a valid weekday/)
      end
    end

    describe "month" do
      it "should support absent" do
        expect { described_class.new(:name => 'foo', :month => 'absent') }.to_not raise_error
      end

      it "should support *" do
        expect { described_class.new(:name => 'foo', :month => '*') }.to_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :month => 'absent')[:month].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :month => '*')[:month].should == :absent
      end

      it "should support valid numeric values" do
        expect { described_class.new(:name => 'foo', :month => '1') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => '12') }.to_not raise_error
      end

      it "should support valid months as words" do
        expect { described_class.new(:name => 'foo', :month => 'January') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'February') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'March') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'April') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'May') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'June') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'July') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'August') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'September') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'October') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'November') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'December') }.to_not raise_error
      end

      it "should support valid months as words (3 character short version)" do
        expect { described_class.new(:name => 'foo', :month => 'Jan') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Feb') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Mar') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Apr') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'May') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Jun') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Jul') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Aug') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Sep') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Oct') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Nov') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => 'Dec') }.to_not raise_error
      end

      it "should not support numeric values out of range" do
        expect { described_class.new(:name => 'foo', :month => '-1') }.to raise_error(Puppet::Error, /-1 is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => '0') }.to raise_error(Puppet::Error, /0 is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => '13') }.to raise_error(Puppet::Error, /13 is not a valid month/)
      end

      it "should not support words that are not valid months" do
        expect { described_class.new(:name => 'foo', :month => 'Jal') }.to raise_error(Puppet::Error, /Jal is not a valid month/)
      end

      it "should not support single values out of range" do

        expect { described_class.new(:name => 'foo', :month => '-1') }.to raise_error(Puppet::Error, /-1 is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => '60') }.to raise_error(Puppet::Error, /60 is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => '61') }.to raise_error(Puppet::Error, /61 is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => '120') }.to raise_error(Puppet::Error, /120 is not a valid month/)
      end

      it "should support valid multiple values" do
        expect { described_class.new(:name => 'foo', :month => ['1','9','12'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => ['Jan','March','Jul'] ) }.to_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        expect { described_class.new(:name => 'foo', :month => ['0','1','12'] ) }.to raise_error(Puppet::Error, /0 is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => ['1','13','10'] ) }.to raise_error(Puppet::Error, /13 is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => ['Jan','Feb','Jxx'] ) }.to raise_error(Puppet::Error, /Jxx is not a valid month/)
        # two invalid
        expect { described_class.new(:name => 'foo', :month => ['Jan','Fex','Jux'] ) }.to raise_error(Puppet::Error, /(Fex|Jux) is not a valid month/)
        # all invalid
        expect { described_class.new(:name => 'foo', :month => ['-1','0','13'] ) }.to raise_error(Puppet::Error, /(-1|0|13) is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => ['Jax','Fex','Aux'] ) }.to raise_error(Puppet::Error, /(Jax|Fex|Aux) is not a valid month/)
      end

      it "should support valid step syntax" do
        expect { described_class.new(:name => 'foo', :month => '*/2' ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :month => '1-12/3' ) }.to_not raise_error
      end

      it "should not support invalid steps" do
        expect { described_class.new(:name => 'foo', :month => '*/A' ) }.to raise_error(Puppet::Error, /\*\/A is not a valid month/)
        expect { described_class.new(:name => 'foo', :month => '*/2A' ) }.to raise_error(Puppet::Error, /\*\/2A is not a valid month/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # expect { described_class.new(:name => 'foo', :month => '*/13' ) }.to raise_error(Puppet::Error, /is not a valid month/)
      end
    end

    describe "monthday" do
      it "should support absent" do
        expect { described_class.new(:name => 'foo', :monthday => 'absent') }.to_not raise_error
      end

      it "should support *" do
        expect { described_class.new(:name => 'foo', :monthday => '*') }.to_not raise_error
      end

      it "should translate absent to :absent" do
        described_class.new(:name => 'foo', :monthday => 'absent')[:monthday].should == :absent
      end

      it "should translate * to :absent" do
        described_class.new(:name => 'foo', :monthday => '*')[:monthday].should == :absent
      end

      it "should support valid single values" do
        expect { described_class.new(:name => 'foo', :monthday => '1') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :monthday => '30') }.to_not raise_error
        expect { described_class.new(:name => 'foo', :monthday => '31') }.to_not raise_error
      end

      it "should not support non numeric characters" do
        expect { described_class.new(:name => 'foo', :monthday => 'z23') }.to raise_error(Puppet::Error, /z23 is not a valid monthday/)
        expect { described_class.new(:name => 'foo', :monthday => '2z3') }.to raise_error(Puppet::Error, /2z3 is not a valid monthday/)
        expect { described_class.new(:name => 'foo', :monthday => '23z') }.to raise_error(Puppet::Error, /23z is not a valid monthday/)
      end

      it "should not support single values out of range" do
        expect { described_class.new(:name => 'foo', :monthday => '-1') }.to raise_error(Puppet::Error, /-1 is not a valid monthday/)
        expect { described_class.new(:name => 'foo', :monthday => '0') }.to raise_error(Puppet::Error, /0 is not a valid monthday/)
        expect { described_class.new(:name => 'foo', :monthday => '32') }.to raise_error(Puppet::Error, /32 is not a valid monthday/)
      end

      it "should support valid multiple values" do
        expect { described_class.new(:name => 'foo', :monthday => ['1','23','31'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :monthday => ['31','23','1'] ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :monthday => ['1','31','23'] ) }.to_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        expect { described_class.new(:name => 'foo', :monthday => ['1','23','32'] ) }.to raise_error(Puppet::Error, /32 is not a valid monthday/)
        expect { described_class.new(:name => 'foo', :monthday => ['-1','12','23'] ) }.to raise_error(Puppet::Error, /-1 is not a valid monthday/)
        expect { described_class.new(:name => 'foo', :monthday => ['13','32','30'] ) }.to raise_error(Puppet::Error, /32 is not a valid monthday/)
        # two invalid
        expect { described_class.new(:name => 'foo', :monthday => ['-1','0','23'] ) }.to raise_error(Puppet::Error, /(-1|0) is not a valid monthday/)
        # all invalid
        expect { described_class.new(:name => 'foo', :monthday => ['-1','0','32'] ) }.to raise_error(Puppet::Error, /(-1|0|32) is not a valid monthday/)
      end

      it "should support valid step syntax" do
        expect { described_class.new(:name => 'foo', :monthday => '*/2' ) }.to_not raise_error
        expect { described_class.new(:name => 'foo', :monthday => '10-16/2' ) }.to_not raise_error
      end

      it "should not support invalid steps" do
        expect { described_class.new(:name => 'foo', :monthday => '*/A' ) }.to raise_error(Puppet::Error, /\*\/A is not a valid monthday/)
        expect { described_class.new(:name => 'foo', :monthday => '*/2A' ) }.to raise_error(Puppet::Error, /\*\/2A is not a valid monthday/)
        # As it turns out cron does not complaining about steps that exceed the valid range
        # expect { described_class.new(:name => 'foo', :monthday => '*/32' ) }.to raise_error(Puppet::Error, /is not a valid monthday/)
      end
    end

    describe "special" do
      %w(reboot yearly annually monthly weekly daily midnight hourly).each do |value|
        it "should support the value '#{value}'" do
          expect { described_class.new(:name => 'foo', :special => value ) }.to_not raise_error(Puppet::Error, /cannot specify both a special schedule and a value/)
        end
      end

      context "when combined with numeric schedule fields" do
        context "which are 'absent'" do
          [ %w(reboot yearly annually monthly weekly daily midnight hourly), :absent ].flatten.each { |value|
            it "should accept the value '#{value}' for special" do
              expect {
                described_class.new(:name => 'foo', :minute => :absent, :special => value )
              }.to_not raise_error(Puppet::Error, /cannot specify both a special schedule and a value/)
            end
          }
        end
        context "which are not absent" do
          %w(reboot yearly annually monthly weekly daily midnight hourly).each { |value|
            it "should not accept the value '#{value}' for special" do
              expect {
                described_class.new(:name => 'foo', :minute => "1", :special => value )
              }.to raise_error(Puppet::Error, /cannot specify both a special schedule and a value/)
            end
          }
          it "should accept the 'absent' value for special" do
            expect {
              described_class.new(:name => 'foo', :minute => "1", :special => :absent )
            }.to_not raise_error(Puppet::Error, /cannot specify both a special schedule and a value/)
          end
        end
      end
    end

    describe "environment" do
      it "it should accept an :environment that looks like a path" do
        expect do
          described_class.new(:name => 'foo',:environment => 'PATH=/bin:/usr/bin:/usr/sbin')
        end.to_not raise_error
      end

      it "should not accept environment variables that do not contain '='" do
        expect do
          described_class.new(:name => 'foo',:environment => 'INVALID')
        end.to raise_error(Puppet::Error, /Invalid environment setting "INVALID"/)
      end

      it "should accept empty environment variables that do not contain '='" do
        expect do
          described_class.new(:name => 'foo',:environment => 'MAILTO=')
        end.to_not raise_error
      end

      it "should accept 'absent'" do
        expect do
          described_class.new(:name => 'foo',:environment => 'absent')
        end.to_not raise_error
      end

    end
  end

  describe "when autorequiring resources" do

    before :each do
      @user_bob = Puppet::Type.type(:user).new(:name => 'bob', :ensure => :present)
      @user_alice = Puppet::Type.type(:user).new(:name => 'alice', :ensure => :present)
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @user_bob, @user_alice
    end

    it "should autorequire the user" do
      @resource = described_class.new(:name => 'dummy', :command => '/usr/bin/uptime', :user => 'alice')
      @catalog.add_resource @resource
      req = @resource.autorequire
      req.size.should == 1
      req[0].target.must == @resource
      req[0].source.must == @user_alice
    end
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
