#!/usr/bin/env ruby

require 'spec_helper'
require 'win32/taskscheduler' if Puppet.features.microsoft_windows?

# The Windows ScheduledTask provider:
provider_class = Puppet::Type.type( :scheduled_task )

describe provider_class, :if => Puppet.features.microsoft_windows?  do
  let( :resource ) {
    provider_class.new(
      :name => 'facter-daily',
      :provider => :windows,
      :command => 'facter --debug',
      :user => 'system',
      :hour => 2,
      :minute => 0,
      :repeat => 'daily'
    )
  }

  # a simply daily schedule trigger
  let( :trigger ) {
    {
      'start_year'   => 2009,
      'start_month'  => 4,
      'start_day'   	=> 11,
      'start_hour'   => resource[ :hour ],
      'start_minute'	=> resource[ :minute ],
      'trigger_type'	=> Win32::TaskScheduler::DAILY,
      'type'         => { 'days_interval' => 1 },
    }
  }

  let( :provider )  { resource.provider }
  let( :task )      { stub 'task' }

  before :each do
    provider.stubs( :trigger ).returns( trigger )
    provider.stubs( :task ).returns( task )
    Win32::TaskScheduler.stubs( :new ).returns( task )
  end

  it 'should support basic features' do
    [ :create, :destroy, :enable, :disable, :enabled? ].each{ |f| provider.should respond_to( f ) }
  end

  describe '.instances' do
    it 'should enumerate all scheduled jobs' do
      jobs = [ 'task1.job', 'task2.job', 'task3.job' ]
      stub_jobs = jobs.map{ |j| stub( :name => j ) }
      task.stubs( :enum ).returns( jobs )
      described_class.instances.map(&:name).should =~ [ 'task1', 'task2', 'task3' ]
    end

    it 'should return absent if there are no scheduled tasks' do
      task.stubs( :enum ).returns []
      described_class.instances.should be_empty
    end

  end

  describe "when managing scheduled tasks" do

    before :each do
      task.stubs( :activate ).with( resource[ :name ] ).returns( task )
      task.stubs( :jobname ).returns( ( resource[ :name ] + ".job" ).downcase )
      task.stubs( :application_name ).returns( 'facter' )
      task.stubs( :account_information ).returns( 'system' )
      task.stubs( :flags ).returns( 0 )
      task.stubs( :working_directory= ).returns( task )
      task.stubs( :priority= ).returns( task )
      task.stubs( :set_account_information ).returns( task )
      task.stubs( :parameters ).returns( '--debug' )
    end

    describe 'creating a scheduled task' do
      before :each do
        provider.stubs( :exists? ).returns( false )
        task.expects( :application_name= )
        task.expects( :parameters= )
        task.expects( :new_work_item ).with( resource[:name], trigger ).returns( task )
        task.expects( :save ).returns( task )
      end

      it 'should create the job on the system and set its other properties'  do
        provider.create
      end

      it 'should schedule a daily task for 8:00am' do
        proc {
          resource = provider_class.new(
            :name => 'facter-daily',
            :provider => :windows,
            :command => 'facter --debug',
            :hour => 8,
            :minute => 0,
            :repeat => 'daily'
          )
          provider.create
        }.should_not raise_error
      end

      it 'should schedule a task for the 3rd of every month using the current time' do
        proc {
          resource = provider_class.new(
            :name => 'facter-bogus',
            :provider => :windows,
            :command => 'facter --debug',
            :monthday => 3,
            :repeat => 'monthly'
          )
          provider.create
        }.should_not raise_error
      end

      it 'should schedule a task for 9:00pm today that runs once' do
        proc {
          resource = provider_class.new(
            :name => 'facter-once',
            :provider => :windows,
            :command => 'facter --debug',
            :hour => 21,
            :minute => 0,
            :repeat => 'once'
          )
          provider.create
        }.should_not raise_error
      end

      it 'should NOT schedule a task for Jan 01 1900' do
        expect {
          resource = provider_class.new(
            :name => 'facter-bogus',
            :provider => :windows,
            :command => 'facter --debug',
            :year => 1900,
            :month => 1,
            :day => 1,
            :repeat => 'daily'
          )
        }.to raise_error( Puppet::Error, /Invalid parameter .*/ )
        provider.create
      end

    end

    describe "scheduled task runtime user" do

      before :each do
        provider.stubs( :exists? ).returns( true )
        provider.stubs( :user ).returns( 'system' )
        task.expects( :save )
      end

      if Puppet.features.microsoft_windows?
        it "should only allow the task to run as the SYSTEM user" do
          task.expects( :set_account_information )
          provider.user= 'newuser'
          provider.task.account_information.should == 'system'
        end

      else
        it 'should specify the runtime user'
        it 'should reassign the runtime user'
      end

    end

    describe 'when deleting a scheduled task' do
      it "should delete an existing task" do
        provider.stubs( :exists? ).returns( true )
        task.expects( :delete ).with( resource[:name] )
        provider.destroy
      end

      it "should not try to delete a non-existent task" do
        provider.stubs( :exists? ).returns( false )
        resource[ :name ] = 'nonexistent task'
        task.expects( :delete ).with( resource[ :name ] )
        provider.destroy
      end
    end

    describe "command pathnames" do
      let( :cmd  ) { 'c:/ruby/187/bin/facter.bat' }

      before :each do
        task.stubs( :application_name= ).returns( task )
        task.stubs( :save ).returns( task )
        provider.stubs( :command ).returns( cmd )
        provider.expects( :command= )
      end

      it "should handle forward slash path seps (*nix and windows)" do
        provider.command = "c:/ruby/187/bin/facter.bat"
        provider.command.should == cmd
      end

      if Puppet.features.microsoft_windows?
        it "should handle back slash path seps" do
          provider.command = "c:\\ruby\\187\\bin\\facter.bat"
          provider.command.should == cmd
        end

        it "should handle both forward AND back slash path seps" do
          provider.command = "c:/ruby/187\\bin\facter.bat"
          provider.command.should == cmd
        end
      end

      it "should handle spaces in the command name" do
        provider.command = "c:\\ruby\\187\bin\facter - Copy.bat"
      end

      it "should handle UNC pathnames" do
        provider.command = "\\localhost\ruby\bin\facter.bat"
      end
    end

    describe "task enabling" do
      it "should enable an existing task" do
        provider.stubs( :exists? ).returns( true )
        provider.expects( :enable )
        provider.exists?.should be_true
        provider.enable
        provider.enabled?.should == :true
      end

      it "should disable an existing task" do
        provider.stubs( :exists? ).returns( true )
        provider.expects( :disable )
        provider.exists?.should be_true
        provider.disable
        provider.stubs( :enabled? ).returns( :false )
        provider.enabled?.should == :false
      end

      it 'should test whether a specfic task exists' do
        resource[ :name ] = 'taskname'
        provider.stubs( :exists? ).returns( true )
        provider.exists?.should be_true

        resource[ :name ] = 'tasknam'
        provider.stubs( :exists? ).returns( false )
        provider.exists?.should_not be_true
      end
    end

    it 'should specify an accessible exec command (accessible by path, user)' do
      File.expects( :exists? ).returns( true )
      FileTest.expects( :executable? ).returns( true )
      File.exists?( task.application_name ).should == true
      FileTest.executable?( task.application_name ).should == true
    end

  end
end
