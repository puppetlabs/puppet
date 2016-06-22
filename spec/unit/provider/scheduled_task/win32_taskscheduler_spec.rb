#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/windows/taskscheduler' if Puppet.features.microsoft_windows?

shared_examples_for "a trigger that handles start_date and start_time" do
  let(:trigger) do
    described_class.new(
      :name => 'Shared Test Task',
      :command => 'C:\Windows\System32\notepad.exe'
    ).translate_hash_to_trigger(trigger_hash)
  end

  before :each do
    Win32::TaskScheduler.any_instance.stubs(:save)
  end

  describe 'the given start_date' do
    before :each do
      trigger_hash['start_time'] = '00:00'
    end

    def date_component
      {
        'start_year'  => trigger['start_year'],
        'start_month' => trigger['start_month'],
        'start_day'   => trigger['start_day']
      }
    end

    it 'should be able to be specified in ISO 8601 calendar date format' do
      trigger_hash['start_date'] = '2011-12-31'

      expect(date_component).to eq({
        'start_year'  => 2011,
        'start_month' => 12,
        'start_day'   => 31
      })
    end

    it 'should fail if before 1753-01-01' do
      trigger_hash['start_date'] = '1752-12-31'

      expect { date_component }.to raise_error(
        Puppet::Error,
        'start_date must be on or after 1753-01-01'
      )
    end

    it 'should succeed if on 1753-01-01' do
      trigger_hash['start_date'] = '1753-01-01'

      expect(date_component).to eq({
        'start_year'  => 1753,
        'start_month' => 1,
        'start_day'   => 1
      })
    end

    it 'should succeed if after 1753-01-01' do
      trigger_hash['start_date'] = '1753-01-02'

      expect(date_component).to eq({
        'start_year'  => 1753,
        'start_month' => 1,
        'start_day'   => 2
      })
    end
  end

  describe 'the given start_time' do
    before :each do
      trigger_hash['start_date'] = '2011-12-31'
    end

    def time_component
      {
        'start_hour'   => trigger['start_hour'],
        'start_minute' => trigger['start_minute']
      }
    end

    it 'should be able to be specified as a 24-hour "hh:mm"' do
      trigger_hash['start_time'] = '17:13'

      expect(time_component).to eq({
        'start_hour'   => 17,
        'start_minute' => 13
      })
    end

    it 'should be able to be specified as a 12-hour "hh:mm am"' do
      trigger_hash['start_time'] = '3:13 am'

      expect(time_component).to eq({
        'start_hour'   => 3,
        'start_minute' => 13
      })
    end

    it 'should be able to be specified as a 12-hour "hh:mm pm"' do
      trigger_hash['start_time'] = '3:13 pm'

      expect(time_component).to eq({
        'start_hour'   => 15,
        'start_minute' => 13
      })
    end
  end
end

