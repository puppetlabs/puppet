#!/usr/bin/env ruby
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
  tasksched = Puppet::Util::Windows::TaskScheduler2
  task_name = tasksched::ROOT_FOLDER + 'puppet_task_' + SecureRandom.uuid.to_s if task_name.nil?
  definition = tasksched.definition()
  # Set task settings
  tasksched.set_compatibility(definition, task_compatiblity)
  tasksched.set_principal(definition, '',nil)
  definition.Settings.Enabled = false
  # Create a trigger
  trigger = tasksched.append_new_trigger(definition, tasksched::TASK_TRIGGER_TIME)
  trigger.StartBoundary = '2017-09-11T14:02:00'
  # Create an action
  new_action = tasksched.create_action(definition, tasksched::TASK_ACTION_EXEC)
  new_action.Path = 'cmd.exe'
  new_action.Arguments = '/c exit 0'
  tasksched.save(task_name, definition)

  task_name
end

describe "Puppet::Util::Windows::TaskScheduler2", :if => Puppet.features.microsoft_windows? do
  let(:subject_taskname) { nil }
  let(:subject) { Puppet::Util::Windows::TaskScheduler2 }
  
  describe '#enum_task_names' do
    before(:all) do
      # Need a V1 task as a test fixture
      @task_name = create_test_task(nil, Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V1)
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.delete(@task_name)
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

  describe '#delete' do
    before(:all) do
      @task_name = Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER + 'puppet_task_' + SecureRandom.uuid.to_s
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.delete(@task_name)
    end

    it 'should delete a task that exists' do
      create_test_task(@task_name)

      ps_cmd = '(Get-ScheduledTask | ? { $_.URI -eq \'' + @task_name + '\' } | Measure-Object).count'
      expect(1).to be_same_as_powershell_command(ps_cmd)

      subject.delete(@task_name)
      expect(0).to be_same_as_powershell_command(ps_cmd)
    end
  end

  describe 'create a task' do
    before(:all) do
      @task_name = create_test_task
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.delete(@task_name)
    end

    let(:task_object) { subject.task(@task_name) }
    let(:task_definition) { subject.definition(task_object) }

    context 'given a test task fixture' do
      it 'should be disabled' do
        expect(task_definition.Settings.Enabled).to eq(false)
      end

      it 'should be V2 compatible' do
        expect(subject.compatibility(task_definition)).to eq(Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V2)
      end

      it 'should have a single trigger' do
        expect(subject.trigger_count(task_definition)).to eq(1)
      end

      it 'should have a trigger of type TimeTrigger' do
        expect(subject.trigger(task_definition, 1).Type).to eq(Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_TIME)
      end

      it 'should have a single action' do
        expect(subject.action_count(task_definition)).to eq(1)
      end

      it 'should have an action of type Execution' do
        expect(subject.action(task_definition, 1).Type).to eq(Puppet::Util::Windows::TaskScheduler2::TASK_ACTION_EXEC)
      end

      it 'should have the specified action path' do
        expect(subject.action(task_definition, 1).Path).to eq('cmd.exe')
      end

      it 'should have the specified action arguments' do
        expect(subject.action(task_definition, 1).Arguments).to eq('/c exit 0')
      end
    end
  end

  describe 'modify a task' do
    before(:all) do
      @task_name = create_test_task
    end

    after(:all) do
      Puppet::Util::Windows::TaskScheduler2.delete(@task_name)
    end

    context 'given a test task fixture' do
      it 'should change the action path' do
        ps_cmd = '(Get-ScheduledTask | ? { $_.URI -eq \'' + @task_name + '\' }).Actions[0].Execute'

        task_object = subject.task(@task_name)
        task_definition = subject.definition(task_object)
        expect('cmd.exe').to be_same_as_powershell_command(ps_cmd)

        subject.action(task_definition, 1).Path = 'notepad.exe'
        subject.save(task_object, task_definition)
        expect('notepad.exe').to be_same_as_powershell_command(ps_cmd)
      end
    end
  end
end
