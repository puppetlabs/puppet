#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet/util/windows/taskscheduler2'

RSpec::Matchers.define :be_same_as_powershell_command do |ps_cmd|
  define_method :run_ps do |cmd|
    full_cmd = "powershell.exe -NoLogo -NoProfile -NonInteractive -Command \"#{cmd}\""

    result = `#{full_cmd}`

    result.strip
  end

  match do |actual|
    from_ps = run_ps(ps_cmd)

    # This matcher probably won't tolerate UTF8 characters
    actual.to_s == from_ps
  end

  failure_message do |actual|
    "expected that #{actual} would match #{run_ps(ps_cmd)} from PowerShell command #{ps_cmd}"
  end
end

def create_test_task(task_name = nil, task_compatiblity = Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V2)
  task_name = Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER + 'puppet_task_' + SecureRandom.uuid.to_s if task_name.nil?
  task = Puppet::Util::Windows::TaskScheduler2.new()
  task.new_task_defintion(task_name)
  task.compatibility = task_compatiblity # Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V2
  task.append_trigger({
    "type"               => 1,
    "id"                 => "",
    "repetition"  => {
      "interval"          => "",
      "duration"          => "",
      "stopatdurationend" => false
    },
    "executiontimelimit" => "",
    "startboundary"      => "2017-09-11T14:02:00",
    "endboundary"        => "",
    "enabled"            => true,
    "randomdelay"        => "",
    "type_name"          => "ITimeTrigger"
  })
  new_action = task.create_action(Puppet::Util::Windows::TaskScheduler2::TASK_ACTION_EXEC)
  new_action.Path = 'cmd.exe'
  new_action.Arguments = '/c exit 0'
  task.set_principal('',nil)
  task.definition.Settings.Enabled = false
  task.save

  task_name
end

describe "Puppet::Util::Windows::TaskScheduler2", :if => Puppet.features.microsoft_windows? do
  let(:subject_taskname) { nil }
  let(:subject) { Puppet::Util::Windows::TaskScheduler2.new(subject_taskname) }
  
  describe '#enum_task_names' do
    before(:all) do
      # Need a V1 task as a test fixture
      @task_name = create_test_task(nil, Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V1)
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.new().delete(@task_name)
    end

    it 'should return all tasks by default' do
      subject_count = subject.enum_task_names.count
      ps_cmd = '(Get-ScheduledTask | Measure-Object).count'
      expect(subject_count).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should not recurse folders if specified' do
      subject_count = subject.enum_task_names(Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER, { :include_child_folders => false}).count
      ps_cmd = '(Get-ScheduledTask | ? { $_.TaskPath -eq \'\\\' } | Measure-Object).count'
      expect(subject_count).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should only return compatible tasks if specified' do
      subject_count = subject.enum_task_names(Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER, { :include_compatibility => [Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V1]}).count
      ps_cmd = '(Get-ScheduledTask | ? { [Int]$_.Settings.Compatibility -eq 1 } | Measure-Object).count'
      expect(subject_count).to be_same_as_powershell_command(ps_cmd)
    end
  end

  describe '#activate' do
    before(:all) do
      @task_name = create_test_task
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.new().delete(@task_name)
    end

    it 'should return nil for a task that does not exist' do
      expect(subject.activate('/this task will never exist')).to be_nil
    end

    it 'should activate a task that exists' do
      expect(subject.activate(@task_name)).to_not be_nil
    end
  end

  describe '#delete' do
    before(:all) do
      @task_name = task_name = Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER + 'puppet_task_' + SecureRandom.uuid.to_s
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.new().delete(@task_name)
    end

    it 'should delete a task that exists' do
      create_test_task(@task_name)

      ps_cmd = '(Get-ScheduledTask | ? { $_.URI -eq \'' + @task_name + '\' } | Measure-Object).count'
      expect(1).to be_same_as_powershell_command(ps_cmd)

      Puppet::Util::Windows::TaskScheduler2.new().delete(@task_name)
      expect(0).to be_same_as_powershell_command(ps_cmd)
    end
  end

  describe 'create a task' do
    before(:all) do
      @task_name = create_test_task
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.new().delete(@task_name)
    end

    context 'given a test task fixture' do
      it 'should be disabled' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.definition.Settings.Enabled).to eq(false)
      end

      it 'should be V2 compatible' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.compatibility).to eq(Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V2)
      end

      it 'should have a single trigger' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.trigger_count).to eq(1)
      end

      it 'should have a trigger of type TimeTrigger' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.trigger(1)['type']).to eq(Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_TIME)
      end

      it 'should have a single action' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.action_count).to eq(1)
      end

      it 'should have an action of type Execution' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.action(1).Type).to eq(Puppet::Util::Windows::TaskScheduler2::TASK_ACTION_EXEC)
      end

      it 'should have the specified action path' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.action(1).Path).to eq('cmd.exe')
      end

      it 'should have the specified action arguments' do
        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect(subject.action(1).Arguments).to eq('/c exit 0')
      end
    end
  end

  describe 'modify a task' do
    before(:all) do
      @task_name = create_test_task
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.new().delete(@task_name)
    end

    context 'given a test task fixture' do
      it 'should change the action path' do
        ps_cmd = '(Get-ScheduledTask | ? { $_.URI -eq \'' + @task_name + '\' }).Actions[0].Execute'

        subject = Puppet::Util::Windows::TaskScheduler2.new(@task_name)
        expect('cmd.exe').to be_same_as_powershell_command(ps_cmd)

        subject.action(1).Path = 'notepad.exe'
        subject.save
        expect('notepad.exe').to be_same_as_powershell_command(ps_cmd)
      end
    end
  end

end