describe Puppet::Type.type(:scheduled_task).provider(:win32_taskscheduler), :if => Puppet.features.microsoft_windows? do
  before :each do
    Puppet::Type.type(:scheduled_task).stubs(:defaultprovider).returns(described_class)
  end

  describe 'when retrieving' do
    before :each do
      @mock_task = stub
      @mock_task.responds_like(Win32::TaskScheduler.new)
      described_class.any_instance.stubs(:task).returns(@mock_task)

      Win32::TaskScheduler.stubs(:new).returns(@mock_task)
    end
    let(:resource) { Puppet::Type.type(:scheduled_task).new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }

    describe 'the triggers for a task' do
      describe 'with only one trigger' do
        before :each do
          @mock_task.expects(:trigger_count).returns(1)
        end

        it 'should handle a single daily trigger' do
          @mock_task.expects(:trigger).with(0).returns({
            'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_DAILY,
            'start_year'   => 2011,
            'start_month'  => 9,
            'start_day'    => 12,
            'start_hour'   => 13,
            'start_minute' => 20,
            'flags'        => 0,
            'type'         => { 'days_interval' => 2 },
          })

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'daily',
            'every'            => '2',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single daily with repeat trigger' do
          @mock_task.expects(:trigger).with(0).returns({
            'trigger_type'     => Win32::TaskScheduler::TASK_TIME_TRIGGER_DAILY,
            'start_year'       => 2011,
            'start_month'      => 9,
            'start_day'        => 12,
            'start_hour'       => 13,
            'start_minute'     => 20,
            'minutes_interval' => 60,
            'minutes_duration' => 180,
            'flags'            => 0,
            'type'             => { 'days_interval' => 2 },
          })

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'daily',
            'every'            => '2',
            'minutes_interval' => 60,
            'minutes_duration' => 180,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single weekly trigger' do
          scheduled_days_of_week = Win32::TaskScheduler::MONDAY |
                                   Win32::TaskScheduler::WEDNESDAY |
                                   Win32::TaskScheduler::FRIDAY |
                                   Win32::TaskScheduler::SUNDAY
          @mock_task.expects(:trigger).with(0).returns({
            'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_WEEKLY,
            'start_year'   => 2011,
            'start_month'  => 9,
            'start_day'    => 12,
            'start_hour'   => 13,
            'start_minute' => 20,
            'flags'        => 0,
            'type'         => {
              'weeks_interval' => 2,
              'days_of_week'   => scheduled_days_of_week
            }
          })

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'weekly',
            'every'            => '2',
            'day_of_week'      => ['sun', 'mon', 'wed', 'fri'],
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single monthly date-based trigger' do
          scheduled_months = Win32::TaskScheduler::JANUARY |
                             Win32::TaskScheduler::FEBRUARY |
                             Win32::TaskScheduler::AUGUST |
                             Win32::TaskScheduler::SEPTEMBER |
                             Win32::TaskScheduler::DECEMBER
          #                1   3        5        15        'last'
          scheduled_days = 1 | 1 << 2 | 1 << 4 | 1 << 14 | 1 << 31
          @mock_task.expects(:trigger).with(0).returns({
            'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_MONTHLYDATE,
            'start_year'   => 2011,
            'start_month'  => 9,
            'start_day'    => 12,
            'start_hour'   => 13,
            'start_minute' => 20,
            'flags'        => 0,
            'type'         => {
              'months' => scheduled_months,
              'days'   => scheduled_days
            }
          })

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'monthly',
            'months'           => [1, 2, 8, 9, 12],
            'on'               => [1, 3, 5, 15, 'last'],
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single monthly day-of-week-based trigger' do
          scheduled_months = Win32::TaskScheduler::JANUARY |
                             Win32::TaskScheduler::FEBRUARY |
                             Win32::TaskScheduler::AUGUST |
                             Win32::TaskScheduler::SEPTEMBER |
                             Win32::TaskScheduler::DECEMBER
          scheduled_days_of_week = Win32::TaskScheduler::MONDAY |
                                   Win32::TaskScheduler::WEDNESDAY |
                                   Win32::TaskScheduler::FRIDAY |
                                   Win32::TaskScheduler::SUNDAY
          @mock_task.expects(:trigger).with(0).returns({
            'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_MONTHLYDOW,
            'start_year'   => 2011,
            'start_month'  => 9,
            'start_day'    => 12,
            'start_hour'   => 13,
            'start_minute' => 20,
            'flags'        => 0,
            'type'         => {
              'months'       => scheduled_months,
              'weeks'        => Win32::TaskScheduler::FIRST_WEEK,
              'days_of_week' => scheduled_days_of_week
            }
          })

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'monthly',
            'months'           => [1, 2, 8, 9, 12],
            'which_occurrence' => 'first',
            'day_of_week'      => ['sun', 'mon', 'wed', 'fri'],
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single one-time trigger' do
          @mock_task.expects(:trigger).with(0).returns({
            'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
            'start_year'   => 2011,
            'start_month'  => 9,
            'start_day'    => 12,
            'start_hour'   => 13,
            'start_minute' => 20,
            'flags'        => 0,
          })

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end
      end

      it 'should handle multiple triggers' do
        @mock_task.expects(:trigger_count).returns(3)
        @mock_task.expects(:trigger).with(0).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2011,
          'start_month'  => 10,
          'start_day'    => 13,
          'start_hour'   => 14,
          'start_minute' => 21,
          'flags'        => 0,
        })
        @mock_task.expects(:trigger).with(1).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2012,
          'start_month'  => 11,
          'start_day'    => 14,
          'start_hour'   => 15,
          'start_minute' => 22,
          'flags'        => 0,
        })
        @mock_task.expects(:trigger).with(2).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2013,
          'start_month'  => 12,
          'start_day'    => 15,
          'start_hour'   => 16,
          'start_minute' => 23,
          'flags'        => 0,
        })

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2012-11-14',
            'start_time'       => '15:22',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 1,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end

      it 'should handle multiple triggers with repeat triggers' do
        @mock_task.expects(:trigger_count).returns(3)
        @mock_task.expects(:trigger).with(0).returns({
          'trigger_type'     => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'       => 2011,
          'start_month'      => 10,
          'start_day'        => 13,
          'start_hour'       => 14,
          'start_minute'     => 21,
          'minutes_interval' => 15,
          'minutes_duration' => 60,
          'flags'            => 0,
        })
        @mock_task.expects(:trigger).with(1).returns({
          'trigger_type'     => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'       => 2012,
          'start_month'      => 11,
          'start_day'        => 14,
          'start_hour'       => 15,
          'start_minute'     => 22,
          'minutes_interval' => 30,
          'minutes_duration' => 120,
          'flags'            => 0,
        })
        @mock_task.expects(:trigger).with(2).returns({
          'trigger_type'     => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'       => 2013,
          'start_month'      => 12,
          'start_day'        => 15,
          'start_hour'       => 16,
          'start_minute'     => 23,
          'minutes_interval' => 60,
          'minutes_duration' => 240,
          'flags'            => 0,
        })

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 15,
            'minutes_duration' => 60,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2012-11-14',
            'start_time'       => '15:22',
            'schedule'         => 'once',
            'minutes_interval' => 30,
            'minutes_duration' => 120,
            'enabled'          => true,
            'index'            => 1,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 60,
            'minutes_duration' => 240,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end

      it 'should skip triggers Win32::TaskScheduler cannot handle' do
        @mock_task.expects(:trigger_count).returns(3)
        @mock_task.expects(:trigger).with(0).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2011,
          'start_month'  => 10,
          'start_day'    => 13,
          'start_hour'   => 14,
          'start_minute' => 21,
          'flags'        => 0,
        })
        @mock_task.expects(:trigger).with(1).raises(
          Win32::TaskScheduler::Error.new('Unhandled trigger type!')
        )
        @mock_task.expects(:trigger).with(2).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2013,
          'start_month'  => 12,
          'start_day'    => 15,
          'start_hour'   => 16,
          'start_minute' => 23,
          'flags'        => 0,
        })

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end

      it 'should skip trigger types Puppet does not handle' do
        @mock_task.expects(:trigger_count).returns(3)
        @mock_task.expects(:trigger).with(0).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2011,
          'start_month'  => 10,
          'start_day'    => 13,
          'start_hour'   => 14,
          'start_minute' => 21,
          'flags'        => 0,
        })
        @mock_task.expects(:trigger).with(1).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_EVENT_TRIGGER_AT_LOGON,
        })
        @mock_task.expects(:trigger).with(2).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2013,
          'start_month'  => 12,
          'start_day'    => 15,
          'start_hour'   => 16,
          'start_minute' => 23,
          'flags'        => 0,
        })

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end
    end

    it 'should get the working directory from the working_directory on the task' do
      @mock_task.expects(:working_directory).returns('C:\Windows\System32')

      expect(resource.provider.working_dir).to eq('C:\Windows\System32')
    end

    it 'should get the command from the application_name on the task' do
      @mock_task.expects(:application_name).returns('C:\Windows\System32\notepad.exe')

      expect(resource.provider.command).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'should get the command arguments from the parameters on the task' do
      @mock_task.expects(:parameters).returns('these are my arguments')

      expect(resource.provider.arguments).to eq('these are my arguments')
    end

    it 'should get the user from the account_information on the task' do
      @mock_task.expects(:account_information).returns('this is my user')

      expect(resource.provider.user).to eq('this is my user')
    end

    describe 'whether the task is enabled' do
      it 'should report tasks with the disabled bit set as disabled' do
        @mock_task.stubs(:flags).returns(Win32::TaskScheduler::DISABLED)

        expect(resource.provider.enabled).to eq(:false)
      end

      it 'should report tasks without the disabled bit set as enabled' do
        @mock_task.stubs(:flags).returns(~Win32::TaskScheduler::DISABLED)

        expect(resource.provider.enabled).to eq(:true)
      end

      it 'should not consider triggers for determining if the task is enabled' do
        @mock_task.stubs(:flags).returns(~Win32::TaskScheduler::DISABLED)
        @mock_task.stubs(:trigger_count).returns(1)
        @mock_task.stubs(:trigger).with(0).returns({
          'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
          'start_year'   => 2011,
          'start_month'  => 10,
          'start_day'    => 13,
          'start_hour'   => 14,
          'start_minute' => 21,
          'flags'        => Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED,
        })

        expect(resource.provider.enabled).to eq(:true)
      end
    end
  end

  describe '#exists?' do
    before :each do
      @mock_task = stub
      @mock_task.responds_like(Win32::TaskScheduler.new)
      described_class.any_instance.stubs(:task).returns(@mock_task)

      Win32::TaskScheduler.stubs(:new).returns(@mock_task)
    end
    let(:resource) { Puppet::Type.type(:scheduled_task).new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }

    it "should delegate to Win32::TaskScheduler using the resource's name" do
      @mock_task.expects(:exists?).with('Test Task').returns(true)

      expect(resource.provider.exists?).to eq(true)
    end
  end

  describe '#clear_task' do
    before :each do
      @mock_task     = stub
      @new_mock_task = stub
      @mock_task.responds_like(Win32::TaskScheduler.new)
      @new_mock_task.responds_like(Win32::TaskScheduler.new)
      Win32::TaskScheduler.stubs(:new).returns(@mock_task, @new_mock_task)

      described_class.any_instance.stubs(:exists?).returns(false)
    end
    let(:resource) { Puppet::Type.type(:scheduled_task).new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }

    it 'should clear the cached task object' do
      expect(resource.provider.task).to eq(@mock_task)
      expect(resource.provider.task).to eq(@mock_task)

      resource.provider.clear_task

      expect(resource.provider.task).to eq(@new_mock_task)
    end

    it 'should clear the cached list of triggers for the task' do
      @mock_task.stubs(:trigger_count).returns(1)
      @mock_task.stubs(:trigger).with(0).returns({
        'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
        'start_year'   => 2011,
        'start_month'  => 10,
        'start_day'    => 13,
        'start_hour'   => 14,
        'start_minute' => 21,
        'flags'        => 0,
      })
      @new_mock_task.stubs(:trigger_count).returns(1)
      @new_mock_task.stubs(:trigger).with(0).returns({
        'trigger_type' => Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE,
        'start_year'   => 2012,
        'start_month'  => 11,
        'start_day'    => 14,
        'start_hour'   => 15,
        'start_minute' => 22,
        'flags'        => 0,
      })

      mock_task_trigger = {
        'start_date'       => '2011-10-13',
        'start_time'       => '14:21',
        'schedule'         => 'once',
        'minutes_interval' => 0,
        'minutes_duration' => 0,
        'enabled'          => true,
        'index'            => 0,
      }

      expect(resource.provider.trigger).to eq([mock_task_trigger])
      expect(resource.provider.trigger).to eq([mock_task_trigger])

      resource.provider.clear_task

      expect(resource.provider.trigger).to eq([{
        'start_date'       => '2012-11-14',
        'start_time'       => '15:22',
        'schedule'         => 'once',
        'minutes_interval' => 0,
        'minutes_duration' => 0,
        'enabled'          => true,
        'index'            => 0,
      }])
    end
  end

  describe '.instances' do
    it 'should use the list of .job files to construct the list of scheduled_tasks' do
      job_files = ['foo.job', 'bar.job', 'baz.job']
      Win32::TaskScheduler.any_instance.stubs(:tasks).returns(job_files)
      job_files.each do |job|
        job = File.basename(job, '.job')

        described_class.expects(:new).with(:provider => :win32_taskscheduler, :name => job)
      end

      described_class.instances
    end
  end

  describe '#user_insync?', :if => Puppet.features.microsoft_windows? do
    let(:resource) { described_class.new(:name => 'foobar', :command => 'C:\Windows\System32\notepad.exe') }

    it 'should consider the user as in sync if the name matches' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('joe').twice.returns('SID A')

      expect(resource).to be_user_insync('joe', ['joe'])
    end

    it 'should consider the user as in sync if the current user is fully qualified' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('joe').returns('SID A')
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('MACHINE\joe').returns('SID A')

      expect(resource).to be_user_insync('MACHINE\joe', ['joe'])
    end

    it 'should consider a current user of the empty string to be the same as the system user' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('system').twice.returns('SYSTEM SID')

      expect(resource).to be_user_insync('', ['system'])
    end

    it 'should consider different users as being different' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('joe').returns('SID A')
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('bob').returns('SID B')

      expect(resource).not_to be_user_insync('joe', ['bob'])
    end
  end

  describe '#trigger_insync?' do
    let(:resource) { described_class.new(:name => 'foobar', :command => 'C:\Windows\System32\notepad.exe') }

    it 'should not consider any extra current triggers as in sync' do
      current = [
        {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]
      desired = {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'}

      expect(resource).not_to be_trigger_insync(current, desired)
    end

    it 'should not consider any extra desired triggers as in sync' do
      current = {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'}
      desired = [
        {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]

      expect(resource).not_to be_trigger_insync(current, desired)
    end

    it 'should consider triggers to be in sync if the sets of current and desired triggers are equal' do
      current = [
        {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]
      desired = [
        {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]

      expect(resource).to be_trigger_insync(current, desired)
    end
  end

  describe '#triggers_same?' do
    let(:provider) { described_class.new(:name => 'foobar', :command => 'C:\Windows\System32\notepad.exe') }

    it "should not mutate triggers" do
      current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
      current.freeze

      desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30'}
      desired.freeze

      expect(provider).to be_triggers_same(current, desired)
    end

    it "ignores 'index' in current trigger" do
      current = {'index' => 0, 'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
      desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}

      expect(provider).to be_triggers_same(current, desired)
    end

    it "ignores 'enabled' in current triggger" do
      current = {'enabled' => true, 'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
      desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}

      expect(provider).to be_triggers_same(current, desired)
    end

    it "should not consider a disabled 'current' trigger to be the same" do
      current = {'schedule' => 'once', 'enabled' => false}
      desired = {'schedule' => 'once'}

      expect(provider).not_to be_triggers_same(current, desired)
    end

    it 'should not consider triggers with different schedules to be the same' do
      current = {'schedule' => 'once'}
      desired = {'schedule' => 'weekly'}

      expect(provider).not_to be_triggers_same(current, desired)
    end

    describe 'start_date' do
      it "considers triggers to be equal when start_date is not specified in the 'desired' trigger" do
        current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_time' => '15:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end
    end

    describe 'comparing daily triggers' do
      it "should consider 'desired' triggers not specifying 'every' to have the same value as the 'current' trigger" do
        current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30'}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2012-09-12', 'start_time' => '15:30', 'every' => 3}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:31', 'every' => 3}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-9-12',  'start_time' => '15:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '5:30',  'every' => 3}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '05:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'every' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 1}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '01:30', 'every' => 1}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing one-time triggers' do
      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30'}
        desired = {'schedule' => 'daily', 'start_date' => '2012-09-12', 'start_time' => '15:30'}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30'}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:31'}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30'}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-9-12',  'start_time' => '15:30'}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '1:30'}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '01:30'}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '01:30'}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing monthly date-based triggers' do
      it "should consider 'desired' triggers not specifying 'months' to have the same value as the 'current' trigger" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [3], 'on' => [1,'last']}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'on' => [1, 'last']}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-10-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '22:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-9-12',  'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '5:30',  'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '05:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'months' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1],    'on' => [1, 3, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'on' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing monthly day-of-week-based triggers' do
      it "should consider 'desired' triggers not specifying 'months' to have the same value as the 'current' trigger" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-10-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '22:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'months' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3, 5, 7, 9],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'which_occurrence' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'last',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'day_of_week' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['fri']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing weekly triggers' do
      it "should consider 'desired' triggers not specifying 'day_of_week' to have the same value as the 'current' trigger" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-10-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '22:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-9-12',  'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '1:30',  'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '01:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'every' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 1, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'day_of_week' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end
  end

  describe '#normalized_date' do
    it 'should format the date without leading zeros' do
      expect(described_class.normalized_date('2011-01-01')).to eq('2011-1-1')
    end
  end

  describe '#normalized_time' do
    it 'should format the time as {24h}:{minutes}' do
      expect(described_class.normalized_time('8:37 PM')).to eq('20:37')
    end
  end

  describe '#translate_hash_to_trigger' do
    before :each do
      @puppet_trigger = {
        'start_date' => '2011-1-1',
        'start_time' => '01:10'
      }
    end
    let(:provider) { described_class.new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }
    let(:trigger)  { provider.translate_hash_to_trigger(@puppet_trigger) }

    context "working with repeat every x triggers" do
      before :each do
        @puppet_trigger['schedule'] = 'once'
      end

      it 'should succeed if minutes_interval is equal to 0' do
        @puppet_trigger['minutes_interval'] = '0'

        expect(trigger['minutes_interval']).to eq(0)
      end

      it 'should default minutes_duration to a full day when minutes_interval is greater than 0 without setting minutes_duration' do
        @puppet_trigger['minutes_interval'] = '1'

        expect(trigger['minutes_duration']).to eq(1440)
      end

      it 'should succeed if minutes_interval is greater than 0 and minutes_duration is also set' do
        @puppet_trigger['minutes_interval'] = '1'
        @puppet_trigger['minutes_duration'] = '2'

        expect(trigger['minutes_interval']).to eq(1)
      end

      it 'should fail if minutes_interval is less than 0' do
        @puppet_trigger['minutes_interval'] = '-1'

        expect { trigger }.to raise_error(
          Puppet::Error,
          'minutes_interval must be an integer greater or equal to 0'
        )
      end

      it 'should fail if minutes_interval is not an integer' do
        @puppet_trigger['minutes_interval'] = 'abc'
        expect { trigger }.to raise_error(ArgumentError)
      end

      it 'should succeed if minutes_duration is equal to 0' do
        @puppet_trigger['minutes_duration'] = '0'
        expect(trigger['minutes_duration']).to eq(0)
      end

      it 'should succeed if minutes_duration is greater than 0' do
        @puppet_trigger['minutes_duration'] = '1'
        expect(trigger['minutes_duration']).to eq(1)
      end

      it 'should fail if minutes_duration is less than 0' do
        @puppet_trigger['minutes_duration'] = '-1'

        expect { trigger }.to raise_error(
          Puppet::Error,
          'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0'
        )
      end

      it 'should fail if minutes_duration is not an integer' do
        @puppet_trigger['minutes_duration'] = 'abc'
        expect { trigger }.to raise_error(ArgumentError)
      end

      it 'should succeed if minutes_duration is equal to a full day' do
        @puppet_trigger['minutes_duration'] = '1440'
        expect(trigger['minutes_duration']).to eq(1440)
      end

      it 'should succeed if minutes_duration is equal to three days' do
        @puppet_trigger['minutes_duration'] = '4320'
        expect(trigger['minutes_duration']).to eq(4320)
      end

      it 'should succeed if minutes_duration is greater than minutes_duration' do
        @puppet_trigger['minutes_interval'] = '10'
        @puppet_trigger['minutes_duration'] = '11'

        expect(trigger['minutes_interval']).to eq(10)
        expect(trigger['minutes_duration']).to eq(11)
      end

      it 'should fail if minutes_duration is equal to minutes_interval' do
        # On Windows 2003, the duration must be greater than the interval
        # on other platforms the values can be equal.
        @puppet_trigger['minutes_interval'] = '10'
        @puppet_trigger['minutes_duration'] = '10'

        expect { trigger }.to raise_error(
          Puppet::Error,
          'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0'
        )
      end

      it 'should succeed if minutes_duration and minutes_interval are both set to 0' do
        @puppet_trigger['minutes_interval'] = '0'
        @puppet_trigger['minutes_duration'] = '0'

        expect(trigger['minutes_interval']).to eq(0)
        expect(trigger['minutes_duration']).to eq(0)
      end

      it 'should fail if minutes_duration is less than minutes_interval' do
        @puppet_trigger['minutes_interval'] = '10'
        @puppet_trigger['minutes_duration'] = '9'

        expect { trigger }.to raise_error(
          Puppet::Error,
          'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0'
        )
      end

      it 'should fail if minutes_duration is less than minutes_interval and set to 0' do
        @puppet_trigger['minutes_interval'] = '10'
        @puppet_trigger['minutes_duration'] = '0'

        expect { trigger }.to raise_error(
          Puppet::Error,
          'minutes_interval cannot be set without minutes_duration also being set to a number greater than 0'
        )
      end
    end

    describe 'when given a one-time trigger' do
      before :each do
        @puppet_trigger['schedule'] = 'once'
      end

      it 'should set the trigger_type to Win32::TaskScheduler::ONCE' do
        expect(trigger['trigger_type']).to eq(Win32::TaskScheduler::ONCE)
      end

      it 'should not set a type' do
        expect(trigger).not_to be_has_key('type')
      end

      it "should require 'start_date'" do
        @puppet_trigger.delete('start_date')

        expect { trigger }.to raise_error(
          Puppet::Error,
          /Must specify 'start_date' when defining a one-time trigger/
        )
      end

      it "should require 'start_time'" do
        @puppet_trigger.delete('start_time')

        expect { trigger }.to raise_error(
          Puppet::Error,
          /Must specify 'start_time' when defining a trigger/
        )
      end

      it_behaves_like "a trigger that handles start_date and start_time" do
        let(:trigger_hash) {{'schedule' => 'once' }}
      end
    end

    describe 'when given a daily trigger' do
      before :each do
        @puppet_trigger['schedule'] = 'daily'
      end

      it "should default 'every' to 1" do
        expect(trigger['type']['days_interval']).to eq(1)
      end

      it "should use the specified value for 'every'" do
        @puppet_trigger['every'] = 5

        expect(trigger['type']['days_interval']).to eq(5)
      end

      it "should default 'start_date' to 'today'" do
        @puppet_trigger.delete('start_date')
        today = Time.now

        expect(trigger['start_year']).to eq(today.year)
        expect(trigger['start_month']).to eq(today.month)
        expect(trigger['start_day']).to eq(today.day)
      end

      it_behaves_like "a trigger that handles start_date and start_time" do
        let(:trigger_hash) {{'schedule' => 'daily', 'every' => 1}}
      end
    end

    describe 'when given a weekly trigger' do
      before :each do
        @puppet_trigger['schedule'] = 'weekly'
      end

      it "should default 'every' to 1" do
        expect(trigger['type']['weeks_interval']).to eq(1)
      end

      it "should use the specified value for 'every'" do
        @puppet_trigger['every'] = 4

        expect(trigger['type']['weeks_interval']).to eq(4)
      end

      it "should default 'day_of_week' to be every day of the week" do
        expect(trigger['type']['days_of_week']).to eq(Win32::TaskScheduler::MONDAY    |
                                                  Win32::TaskScheduler::TUESDAY   |
                                                  Win32::TaskScheduler::WEDNESDAY |
                                                  Win32::TaskScheduler::THURSDAY  |
                                                  Win32::TaskScheduler::FRIDAY    |
                                                  Win32::TaskScheduler::SATURDAY  |
                                                  Win32::TaskScheduler::SUNDAY)
      end

      it "should use the specified value for 'day_of_week'" do
        @puppet_trigger['day_of_week'] = ['mon', 'wed', 'fri']

        expect(trigger['type']['days_of_week']).to eq(Win32::TaskScheduler::MONDAY    |
                                                  Win32::TaskScheduler::WEDNESDAY |
                                                  Win32::TaskScheduler::FRIDAY)
      end

      it "should default 'start_date' to 'today'" do
        @puppet_trigger.delete('start_date')
        today = Time.now

        expect(trigger['start_year']).to eq(today.year)
        expect(trigger['start_month']).to eq(today.month)
        expect(trigger['start_day']).to eq(today.day)
      end

      it_behaves_like "a trigger that handles start_date and start_time" do
        let(:trigger_hash) {{'schedule' => 'weekly', 'every' => 1, 'day_of_week' => 'mon'}}
      end
    end

    shared_examples_for 'a monthly schedule' do
      it "should default 'months' to be every month" do
        expect(trigger['type']['months']).to eq(Win32::TaskScheduler::JANUARY   |
                                            Win32::TaskScheduler::FEBRUARY  |
                                            Win32::TaskScheduler::MARCH     |
                                            Win32::TaskScheduler::APRIL     |
                                            Win32::TaskScheduler::MAY       |
                                            Win32::TaskScheduler::JUNE      |
                                            Win32::TaskScheduler::JULY      |
                                            Win32::TaskScheduler::AUGUST    |
                                            Win32::TaskScheduler::SEPTEMBER |
                                            Win32::TaskScheduler::OCTOBER   |
                                            Win32::TaskScheduler::NOVEMBER  |
                                            Win32::TaskScheduler::DECEMBER)
      end

      it "should use the specified value for 'months'" do
        @puppet_trigger['months'] = [2, 8]

        expect(trigger['type']['months']).to eq(Win32::TaskScheduler::FEBRUARY  |
                                            Win32::TaskScheduler::AUGUST)
      end
    end

    describe 'when given a monthly date-based trigger' do
      before :each do
        @puppet_trigger['schedule'] = 'monthly'
        @puppet_trigger['on']       = [7, 14]
      end

      it_behaves_like 'a monthly schedule'

      it "should not allow 'which_occurrence' to be specified" do
        @puppet_trigger['which_occurrence'] = 'first'

        expect {trigger}.to raise_error(
          Puppet::Error,
          /Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger/
        )
      end

      it "should not allow 'day_of_week' to be specified" do
        @puppet_trigger['day_of_week'] = 'mon'

        expect {trigger}.to raise_error(
          Puppet::Error,
          /Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger/
        )
      end

      it "should require 'on'" do
        @puppet_trigger.delete('on')

        expect {trigger}.to raise_error(
          Puppet::Error,
          /Don't know how to create a 'monthly' schedule with the options: schedule, start_date, start_time/
        )
      end

      it "should default 'start_date' to 'today'" do
        @puppet_trigger.delete('start_date')
        today = Time.now

        expect(trigger['start_year']).to eq(today.year)
        expect(trigger['start_month']).to eq(today.month)
        expect(trigger['start_day']).to eq(today.day)
      end

      it_behaves_like "a trigger that handles start_date and start_time" do
        let(:trigger_hash) {{'schedule' => 'monthly', 'months' => 1, 'on' => 1}}
      end
    end

    describe 'when given a monthly day-of-week-based trigger' do
      before :each do
        @puppet_trigger['schedule']         = 'monthly'
        @puppet_trigger['which_occurrence'] = 'first'
        @puppet_trigger['day_of_week']      = 'mon'
      end

      it_behaves_like 'a monthly schedule'

      it "should not allow 'on' to be specified" do
        @puppet_trigger['on'] = 15

        expect {trigger}.to raise_error(
          Puppet::Error,
          /Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger/
        )
      end

      it "should require 'which_occurrence'" do
        @puppet_trigger.delete('which_occurrence')

        expect {trigger}.to raise_error(
          Puppet::Error,
          /which_occurrence must be specified when creating a monthly day-of-week based trigger/
        )
      end

      it "should require 'day_of_week'" do
        @puppet_trigger.delete('day_of_week')

        expect {trigger}.to raise_error(
          Puppet::Error,
          /day_of_week must be specified when creating a monthly day-of-week based trigger/
        )
      end

      it "should default 'start_date' to 'today'" do
        @puppet_trigger.delete('start_date')
        today = Time.now

        expect(trigger['start_year']).to eq(today.year)
        expect(trigger['start_month']).to eq(today.month)
        expect(trigger['start_day']).to eq(today.day)
      end

      it_behaves_like "a trigger that handles start_date and start_time" do
        let(:trigger_hash) {{'schedule' => 'monthly', 'months' => 1, 'which_occurrence' => 'first', 'day_of_week' => 'mon'}}
      end
    end
  end

  describe '#validate_trigger' do
    let(:provider) { described_class.new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }

    it 'should succeed if all passed triggers translate from hashes to triggers' do
      triggers_to_validate = [
        {'schedule' => 'once',   'start_date' => '2011-09-13', 'start_time' => '13:50'},
        {'schedule' => 'weekly', 'start_date' => '2011-09-13', 'start_time' => '13:50', 'day_of_week' => 'mon'}
      ]

      expect(provider.validate_trigger(triggers_to_validate)).to eq(true)
    end

    it 'should use the exception from translate_hash_to_trigger when it fails' do
      triggers_to_validate = [
        {'schedule' => 'once', 'start_date' => '2011-09-13', 'start_time' => '13:50'},
        {'schedule' => 'monthly', 'this is invalid' => true}
      ]

      expect {provider.validate_trigger(triggers_to_validate)}.to raise_error(
        Puppet::Error,
        /#{Regexp.escape("Unknown trigger option(s): ['this is invalid']")}/
      )
    end
  end

  describe '#flush' do
    let(:resource) do
      Puppet::Type.type(:scheduled_task).new(
        :name    => 'Test Task',
        :command => 'C:\Windows\System32\notepad.exe',
        :ensure  => @ensure
      )
    end

    before :each do
      @mock_task = stub
      @mock_task.responds_like(Win32::TaskScheduler.new)
      @mock_task.stubs(:exists?).returns(true)
      @mock_task.stubs(:activate)
      Win32::TaskScheduler.stubs(:new).returns(@mock_task)

      @command = 'C:\Windows\System32\notepad.exe'
    end

    describe 'when :ensure is :present' do
      before :each do
        @ensure = :present
      end

      it 'should save the task' do
        @mock_task.expects(:set_account_information).with(nil, nil)
        @mock_task.expects(:save)

        resource.provider.flush
      end

      it 'should fail if the command is not specified' do
        resource = Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :ensure  => @ensure
        )

        expect { resource.provider.flush }.to raise_error(
          Puppet::Error,
          'Parameter command is required.'
        )
      end
    end

    describe 'when :ensure is :absent' do
      before :each do
        @ensure = :absent
        @mock_task.stubs(:activate)
      end

      it 'should not save the task if :ensure is :absent' do
        @mock_task.expects(:save).never

        resource.provider.flush
      end

      it 'should not fail if the command is not specified' do
        @mock_task.stubs(:save)

        resource = Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :ensure  => @ensure
        )

        resource.provider.flush
      end
    end
  end

  describe 'property setter methods' do
    let(:resource) do
      Puppet::Type.type(:scheduled_task).new(
        :name    => 'Test Task',
        :command => 'C:\dummy_task.exe'
      )
    end

    before :each do
        @mock_task = stub
        @mock_task.responds_like(Win32::TaskScheduler.new)
        @mock_task.stubs(:exists?).returns(true)
        @mock_task.stubs(:activate)
        Win32::TaskScheduler.stubs(:new).returns(@mock_task)
    end

    describe '#command=' do
      it 'should set the application_name on the task' do
        @mock_task.expects(:application_name=).with('C:\Windows\System32\notepad.exe')

        resource.provider.command = 'C:\Windows\System32\notepad.exe'
      end
    end

    describe '#arguments=' do
      it 'should set the parameters on the task' do
        @mock_task.expects(:parameters=).with(['/some /arguments /here'])

        resource.provider.arguments = ['/some /arguments /here']
      end
    end

    describe '#working_dir=' do
      it 'should set the working_directory on the task' do
        @mock_task.expects(:working_directory=).with('C:\Windows\System32')

        resource.provider.working_dir = 'C:\Windows\System32'
      end
    end

    describe '#enabled=' do
      it 'should set the disabled flag if the task should be disabled' do
        @mock_task.stubs(:flags).returns(0)
        @mock_task.expects(:flags=).with(Win32::TaskScheduler::DISABLED)

        resource.provider.enabled = :false
      end

      it 'should clear the disabled flag if the task should be enabled' do
        @mock_task.stubs(:flags).returns(Win32::TaskScheduler::DISABLED)
        @mock_task.expects(:flags=).with(0)

        resource.provider.enabled = :true
      end
    end

    describe '#trigger=' do
      let(:resource) do
        Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :command => 'C:\Windows\System32\notepad.exe',
          :trigger => @trigger
        )
      end

      before :each do
        @mock_task = stub
        @mock_task.responds_like(Win32::TaskScheduler.new)
        @mock_task.stubs(:exists?).returns(true)
        @mock_task.stubs(:activate)
        Win32::TaskScheduler.stubs(:new).returns(@mock_task)
      end

      it 'should not consider all duplicate current triggers in sync with a single desired trigger' do
        @trigger = {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10'}
        current_triggers = [
          {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10', 'index' => 0},
          {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10', 'index' => 1},
          {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10', 'index' => 2},
        ]
        resource.provider.stubs(:trigger).returns(current_triggers)
        @mock_task.expects(:delete_trigger).with(1)
        @mock_task.expects(:delete_trigger).with(2)

        resource.provider.trigger = @trigger
      end

      it 'should remove triggers not defined in the resource' do
        @trigger = {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10'}
        current_triggers = [
          {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10', 'index' => 0},
          {'schedule' => 'once', 'start_date' => '2012-09-15', 'start_time' => '15:10', 'index' => 1},
          {'schedule' => 'once', 'start_date' => '2013-09-15', 'start_time' => '15:10', 'index' => 2},
        ]
        resource.provider.stubs(:trigger).returns(current_triggers)
        @mock_task.expects(:delete_trigger).with(1)
        @mock_task.expects(:delete_trigger).with(2)

        resource.provider.trigger = @trigger
      end

      it 'should add triggers defined in the resource, but not found on the system' do
        @trigger = [
          {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10'},
          {'schedule' => 'once', 'start_date' => '2012-09-15', 'start_time' => '15:10'},
          {'schedule' => 'once', 'start_date' => '2013-09-15', 'start_time' => '15:10'},
        ]
        current_triggers = [
          {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10', 'index' => 0},
        ]
        resource.provider.stubs(:trigger).returns(current_triggers)
        @mock_task.expects(:trigger=).with(resource.provider.translate_hash_to_trigger(@trigger[1]))
        @mock_task.expects(:trigger=).with(resource.provider.translate_hash_to_trigger(@trigger[2]))

        resource.provider.trigger = @trigger
      end
    end

    describe '#user=', :if => Puppet.features.microsoft_windows? do
      before :each do
        @mock_task = stub
        @mock_task.responds_like(Win32::TaskScheduler.new)
        @mock_task.stubs(:exists?).returns(true)
        @mock_task.stubs(:activate)
        Win32::TaskScheduler.stubs(:new).returns(@mock_task)
      end

      it 'should use nil for user and password when setting the user to the SYSTEM account' do
        Puppet::Util::Windows::SID.stubs(:name_to_sid).with('system').returns('SYSTEM SID')

        resource = Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :command => 'C:\dummy_task.exe',
          :user    => 'system'
        )

        @mock_task.expects(:set_account_information).with(nil, nil)

        resource.provider.user = 'system'
      end

      it 'should use the specified user and password when setting the user to anything other than SYSTEM' do
        Puppet::Util::Windows::SID.stubs(:name_to_sid).with('my_user_name').returns('SID A')

        resource = Puppet::Type.type(:scheduled_task).new(
          :name     => 'Test Task',
          :command  => 'C:\dummy_task.exe',
          :user     => 'my_user_name',
          :password => 'my password'
        )

        @mock_task.expects(:set_account_information).with('my_user_name', 'my password')

        resource.provider.user = 'my_user_name'
      end
    end
  end

  describe '#create' do
    let(:resource) do
      Puppet::Type.type(:scheduled_task).new(
        :name        => 'Test Task',
        :enabled     => @enabled,
        :command     => @command,
        :arguments   => @arguments,
        :working_dir => @working_dir,
        :trigger     => { 'schedule' => 'once', 'start_date' => '2011-09-27', 'start_time' => '17:00' }
      )
    end

    before :each do
      @enabled     = :true
      @command     = 'C:\Windows\System32\notepad.exe'
      @arguments   = '/a /list /of /arguments'
      @working_dir = 'C:\Windows\Some\Directory'

      @mock_task = stub
      @mock_task.responds_like(Win32::TaskScheduler.new)
      @mock_task.stubs(:exists?).returns(true)
      @mock_task.stubs(:activate)
      @mock_task.stubs(:application_name=)
      @mock_task.stubs(:parameters=)
      @mock_task.stubs(:working_directory=)
      @mock_task.stubs(:set_account_information)
      @mock_task.stubs(:flags)
      @mock_task.stubs(:flags=)
      @mock_task.stubs(:trigger_count).returns(0)
      @mock_task.stubs(:trigger=)
      @mock_task.stubs(:save)
      Win32::TaskScheduler.stubs(:new).returns(@mock_task)

      described_class.any_instance.stubs(:sync_triggers)
    end

    it 'should set the command' do
      resource.provider.expects(:command=).with(@command)

      resource.provider.create
    end

    it 'should set the arguments' do
      resource.provider.expects(:arguments=).with(@arguments)

      resource.provider.create
    end

    it 'should set the working_dir' do
      resource.provider.expects(:working_dir=).with(@working_dir)

      resource.provider.create
    end

    it "should set the user" do
      resource.provider.expects(:user=).with(:system)

      resource.provider.create
    end

    it 'should set the enabled property' do
      resource.provider.expects(:enabled=)

      resource.provider.create
    end

    it 'should sync triggers' do
      resource.provider.expects(:trigger=)

      resource.provider.create
    end
  end

  describe "Win32::TaskScheduler", :if => Puppet.features.microsoft_windows? do

    let(:name) { SecureRandom.uuid }

    describe 'sets appropriate generic trigger defaults' do
      before(:each) do
        @now = Time.now
        Time.stubs(:now).returns(@now)
      end

      it 'for a ONCE schedule' do
        task = Win32::TaskScheduler.new(name, { 'trigger_type' => Win32::TaskScheduler::ONCE })
        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a DAILY schedule' do
        trigger = {
          'trigger_type' => Win32::TaskScheduler::DAILY,
          'type' => { 'days_interval' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a WEEKLY schedule' do
        trigger = {
          'trigger_type' => Win32::TaskScheduler::WEEKLY,
          'type' => { 'weeks_interval' => 1, 'days_of_week' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a MONTHLYDATE schedule' do
        trigger = {
          'trigger_type' => Win32::TaskScheduler::MONTHLYDATE,
          'type' => { 'days' => 1, 'months' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a MONTHLYDOW schedule' do
        trigger = {
          'trigger_type' => Win32::TaskScheduler::MONTHLYDOW,
          'type' => { 'weeks' => 1, 'days_of_week' => 1, 'months' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end
    end

    describe 'enforces maximum lengths' do
      let(:task) { Win32::TaskScheduler.new(name, { 'trigger_type' => Win32::TaskScheduler::ONCE }) }

      it 'on account user name' do
        expect {
          task.set_account_information('a' * (Win32::TaskScheduler::MAX_ACCOUNT_LENGTH + 1), 'pass')
        }.to raise_error(Puppet::Error)
      end

      it 'on application name' do
        expect {
          task.application_name = 'a' * (Win32::TaskScheduler::MAX_PATH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on parameters' do
        expect {
          task.parameters = 'a' * (Win32::TaskScheduler::MAX_PARAMETERS_LENGTH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on working directory' do
        expect {
          task.working_directory = 'a' * (Win32::TaskScheduler::MAX_PATH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on comment' do
        expect {
          task.comment = 'a' * (Win32::TaskScheduler::MAX_COMMENT_LENGTH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on creator' do
        expect {
          task.creator = 'a' * (Win32::TaskScheduler::MAX_ACCOUNT_LENGTH + 1)
        }.to raise_error(Puppet::Error)
      end
    end

    describe '#exists?' do
      it 'works with Unicode task names' do
        task_name = name + "\u16A0\u16C7\u16BB" # ᚠᛇᚻ

        begin
          task = Win32::TaskScheduler.new(task_name, { 'trigger_type' => Win32::TaskScheduler::ONCE })
          task.save()

          expect(Puppet::FileSystem.exist?("C:\\Windows\\Tasks\\#{task_name}.job")).to be_truthy
          expect(task.exists?(task_name)).to be_truthy
        ensure
          task.delete(task_name) if Win32::TaskScheduler.new.exists?(task_name)
        end
      end

      it 'is case insensitive' do
        task_name = name + 'abc' # name is a guid, but might not have alpha chars

        begin
          task = Win32::TaskScheduler.new(task_name.upcase, { 'trigger_type' => Win32::TaskScheduler::ONCE })
          task.save()

          expect(task.exists?(task_name.downcase)).to be_truthy
        ensure
          task.delete(task_name) if Win32::TaskScheduler.new.exists?(task_name)
        end
      end
    end

    describe 'does not corrupt tasks' do
      it 'when setting maximum length values for all settings' do
        begin
          task = Win32::TaskScheduler.new(name, { 'trigger_type' => Win32::TaskScheduler::ONCE })

          application_name = 'a' * Win32::TaskScheduler::MAX_PATH
          parameters = 'b' * Win32::TaskScheduler::MAX_PARAMETERS_LENGTH
          working_directory = 'c' * Win32::TaskScheduler::MAX_PATH
          comment = 'd' * Win32::TaskScheduler::MAX_COMMENT_LENGTH
          creator = 'e' * Win32::TaskScheduler::MAX_ACCOUNT_LENGTH

          task.application_name = application_name
          task.parameters = parameters
          task.working_directory = working_directory
          task.comment = comment
          task.creator = creator

          # saving and reloading (activating) can induce COM load errors when
          # file is corrupted, which can happen when the upper bounds of these lengths are set too high
          task.save()
          task.activate(name)

          # furthermore, corrupted values may not necessarily be read back properly
          # note that SYSTEM is always returned as an empty string in account_information
          expect(task.account_information).to eq('')
          expect(task.application_name).to eq(application_name)
          expect(task.parameters).to eq(parameters)
          expect(task.working_directory).to eq(working_directory)
          expect(task.comment).to eq(comment)
          expect(task.creator).to eq(creator)
        ensure
          task.delete(name) if Win32::TaskScheduler.new.exists?(name)
        end
      end

      it 'by preventing a save() not preceded by a set_account_information()' do
        begin
          # creates a default new task with SYSTEM user
          task = Win32::TaskScheduler.new(name, { 'trigger_type' => Win32::TaskScheduler::ONCE })
          # save automatically resets the current task
          task.save()

          # re-activate named task, try to modify, and save
          task.activate(name)
          task.application_name = 'c:/windows/system32/notepad.exe'

          expect { task.save() }.to raise_error(Puppet::Error, /Account information must be set on the current task to save it properly/)

          # on a failed save, the current task is still active - add SYSTEM
          task.set_account_information('', nil)
          expect(task.save()).to be_instance_of(Win32::TaskScheduler::COM::Task)

          # the most appropriate additional validation here would be to confirm settings with schtasks.exe
          # but that test can live inside a system-level acceptance test
        ensure
          task.delete(name) if Win32::TaskScheduler.new.exists?(name)
        end
      end
    end
  end
end
