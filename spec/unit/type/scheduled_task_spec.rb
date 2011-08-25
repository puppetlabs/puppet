#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Type.type(:scheduled_task) do 
  before do
    @class = Puppet::Type.type(:scheduled_task)

    # Init a fake provider
    @provider_class = stub 'provider_class', :ancestors => [], :name => 'fake', :suitable? => true, :supports_parameter? => true
    @class.stubs(:defaultprovider).returns @provider_class
    @class.stubs(:provider).returns @provider_class

    @provider = stub 'provider', :class => @provider_class, :clean => nil
    @provider.stubs(:is_a?).returns false
    @provider_class.stubs(:new).returns @provider

    @task = @class.new( :name => "foo" )
  end

  it "should have :name be its namevar" do
    @class.key_attributes.should == [:name]
  end

  describe "when validating attributes" do

    [:name].each do |param|
      it "should have a #{param} parameter" do
        @class.attrtype(param).should == :param
      end
    end

    [:command, :minute, :hour, :weekday, :month, :monthday].each do |property|
      it "should have a #{property} property" do
        @class.attrtype(property).should == :property
      end
    end

    [:command, :minute, :hour, :weekday, :month, :monthday].each do |param|
      it "should have #{param} of type ScheduledTaskParam" do
        @class.attrclass(param).ancestors.should include ScheduledTaskParam
      end
    end

  end

  describe "when validating attribute" do

    describe "ensure" do
      it "should support present as a value for ensure" do
        proc { @class.new(:name => 'foo', :ensure => :present) }.should_not raise_error
      end

      it "should support absent as a value for ensure" do
        proc { @class.new(:name => 'foo', :ensure => :present) }.should_not raise_error
      end
    end

    describe "minute" do

      it "should support absent" do
        proc { @class.new(:name => 'foo', :minute => 'absent') }.should_not raise_error
      end

      if Puppet.features.microsoft_windows?
        it "should NOT support *" do
          proc { @class.new(:name => 'foo', :minute => '*') }.should raise_error
        end
      else
        it "should support *" do
          proc { @class.new(:name => 'foo', :minute => '*') }.should_not raise_error
        end
      end

      it "should translate absent to :absent" do
        @class.new(:name => 'foo', :minute => 'absent')[:minute].should == :absent
      end

      it "should support valid single values" do
        proc { @class.new(:name => 'foo', :minute => '0') }.should_not raise_error
        proc { @class.new(:name => 'foo', :minute => '1') }.should_not raise_error
        proc { @class.new(:name => 'foo', :minute => '59') }.should_not raise_error
      end

      it "should not support non numeric characters" do
        proc { @class.new(:name => 'foo', :minute => 'z59') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => '5z9') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => '59z') }.should raise_error(Puppet::Error)
      end

      it "should not support single values out of range" do
        proc { @class.new(:name => 'foo', :minute => '-1') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => '60') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => '61') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => '120') }.should raise_error(Puppet::Error)
      end

      it "should support valid multiple values" do
        proc { @class.new(:name => 'foo', :minute => ['0','1','59'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :minute => ['40','30','20'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :minute => ['10','30','20'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { @class.new(:name => 'foo', :minute => ['0','1','60'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => ['0','120','59'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => ['-1','1','59'] ) }.should raise_error(Puppet::Error)
        # two invalid
        proc { @class.new(:name => 'foo', :minute => ['0','61','62'] ) }.should raise_error(Puppet::Error)
        # all invalid
        proc { @class.new(:name => 'foo', :minute => ['-1','61','62'] ) }.should raise_error(Puppet::Error)
      end

      it "should NOT support valid step syntax" do
        proc { @class.new(:name => 'foo', :minute => '*/2' ) }.should raise_error
        proc { @class.new(:name => 'foo', :minute => '10-16/2' ) }.should raise_error
      end

      it "should NOT support invalid steps" do
        proc { @class.new(:name => 'foo', :minute => '*/A' ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :minute => '*/2A' ) }.should raise_error(Puppet::Error)
      end

    end

    describe "hour" do

     it "should support absent" do
        proc { @class.new(:name => 'foo', :hour => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { @class.new(:name => 'foo', :hour => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        @class.new(:name => 'foo', :hour => 'absent')[:hour].should == :absent
      end

      it "should translate * to :absent" do
        @class.new(:name => 'foo', :hour => '*')[:hour].should == :absent
      end

      it "should support valid single values" do
        proc { @class.new(:name => 'foo', :hour => '0') }.should_not raise_error
        proc { @class.new(:name => 'foo', :hour => '11') }.should_not raise_error
        proc { @class.new(:name => 'foo', :hour => '12') }.should_not raise_error
        proc { @class.new(:name => 'foo', :hour => '13') }.should_not raise_error
        proc { @class.new(:name => 'foo', :hour => '23') }.should_not raise_error
      end

      it "should not support non numeric characters" do
        proc { @class.new(:name => 'foo', :hour => 'z15') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :hour => '1z5') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :hour => '15z') }.should raise_error(Puppet::Error)
      end

      it "should not support single values out of range" do
        proc { @class.new(:name => 'foo', :hour => '-1') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :hour => '24') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :hour => '120') }.should raise_error(Puppet::Error)
      end

      it "should support valid multiple values" do
        proc { @class.new(:name => 'foo', :hour => ['0','1','23'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :hour => ['5','16','14'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :hour => ['16','13','9'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { @class.new(:name => 'foo', :hour => ['0','1','24'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :hour => ['0','-1','5'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :hour => ['-1','1','23'] ) }.should raise_error(Puppet::Error)
        # two invalid
        proc { @class.new(:name => 'foo', :hour => ['0','25','26'] ) }.should raise_error(Puppet::Error)
        # all invalid
        proc { @class.new(:name => 'foo', :hour => ['-1','24','120'] ) }.should raise_error(Puppet::Error)
      end

      it "should NOT support valid step syntax" do
        proc { @class.new(:name => 'foo', :hour => '*/2' ) }.should raise_error
        proc { @class.new(:name => 'foo', :hour => '10-18/4' ) }.should raise_error
      end

      it "should NOT support invalid steps" do
        proc { @class.new(:name => 'foo', :hour => '*/A' ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :hour => '*/2A' ) }.should raise_error(Puppet::Error)
      end

    end

   describe "weekday" do

      it "should support absent" do
        proc { @class.new(:name => 'foo', :weekday => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { @class.new(:name => 'foo', :weekday => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        @class.new(:name => 'foo', :weekday => 'absent')[:weekday].should == :absent
      end

      it "should translate * to :absent" do
        @class.new(:name => 'foo', :weekday => '*')[:weekday].should == :absent
      end

      it "should support valid numeric weekdays" do
        proc { @class.new(:name => 'foo', :weekday => '0') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => '1') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => '6') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => '7') }.should_not raise_error
      end

      it "should support valid weekdays as words (3 character version)" do
        proc { @class.new(:name => 'foo', :weekday => 'Monday') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Tuesday') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Wednesday') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Thursday') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Friday') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Saturday') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Sunday') }.should_not raise_error
      end

      it "should support valid weekdays as words (3 character version)" do
        proc { @class.new(:name => 'foo', :weekday => 'Mon') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Tue') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Wed') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Thu') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Fri') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Sat') }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => 'Sun') }.should_not raise_error
      end

      it "should not support numeric values out of range" do
        proc { @class.new(:name => 'foo', :weekday => '-1') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :weekday => '8') }.should raise_error(Puppet::Error)
      end

      it "should not support invalid weekday names" do
        proc { @class.new(:name => 'foo', :weekday => 'Sar') }.should raise_error(Puppet::Error)
      end

      it "should support valid multiple values" do
        proc { @class.new(:name => 'foo', :weekday => ['0','1','6'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :weekday => ['Mon','Wed','Friday'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { @class.new(:name => 'foo', :weekday => ['0','1','8'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :weekday => ['Mon','Fii','Sat'] ) }.should raise_error(Puppet::Error)
        # two invalid
        proc { @class.new(:name => 'foo', :weekday => ['Mos','Fii','Sat'] ) }.should raise_error(Puppet::Error)
        # all invalid
        proc { @class.new(:name => 'foo', :weekday => ['Mos','Fii','Saa'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :weekday => ['-1','8','11'] ) }.should raise_error(Puppet::Error)
      end

      it "should NOT support valid step syntax" do
        proc { @class.new(:name => 'foo', :weekday => '*/2' ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :weekday => '0-4/2' ) }.should raise_error(Puppet::Error)
      end
    end

    describe "month" do

      it "should support absent" do
        proc { @class.new(:name => 'foo', :month => 'absent') }.should_not raise_error
      end

      it "should upport *" do
        proc { @class.new(:name => 'foo', :month => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        @class.new(:name => 'foo', :month => 'absent')[:month].should == :absent
      end

      it "should translate * to :absent" do
        @class.new(:name => 'foo', :month => '*')[:month].should == :absent
      end

      it "should support valid numeric values" do
        proc { @class.new(:name => 'foo', :month => '1') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => '12') }.should_not raise_error
      end

      it "should support valid months as words" do
        proc { @class.new(:name => 'foo', :month => 'January') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'February') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'March') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'April') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'May') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'June') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'July') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'August') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'September') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'October') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'November') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'December') }.should_not raise_error
      end

      it "should support valid months as words (3 character short version)" do
        proc { @class.new(:name => 'foo', :month => 'Jan') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Feb') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Mar') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Apr') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'May') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Jun') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Jul') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Aug') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Sep') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Oct') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Nov') }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => 'Dec') }.should_not raise_error
      end

      it "should not support numeric values out of range" do
        proc { @class.new(:name => 'foo', :month => '-1') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => '0') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => '13') }.should raise_error(Puppet::Error)
      end

      it "should not support words that are not valid months" do
        proc { @class.new(:name => 'foo', :month => 'Jal') }.should raise_error(Puppet::Error)
      end

      it "should not support single values out of range" do

        proc { @class.new(:name => 'foo', :month => '-1') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => '60') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => '61') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => '120') }.should raise_error(Puppet::Error)
      end

      it "should support valid multiple values" do
        proc { @class.new(:name => 'foo', :month => ['1','9','12'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :month => ['Jan','March','Jul'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { @class.new(:name => 'foo', :month => ['0','1','12'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => ['1','13','10'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => ['Jan','Feb','Jxx'] ) }.should raise_error(Puppet::Error)
        # two invalid
        proc { @class.new(:name => 'foo', :month => ['Jan','Fex','Jux'] ) }.should raise_error(Puppet::Error)
        # all invalid
        proc { @class.new(:name => 'foo', :month => ['-1','0','13'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => ['Jax','Fex','Aux'] ) }.should raise_error(Puppet::Error)
      end

      it "should NOT support valid step syntax" do
        proc { @class.new(:name => 'foo', :month => '*/2' ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :month => '*/2A' ) }.should raise_error(Puppet::Error)
      end

    end

    describe "monthday" do

      it "should support absent" do
        proc { @class.new(:name => 'foo', :monthday => 'absent') }.should_not raise_error
      end

      it "should support *" do
        proc { @class.new(:name => 'foo', :monthday => '*') }.should_not raise_error
      end

      it "should translate absent to :absent" do
        @class.new(:name => 'foo', :monthday => 'absent')[:monthday].should == :absent
      end

      it "should translate * to :absent" do
        @class.new(:name => 'foo', :monthday => '*')[:monthday].should == :absent
      end

      it "should support valid single values" do
        proc { @class.new(:name => 'foo', :monthday => '1') }.should_not raise_error
        proc { @class.new(:name => 'foo', :monthday => '30') }.should_not raise_error
        proc { @class.new(:name => 'foo', :monthday => '31') }.should_not raise_error
      end

      it "should not support non numeric characters" do
        proc { @class.new(:name => 'foo', :monthday => 'z23') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :monthday => '2z3') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :monthday => '23z') }.should raise_error(Puppet::Error)
      end

      it "should not support single values out of range" do
        proc { @class.new(:name => 'foo', :monthday => '-1') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :monthday => '0') }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :monthday => '32') }.should raise_error(Puppet::Error)
      end

      it "should support valid multiple values" do
        proc { @class.new(:name => 'foo', :monthday => ['1','23','31'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :monthday => ['31','23','1'] ) }.should_not raise_error
        proc { @class.new(:name => 'foo', :monthday => ['1','31','23'] ) }.should_not raise_error
      end

      it "should not support multiple values if at least one is invalid" do
        # one invalid
        proc { @class.new(:name => 'foo', :monthday => ['1','23','32'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :monthday => ['-1','12','23'] ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :monthday => ['13','32','30'] ) }.should raise_error(Puppet::Error)
        # two invalid
        proc { @class.new(:name => 'foo', :monthday => ['-1','0','23'] ) }.should raise_error(Puppet::Error)
        # all invalid
        proc { @class.new(:name => 'foo', :monthday => ['-1','0','32'] ) }.should raise_error(Puppet::Error)
      end

      it "should NOT support valid step syntax" do
        proc { @class.new(:name => 'foo', :monthday => '*/2' ) }.should raise_error(Puppet::Error)
        proc { @class.new(:name => 'foo', :monthday => '10-16/2A' ) }.should raise_error(Puppet::Error)
      end
    end

  end

  it "should require a command when adding an entry" do
    entry = @class.new(:name => "test_entry", :ensure => :present)
    expect { entry.value(:command) }.should raise_error(/No command/)
  end

  it "should not require a command when removing an entry" do
    entry = @class.new(:name => "test_entry", :ensure => :absent)
    entry.value(:command).should == nil
  end


  it "should specify a repeat cycle withing the supported periods" do
    ['hourly', 'daily', 'weekly', 'monthly', 'once'].each{ |r|
      proc { @class.new(:name => 'foo', :repeat => r) }.should_not raise_error
    }
  end

end
