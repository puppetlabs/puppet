#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/modules'
require 'puppet/module/task'

describe Puppet::Module::Task do
  include PuppetSpec::Files

  let(:modpath) { tmpdir('task_modpath') }
  let(:mymodpath) { File.join(modpath, 'mymod') }
  let(:othermodpath) { File.join(modpath, 'othermod') }
  let(:mymod) { Puppet::Module.new('mymod', mymodpath, nil) }
  let(:othermod) { Puppet::Module.new('othermod', othermodpath, nil) }
  let(:tasks_path) { File.join(mymodpath, 'tasks') }
  let(:other_tasks_path) { File.join(othermodpath, 'tasks') }
  let(:tasks_glob) { File.join(mymodpath, 'tasks', '*') }

  it "cannot construct tasks with illegal names" do
    expect { Puppet::Module::Task.new(mymod, "iLegal", []) }
      .to raise_error(Puppet::Module::Task::InvalidName,
                      "Task names must start with a lowercase letter and be composed of only lowercase letters, numbers, and underscores")
  end

  it "constructs tasks as expected when every task has a metadata file with the same name (besides extension)" do
    task_files = %w{task1.json task1 task2.json task2.exe task3.json task3.sh}.map { |bn| "#{tasks_path}/#{bn}" }
    Dir.expects(:glob).with(tasks_glob).returns(task_files)
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    Puppet::Module::Task.any_instance.stubs(:metadata).returns({})

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1 mymod::task2 mymod::task3})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json",
                                                  "#{tasks_path}/task2.json",
                                                  "#{tasks_path}/task3.json"])
    expect(tasks.map{|t| t.files.map { |f| f["path"] } }).to eq([["#{tasks_path}/task1"],
                                                                 ["#{tasks_path}/task2.exe"],
                                                                 ["#{tasks_path}/task3.sh"]])
    expect(tasks.map{|t| t.files.map { |f| f["name"] } }).to eq([["task1"],
                                                                 ["task2.exe"],
                                                                 ["task3.sh"]])

    tasks.map{|t| t.metadata_file}.each do |metadata_file|
      expect(metadata_file).to eq(File.absolute_path(metadata_file))
    end

    tasks.map{|t| t.files}.each do |file_data|
      path = file_data[0]['path']
      expect(path).to eq(File.absolute_path(path))
    end
  end

  it "constructs tasks as expected when some tasks don't have a metadata file" do
    task_files = %w{task1 task2.exe task3.json task3.sh}.map { |bn| "#{tasks_path}/#{bn}" }
    Dir.expects(:glob).with(tasks_glob).returns(task_files)
    Puppet::Module::Task.any_instance.stubs(:metadata).returns({})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1 mymod::task2 mymod::task3})
    expect(tasks.map{|t| t.metadata_file}).to eq([nil, nil, "#{tasks_path}/task3.json"])
    expect(tasks.map{|t| t.files.map { |f| f["path"] } }).to eq([["#{tasks_path}/task1"],
                                          ["#{tasks_path}/task2.exe"],
                                          ["#{tasks_path}/task3.sh"]])
  end

  it "constructs a task as expected when a task has implementations" do
    task_files = %w{task1.elf task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    Dir.expects(:glob).with(tasks_glob).returns(task_files)
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    Puppet::Module::Task.any_instance.stubs(:metadata).returns({'implementations' =>
    [{"name" => "task1.sh"}]})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json"])
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh"]])
  end

  it "constructs a task as expected when a task has files" do
    og_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    Dir.expects(:glob).with(tasks_glob).returns(og_files)

    Puppet::Module.expects(:find).with(othermod.name, "production").returns(othermod).at_least(1)
    short_files = %w{other_task.sh other_task.json task_2.sh}.map { |bn| "#{othermod.name}/tasks/#{bn}" }
    long_files = %w{other_task.sh other_task.json task_2.sh}.map { |bn| "#{other_tasks_path}/#{bn}" }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    Puppet::Module::Task.any_instance.stubs(:metadata).returns({'files' => short_files})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh"] + long_files])
  end

  it "constructs a task as expected when a task has directory in files key" do
    og_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    long_files = %w{other_task.sh other_task.json helpers/helper.sh}.map { |bn| "#{other_tasks_path}/#{bn}" }

    Dir.expects(:glob).with(tasks_glob).returns(og_files)
    Dir.expects(:glob).with("#{other_tasks_path}//**/*").returns(long_files)
    File.expects(:directory?).with("#{other_tasks_path}/").returns(true).at_least(1)
    File.expects(:file?).with(any_parameters).returns(true).at_least(1)

    Puppet::Module.expects(:find).with(othermod.name, "production").returns(othermod).at_least(1)
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    Puppet::Module::Task.any_instance.stubs(:metadata).returns({'files' => ["#{othermod.name}/tasks/"]})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh"] + long_files])
  end

  it "finds all required files for a task" do
    og_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    Dir.expects(:glob).with(tasks_glob).returns(og_files)

    Puppet::Module.expects(:find).with(mymod.name, "production").returns(mymod).at_least(1)
    Puppet::Module.expects(:find).with(othermod.name, "production").returns(othermod).at_least(1)
    short_files = %w{helper.rb lib.sh}.map { |bn| "#{othermod.name}/files/#{bn}" }
    long_files = %w{helper.rb lib.sh}.map { |bn| "#{othermodpath}/files/#{bn}" }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    Puppet::Module::Task.any_instance.stubs(:metadata).returns({'files' => short_files,
                                                                'implementations' => [{"name" => "task1.sh",
                                                                                       "files" => ["#{mymod.name}/files/myhelper.rb",
                                                                                                   "#{othermod.name}/files/helper.rb"]}]})
    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh"] + 
                                                                ["#{mymodpath}/files/myhelper.rb"] +
                                                                long_files])
  end

  it "finds files whose names (besides extensions) are valid task names" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{task task_1 xx_t_a_s_k_2_xx})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task mymod::task_1 mymod::xx_t_a_s_k_2_xx})
  end

  it "ignores files that have names (besides extensions) that are not valid task names" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{.nottask.exe .wat !runme _task 2task2furious def_a_task_PSYCH Fake_task not-a-task realtask})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::realtask})
  end

  it "ignores files that have names ending in .conf and .md" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{ginuwine_task task.conf readme.md other_task.md})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::ginuwine_task})
  end

  it "gives the 'init' task a name that is just the module's name" do
    expect(Puppet::Module::Task.new(mymod, 'init', ["#{tasks_path}/init.sh"]).name).to eq('mymod')
  end

  describe :metadata do
    it "loads metadata for a task" do
      metadata  = {'desciption': 'some info'}
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.exe task1.json})
      Puppet::Module::Task.any_instance.stubs(:read_metadata).returns(metadata)

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].metadata).to eq(metadata)
    end

    it 'returns nil for metadata if no file is present' do
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.exe})
      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].metadata).to be_nil
    end

    it 'raises InvalidMetadata if the json metadata is invalid' do
      FileUtils.mkdir_p(tasks_path)
      File.open(File.join(tasks_path, 'task.json'), 'w') { |f| f.write '{ "whoops"' }
      FileUtils.touch(File.join(tasks_path, 'task'))

      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      expect(tasks.count).to eq(1)

      expect {
        tasks[0].metadata
      }.to raise_error(Puppet::Module::Task::InvalidMetadata, /whoops/)
    end
  end

  describe :validate do
    it "validates when there is no metadata" do
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.exe})

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].validate).to eq(true)
    end

    it "validates when an implementation isn't used" do
      metadata  = {'desciption' => 'some info',
        'implementations' => [ {"name" => "task1.exe"}, ] }
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.exe task1.sh task1.json})
      Puppet::Module::Task.any_instance.stubs(:read_metadata).returns(metadata)

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].validate).to be(true)
    end

    it "validates when an implementation is another task" do
      metadata  = {'desciption' => 'some info',
                   'implementations' => [ {"name" => "task2.sh"}, ] }
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.exe task2.sh task1.json})
      Puppet::Module::Task.any_instance.stubs(:read_metadata).returns(metadata)

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(2)
      expect(tasks.map(&:validate)).to eq([true, true])
    end

    it "fails validation when there is no metadata and multiple task files" do
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.elf task1.exe task1.json task2.ps1 task2.sh})
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      Puppet::Module::Task.any_instance.stubs(:metadata).returns({})

      tasks.each do |task|
        expect {task.validate}.to raise_error(Puppet::Module::Task::InvalidTask)
      end
    end

    it "fails validation when an implementation references a non-existant file" do
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.elf task1.exe task1.json})
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      Puppet::Module::Task.any_instance.stubs(:metadata).returns({'implementations' => [ { 'name' => 'task1.sh' } ] })

      tasks.each do |task|
        expect {task.validate}.to raise_error(Puppet::Module::Task::InvalidTask)
      end
    end

    it 'fails validation when there is metadata but no executable' do
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.json task2.sh})
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      Puppet::Module::Task.any_instance.stubs(:metadata).returns({})

      expect { tasks.find { |t| t.name == 'mymod::task1' }.validate }.to raise_error(Puppet::Module::Task::InvalidTask)
    end

    it 'fails validation when the implementations are not an array' do
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.json task2.sh})
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      Puppet::Module::Task.any_instance.stubs(:metadata).returns({"implemenations" => {}})

      expect { tasks.find { |t| t.name == 'mymod::task1' }.validate }.to raise_error(Puppet::Module::Task::InvalidTask)
    end

    it 'fails validation when the implementation is json' do
      Dir.expects(:glob).with(tasks_glob).returns(%w{task1.json task1.sh})
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      Puppet::Module::Task.any_instance.stubs(:metadata).returns({'implementations' => [ { 'name' => 'task1.json' } ] })

      expect { tasks.find { |t| t.name == 'mymod::task1' }.validate }.to raise_error(Puppet::Module::Task::InvalidTask)
    end
  end
end
