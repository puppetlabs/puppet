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
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(task_files)
    task_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({})

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
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(task_files)
    task_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({})
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
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(task_files)
    task_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'implementations' => [{"name" => "task1.sh"}]})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json"])
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh"]])
  end

  it "constructs a task as expected when task metadata declares additional files" do
    task_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(task_files)
    task_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    expect(Puppet::Module::Task).to receive(:find_extra_files).and_return([{'name' => 'mymod/lib/file0.elf', 'path' => "/path/to/file0.elf"}])
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'files' => ["mymod/lib/file0.elf"]})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json"])
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh", "/path/to/file0.elf"]])
  end

  it "constructs a task as expected when a task implementation declares additional files" do
    task_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(task_files)
    task_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    expect(Puppet::Module::Task).to receive(:find_extra_files).and_return([{'name' => 'mymod/lib/file0.elf', 'path' => "/path/to/file0.elf"}])
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'implementations' => [{"name" => "task1.sh", "files" => ["mymod/lib/file0.elf"]}]})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json"])
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh", "/path/to/file0.elf"]])
  end

  it "constructs a task as expected when task metadata and a task implementation both declare additional files" do
    task_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(task_files)
    task_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    expect(Puppet::Module::Task).to receive(:find_extra_files).and_return([
      {'name' => 'mymod/lib/file0.elf', 'path' => "/path/to/file0.elf"},
      {'name' => 'yourmod/files/file1.txt', 'path' => "/other/path/to/file1.txt"}
    ])
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'implementations' => [{"name" => "task1.sh", "files" => ["mymod/lib/file0.elf"]}]})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json"])
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([[
      "#{tasks_path}/task1.sh",
      "/path/to/file0.elf",
      "/other/path/to/file1.txt"
    ]])
  end

  it "constructs a task as expected when a task has files" do
    og_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
    og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    expect(File).to receive(:exist?).with(any_args).and_return(true).at_least(:once)

    expect(Puppet::Module).to receive(:find).with(othermod.name, "production").and_return(othermod).at_least(:once)
    short_files = %w{other_task.sh other_task.json task_2.sh}.map { |bn| "#{othermod.name}/tasks/#{bn}" }
    long_files = %w{other_task.sh other_task.json task_2.sh}.map { |bn| "#{other_tasks_path}/#{bn}" }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'files' => short_files})

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.files.map{ |f| f["path"] } }).to eq([["#{tasks_path}/task1.sh"] + long_files])
  end

  it "fails to load a task if its metadata specifies a non-existent file" do
    og_files = %w{task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
    allow(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
    og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    allow(File).to receive(:exist?).with(any_args).and_return(true)

    expect(Puppet::Module).to receive(:find).with(othermod.name, "production").and_return(nil).at_least(:once)
    tasks = Puppet::Module::Task.tasks_in_module(mymod)
    allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'files' => ["#{othermod.name}/files/test"]})

    expect { tasks.first.files }.to raise_error(Puppet::Module::Task::InvalidMetadata, /Could not find module #{othermod.name} containing task file test/)
  end

  it "finds files whose names (besides extensions) are valid task names" do
    og_files = %w{task task_1 xx_t_a_s_k_2_xx}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
    og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task mymod::task_1 mymod::xx_t_a_s_k_2_xx})
  end

  it "ignores files that have names (besides extensions) that are not valid task names" do
    og_files = %w{.nottask.exe .wat !runme _task 2task2furious def_a_task_PSYCH Fake_task not-a-task realtask}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
    og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::realtask})
  end

  it "ignores files that have names ending in .conf and .md" do
    og_files = %w{ginuwine_task task.conf readme.md other_task.md}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
    og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::ginuwine_task})
  end

  it "ignores files which are not regular files" do
    og_files = %w{foo}.map { |bn| "#{tasks_path}/#{bn}" }
    expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
    og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(false) }
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(0)
  end

  it "gives the 'init' task a name that is just the module's name" do
    expect(Puppet::Module::Task.new(mymod, 'init', ["#{tasks_path}/init.sh"]).name).to eq('mymod')
  end

  describe :metadata do
    it "loads metadata for a task" do
      metadata  = {'desciption': 'some info'}
      og_files = %w{task1.exe task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      allow(Puppet::Module::Task).to receive(:read_metadata).and_return(metadata)

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].metadata).to eq(metadata)
    end

    it 'returns nil for metadata if no file is present' do
      og_files = %w{task1.exe}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
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

    it 'returns empty hash for metadata when json metadata file is empty' do
      FileUtils.mkdir_p(tasks_path)
      FileUtils.touch(File.join(tasks_path, 'task.json'))
      FileUtils.touch(File.join(tasks_path, 'task'))

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].metadata).to eq({})
    end
  end

  describe :validate do
    it "validates when there is no metadata" do
      og_files = %w{task1.exe}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].validate).to eq(true)
    end

    it "validates when an implementation isn't used" do
      metadata  = {'desciption' => 'some info',
        'implementations' => [ {"name" => "task1.exe"}, ] }
      og_files = %w{task1.exe task1.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      allow(Puppet::Module::Task).to receive(:read_metadata).and_return(metadata)

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(1)
      expect(tasks[0].validate).to be(true)
    end

    it "validates when an implementation is another task" do
      metadata  = {'desciption' => 'some info',
                   'implementations' => [ {"name" => "task2.sh"}, ] }
      og_files = %w{task1.exe task2.sh task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      allow(Puppet::Module::Task).to receive(:read_metadata).and_return(metadata)

      tasks = Puppet::Module::Task.tasks_in_module(mymod)

      expect(tasks.count).to eq(2)
      expect(tasks.map(&:validate)).to eq([true, true])
    end

    it "fails validation when there is no metadata and multiple task files" do
      og_files = %w{task1.elf task1.exe task1.json task2.ps1 task2.sh}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({})

      tasks.each do |task|
        expect {task.validate}.to raise_error(Puppet::Module::Task::InvalidTask)
      end
    end

    it "fails validation when an implementation references a non-existant file" do
      og_files = %w{task1.elf task1.exe task1.json}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'implementations' => [ { 'name' => 'task1.sh' } ] })

      tasks.each do |task|
        expect {task.validate}.to raise_error(Puppet::Module::Task::InvalidTask)
      end
    end

    it 'fails validation when there is metadata but no executable' do
      og_files = %w{task1.json task2.sh}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({})

      expect { tasks.find { |t| t.name == 'mymod::task1' }.validate }.to raise_error(Puppet::Module::Task::InvalidTask)
    end

    it 'fails validation when the implementations are not an array' do
      og_files = %w{task1.json task2.sh}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({"implemenations" => {}})

      expect { tasks.find { |t| t.name == 'mymod::task1' }.validate }.to raise_error(Puppet::Module::Task::InvalidTask)
    end

    it 'fails validation when the implementation is json' do
      og_files = %w{task1.json task1.sh}.map { |bn| "#{tasks_path}/#{bn}" }
      expect(Dir).to receive(:glob).with(tasks_glob).and_return(og_files)
      og_files.each { |f| expect(File).to receive(:file?).with(f).and_return(true) }
      tasks = Puppet::Module::Task.tasks_in_module(mymod)
      allow_any_instance_of(Puppet::Module::Task).to receive(:metadata).and_return({'implementations' => [ { 'name' => 'task1.json' } ] })

      expect { tasks.find { |t| t.name == 'mymod::task1' }.validate }.to raise_error(Puppet::Module::Task::InvalidTask)
    end
  end
end
