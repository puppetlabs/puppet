require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/modules'
require 'puppet/module_tool/checksums'

describe Puppet::Module do
  include PuppetSpec::Files

  let(:env) { double("environment") }
  let(:path) { "/path" }
  let(:name) { "mymod" }
  let(:mod) { Puppet::Module.new(name, path, env) }

  before do
    # This is necessary because of the extra checks we have for the deprecated
    # 'plugins' directory
    allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
  end

  it "should have a class method that returns a named module from a given environment" do
    env = Puppet::Node::Environment.create(:myenv, [])
    expect(env).to receive(:module).with(name).and_return("yep")
    Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
      expect(Puppet::Module.find(name, "myenv")).to eq("yep")
    end
  end

  it "should return nil if asked for a named module that doesn't exist" do
    env = Puppet::Node::Environment.create(:myenv, [])
    expect(env).to receive(:module).with(name).and_return(nil)
    Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
      expect(Puppet::Module.find(name, "myenv")).to be_nil
    end
  end

  describe "is_module_directory?" do
    let(:first_modulepath) { tmpdir('firstmodules') }
    let(:not_a_module) { tmpfile('thereisnomodule', first_modulepath) }

    it "should return false for a non-directory" do
      expect(Puppet::Module.is_module_directory?('thereisnomodule', first_modulepath)).to be_falsey
    end

    it "should return true for a well named directories" do
      PuppetSpec::Modules.generate_files('foo', first_modulepath)
      PuppetSpec::Modules.generate_files('foo2', first_modulepath)
      PuppetSpec::Modules.generate_files('foo_bar', first_modulepath)
      expect(Puppet::Module.is_module_directory?('foo', first_modulepath)).to be_truthy
      expect(Puppet::Module.is_module_directory?('foo2', first_modulepath)).to be_truthy
      expect(Puppet::Module.is_module_directory?('foo_bar', first_modulepath)).to be_truthy
    end

    it "should return false for badly named directories" do
      PuppetSpec::Modules.generate_files('foo=bar', first_modulepath)
      PuppetSpec::Modules.generate_files('.foo', first_modulepath)
      expect(Puppet::Module.is_module_directory?('foo=bar', first_modulepath)).to be_falsey
      expect(Puppet::Module.is_module_directory?('.foo', first_modulepath)).to be_falsey
    end
  end

  describe "is_module_directory_name?" do
    it "should return true for a valid directory module name" do
      expect(Puppet::Module.is_module_directory_name?('foo')).to be_truthy
      expect(Puppet::Module.is_module_directory_name?('foo2')).to be_truthy
      expect(Puppet::Module.is_module_directory_name?('foo_bar')).to be_truthy
    end

    it "should return false for badly formed directory module names" do
      expect(Puppet::Module.is_module_directory_name?('foo-bar')).to be_falsey
      expect(Puppet::Module.is_module_directory_name?('foo=bar')).to be_falsey
      expect(Puppet::Module.is_module_directory_name?('foo bar')).to be_falsey
      expect(Puppet::Module.is_module_directory_name?('foo.bar')).to be_falsey
      expect(Puppet::Module.is_module_directory_name?('-foo')).to be_falsey
      expect(Puppet::Module.is_module_directory_name?('foo-')).to be_falsey
      expect(Puppet::Module.is_module_directory_name?('foo--bar')).to be_falsey
      expect(Puppet::Module.is_module_directory_name?('.foo')).to be_falsey
    end
  end

  describe "is_module_namespaced_name?" do
    it "should return true for a valid namespaced module name" do
      expect(Puppet::Module.is_module_namespaced_name?('foo-bar')).to be_truthy
    end

    it "should return false for badly formed namespaced module names" do
      expect(Puppet::Module.is_module_namespaced_name?('foo')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('.foo-bar')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('foo2')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('foo_bar')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('foo=bar')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('foo bar')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('foo.bar')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('-foo')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('foo-')).to be_falsey
      expect(Puppet::Module.is_module_namespaced_name?('foo--bar')).to be_falsey
    end
  end

  describe "attributes" do
    it "should support a 'version' attribute" do
      mod.version = 1.09
      expect(mod.version).to eq(1.09)
    end

    it "should support a 'source' attribute" do
      mod.source = "http://foo/bar"
      expect(mod.source).to eq("http://foo/bar")
    end

    it "should support a 'project_page' attribute" do
      mod.project_page = "http://foo/bar"
      expect(mod.project_page).to eq("http://foo/bar")
    end

    it "should support an 'author' attribute" do
      mod.author = "Luke Kanies <luke@madstop.com>"
      expect(mod.author).to eq("Luke Kanies <luke@madstop.com>")
    end

    it "should support a 'license' attribute" do
      mod.license = "GPL2"
      expect(mod.license).to eq("GPL2")
    end

    it "should support a 'summary' attribute" do
      mod.summary = "GPL2"
      expect(mod.summary).to eq("GPL2")
    end

    it "should support a 'description' attribute" do
      mod.description = "GPL2"
      expect(mod.description).to eq("GPL2")
    end
  end

  describe "when finding unmet dependencies" do
    before do
      allow(Puppet::FileSystem).to receive(:exist?).and_call_original
      @modpath = tmpdir('modpath')
      Puppet.settings[:modulepath] = @modpath
    end

    it "should resolve module dependencies using forge names" do
      parent = PuppetSpec::Modules.create(
        'parent',
        @modpath,
        :metadata => {
          :author => 'foo',
          :dependencies => [{
            "name" => "foo/child"
          }]
        },
        :environment => env
      )
      child = PuppetSpec::Modules.create(
        'child',
        @modpath,
        :metadata => {
          :author => 'foo',
          :dependencies => []
        },
        :environment => env
      )

      expect(env).to receive(:module_by_forge_name).with('foo/child').and_return(child)

      expect(parent.unmet_dependencies).to eq([])
    end

    it "should list modules that are missing" do
      mod = PuppetSpec::Modules.create(
        'needy',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )

      expect(env).to receive(:module_by_forge_name).with('baz/foobar').and_return(nil)

      expect(mod.unmet_dependencies).to eq([{
        :reason => :missing,
        :name   => "baz/foobar",
        :version_constraint => ">= 2.2.0",
        :parent => { :name => 'puppetlabs/needy', :version => 'v9.9.9' },
        :mod_details => { :installed_version => nil }
      }])
    end

    it "should list modules that are missing and have invalid names" do
      mod = PuppetSpec::Modules.create(
        'needy',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar=bar"
          }]
        },
        :environment => env
      )

      expect(env).to receive(:module_by_forge_name).with('baz/foobar=bar').and_return(nil)

      expect(mod.unmet_dependencies).to eq([{
        :reason => :missing,
        :name   => "baz/foobar=bar",
        :version_constraint => ">= 2.2.0",
        :parent => { :name => 'puppetlabs/needy', :version => 'v9.9.9' },
        :mod_details => { :installed_version => nil }
      }])
    end

    it "should list modules with unmet version requirement" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      ['test_gte_req', 'test_specific_req', 'foobar'].each do |mod_name|
        mod_dir = "#{@modpath}/#{mod_name}"
        metadata_file = "#{mod_dir}/metadata.json"
        allow(Puppet::FileSystem).to receive(:exist?).with(metadata_file).and_return(true)
      end
      mod = PuppetSpec::Modules.create(
        'test_gte_req',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )
      mod2 = PuppetSpec::Modules.create(
        'test_specific_req',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => "1.0.0",
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )

      PuppetSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => { :version => '2.0.0', :author  => 'baz' },
        :environment => env
      )

      expect(mod.unmet_dependencies).to eq([{
        :reason => :version_mismatch,
        :name   => "baz/foobar",
        :version_constraint => ">= 2.2.0",
        :parent => { :version => "v9.9.9", :name => "puppetlabs/test_gte_req" },
        :mod_details => { :installed_version => "2.0.0" }
      }])

      expect(mod2.unmet_dependencies).to eq([{
        :reason => :version_mismatch,
        :name   => "baz/foobar",
        :version_constraint => "v1.0.0",
        :parent => { :version => "v9.9.9", :name => "puppetlabs/test_specific_req" },
        :mod_details => { :installed_version => "2.0.0" }
      }])

    end

    it "should consider a dependency without a version requirement to be satisfied" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      mod = PuppetSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :dependencies => [{
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )
      PuppetSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :version => '2.0.0',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to be_empty
    end

    it "should consider a dependency without a semantic version to be unmet" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      mod = PuppetSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :dependencies => [{
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )
      PuppetSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :version => '5.1',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to eq([{
        :reason => :non_semantic_version,
        :parent => { :version => "v9.9.9", :name => "puppetlabs/foobar" },
        :mod_details => { :installed_version => "5.1" },
        :name => "baz/foobar",
        :version_constraint => ">= 0.0.0"
      }])
    end

    it "should have valid dependencies when no dependencies have been specified" do
      mod = PuppetSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :dependencies => []
        }
      )

      expect(mod.unmet_dependencies).to eq([])
    end

    it "should throw an error if invalid dependencies are specified" do
      expect {
        PuppetSpec::Modules.create(
          'foobar',
          @modpath,
          :metadata => {
            :dependencies => ""
          }
        )
      }.to raise_error(
        Puppet::Module::MissingMetadata,
        /dependencies in the file metadata.json of the module foobar must be an array, not: ''/)
    end

    it "should only list unmet dependencies" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      mod = PuppetSpec::Modules.create(
        name,
        @modpath,
        :metadata => {
          :dependencies => [
            {
              "version_requirement" => ">= 2.2.0",
              "name" => "baz/satisfied"
            },
            {
              "version_requirement" => ">= 2.2.0",
              "name" => "baz/notsatisfied"
            }
          ]
        },
        :environment => env
      )
      PuppetSpec::Modules.create(
        'satisfied',
        @modpath,
        :metadata => {
          :version => '3.3.0',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to eq([{
        :reason => :missing,
        :mod_details => { :installed_version => nil },
        :parent => { :version => "v9.9.9", :name => "puppetlabs/#{name}" },
        :name => "baz/notsatisfied",
        :version_constraint => ">= 2.2.0"
      }])
    end

    it "should be empty when all dependencies are met" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      mod = PuppetSpec::Modules.create(
        'mymod2',
        @modpath,
        :metadata => {
          :dependencies => [
            {
              "version_requirement" => ">= 2.2.0",
              "name" => "baz/satisfied"
            },
            {
              "version_requirement" => "< 2.2.0",
              "name" => "baz/alsosatisfied"
            }
          ]
        },
        :environment => env
      )
      PuppetSpec::Modules.create(
        'satisfied',
        @modpath,
        :metadata => {
          :version => '3.3.0',
          :author  => 'baz'
        },
        :environment => env
      )
      PuppetSpec::Modules.create(
        'alsosatisfied',
        @modpath,
        :metadata => {
          :version => '2.1.0',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to be_empty
    end
  end

  describe "when managing supported platforms" do
    it "should support specifying a supported platform" do
      mod.supports "solaris"
    end

    it "should support specifying a supported platform and version" do
      mod.supports "solaris", 1.0
    end
  end

  it "should return nil if asked for a module whose name is 'nil'" do
    expect(Puppet::Module.find(nil, "myenv")).to be_nil
  end

  it "should provide support for logging" do
    expect(Puppet::Module.ancestors).to be_include(Puppet::Util::Logging)
  end

  it "should be able to be converted to a string" do
    expect(mod.to_s).to eq("Module #{name}(#{path})")
  end

  it "should fail if its name is not alphanumeric" do
    expect { Puppet::Module.new(".something", "/path", env) }.to raise_error(Puppet::Module::InvalidName)
  end

  it "should require a name at initialization" do
    expect { Puppet::Module.new }.to raise_error(ArgumentError)
  end

  it "should accept an environment at initialization" do
    expect(Puppet::Module.new("foo", "/path", env).environment).to eq(env)
  end

  describe '#modulepath' do
    it "should return the directory the module is installed in, if a path exists" do
      mod = Puppet::Module.new("foo", "/a/foo", env)
      expect(mod.modulepath).to eq('/a')
    end
  end

  [:plugins, :pluginfacts, :templates, :files, :manifests].each do |filetype|
    case filetype
      when :plugins
        dirname = "lib"
      when :pluginfacts
        dirname = "facts.d"
      else
        dirname = filetype.to_s
    end

    it "should be able to return individual #{filetype}" do
      module_file = File.join(path, dirname, "my/file")
      expect(Puppet::FileSystem).to receive(:exist?).with(module_file).and_return(true)
      expect(mod.send(filetype.to_s.sub(/s$/, ''), "my/file")).to eq(module_file)
    end

    it "should consider #{filetype} to be present if their base directory exists" do
      module_file = File.join(path, dirname)
      expect(Puppet::FileSystem).to receive(:exist?).with(module_file).and_return(true)
      expect(mod.send(filetype.to_s + "?")).to be_truthy
    end

    it "should consider #{filetype} to be absent if their base directory does not exist" do
      module_file = File.join(path, dirname)
      expect(Puppet::FileSystem).to receive(:exist?).with(module_file).and_return(false)
      expect(mod.send(filetype.to_s + "?")).to be_falsey
    end

    it "should return nil if asked to return individual #{filetype} that don't exist" do
      module_file = File.join(path, dirname, "my/file")
      expect(Puppet::FileSystem).to receive(:exist?).with(module_file).and_return(false)
      expect(mod.send(filetype.to_s.sub(/s$/, ''), "my/file")).to be_nil
    end

    it "should return the base directory if asked for a nil path" do
      base = File.join(path, dirname)
      expect(Puppet::FileSystem).to receive(:exist?).with(base).and_return(true)
      expect(mod.send(filetype.to_s.sub(/s$/, ''), nil)).to eq(base)
    end
  end

  it "should return the path to the plugin directory" do
    expect(mod.plugin_directory).to eq(File.join(path, "lib"))
  end

  it "should return the path to the tasks directory" do
    expect(mod.tasks_directory).to eq(File.join(path, "tasks"))
  end

  it "should return the path to the plans directory" do
    expect(mod.plans_directory).to eq(File.join(path, "plans"))
  end

  describe "when finding tasks" do
    before do
      allow(Puppet::FileSystem).to receive(:exist?).and_call_original
      @modpath = tmpdir('modpath')
      Puppet.settings[:modulepath] = @modpath
    end

    it "should have an empty array for the tasks when the tasks directory does not exist" do
      mod = PuppetSpec::Modules.create('tasks_test_nodir', @modpath, :environment => env)
      expect(mod.tasks).to eq([])
    end

    it "should have an empty array for the tasks when the tasks directory does exist and is empty" do
      mod = PuppetSpec::Modules.create('tasks_test_empty', @modpath, {:environment => env,
                                                                      :tasks => []})
      expect(mod.tasks).to eq([])
    end

    it "should list the expected tasks when the required files exist" do
      fake_tasks = [['task1'], ['task2.sh', 'task2.json']]
      mod = PuppetSpec::Modules.create('tasks_smoke', @modpath, {:environment => env,
                                                                 :tasks => fake_tasks})

      expect(mod.tasks.count).to eq(2)
      expect(mod.tasks.map{|t| t.name}.sort).to eq(['tasks_smoke::task1', 'tasks_smoke::task2'])
      expect(mod.tasks.map{|t| t.class}).to eq([Puppet::Module::Task] * 2)
    end

    it "should be able to find individual task files when they exist" do
      task_exe = 'stateskatetask.stk'
      mod = PuppetSpec::Modules.create('task_file_smoke', @modpath, {:environment => env,
                                                                     :tasks => [[task_exe]]})

      expect(mod.task_file(task_exe)).to eq("#{mod.path}/tasks/#{task_exe}")
    end

    it "should return nil when asked for an individual task file if it does not exist" do
      mod = PuppetSpec::Modules.create('task_file_neg', @modpath, {:environment => env,
                                                                   :tasks => []})
      expect(mod.task_file('nosuchtask')).to be_nil
    end

    describe "does the task finding" do
      let(:mod_name) { 'tasks_test_lazy' }
      let(:mod_tasks_dir) { File.join(@modpath, mod_name, 'tasks') }

      it "after the module is initialized" do
        expect(Puppet::FileSystem).not_to receive(:exist?).with(mod_tasks_dir)
        expect(Puppet::Module::Task).not_to receive(:tasks_in_module)
        Puppet::Module.new(mod_name, @modpath, env)
      end

      it "when the tasks method is called" do
        expect(Puppet::Module::Task).to receive(:tasks_in_module)
        mod = PuppetSpec::Modules.create(mod_name, @modpath, {:environment => env,
                                                              :tasks => [['itascanstaccatotask']]})
        mod.tasks
      end

      it "only once for the lifetime of the module object" do
        expect(Dir).to receive(:glob).with("#{mod_tasks_dir}/*").once.and_return(['allalaskataskattacktactics'])
        mod = PuppetSpec::Modules.create(mod_name, @modpath, {:environment => env,
                                                              :tasks => []})
        mod.tasks
        mod.tasks
      end
    end
  end

  describe "when finding plans" do
    before do
      allow(Puppet::FileSystem).to receive(:exist?).and_call_original
      @modpath = tmpdir('modpath')
      Puppet.settings[:modulepath] = @modpath
    end

    it "should have an empty array for the plans when the plans directory does not exist" do
      mod = PuppetSpec::Modules.create('plans_test_nodir', @modpath, :environment => env)
      expect(mod.plans).to eq([])
    end

    it "should have an empty array for the plans when the plans directory does exist and is empty" do
      mod = PuppetSpec::Modules.create('plans_test_empty', @modpath, {:environment => env,
                                                                      :plans => []})
      expect(mod.plans).to eq([])
    end

    it "should list the expected plans when the required files exist" do
      fake_plans = ['plan1.pp', 'plan2.yaml']
      mod = PuppetSpec::Modules.create('plans_smoke', @modpath, {:environment => env,
                                                                 :plans => fake_plans})

      expect(mod.plans.count).to eq(2)
      expect(mod.plans.map{|t| t.name}.sort).to eq(['plans_smoke::plan1', 'plans_smoke::plan2'])
      expect(mod.plans.map{|t| t.class}).to eq([Puppet::Module::Plan] * 2)
    end

    it "should be able to find individual plan files when they exist" do
      plan_exe = 'stateskateplan.pp'
      mod = PuppetSpec::Modules.create('plan_file_smoke', @modpath, {:environment => env,
                                                                     :plans => [plan_exe]})

      expect(mod.plan_file(plan_exe)).to eq("#{mod.path}/plans/#{plan_exe}")
    end

    it "should return nil when asked for an individual plan file if it does not exist" do
      mod = PuppetSpec::Modules.create('plan_file_neg', @modpath, {:environment => env,
                                                                   :plans => []})
      expect(mod.plan_file('nosuchplan')).to be_nil
    end

    describe "does the plan finding" do
      let(:mod_name) { 'plans_test_lazy' }
      let(:mod_plans_dir) { File.join(@modpath, mod_name, 'plans') }

      it "after the module is initialized" do
        expect(Puppet::FileSystem).not_to receive(:exist?).with(mod_plans_dir)
        expect(Puppet::Module::Plan).not_to receive(:plans_in_module)
        Puppet::Module.new(mod_name, @modpath, env)
      end

      it "when the plans method is called" do
        expect(Puppet::Module::Plan).to receive(:plans_in_module)
        mod = PuppetSpec::Modules.create(mod_name, @modpath, {:environment => env,
                                                              :plans => ['itascanstaccatoplan.yaml']})
        mod.plans
      end

      it "only once for the lifetime of the module object" do
        expect(Dir).to receive(:glob).with("#{mod_plans_dir}/*").once.and_return(['allalaskaplanattacktactics'])
        mod = PuppetSpec::Modules.create(mod_name, @modpath, {:environment => env,
                                                              :plans => []})
        mod.plans
        mod.plans
      end
    end
  end
end

describe Puppet::Module, "when finding matching manifests" do
  before do
    @mod = Puppet::Module.new("mymod", "/a", double("environment"))
    @pq_glob_with_extension = "yay/*.xx"
    @fq_glob_with_extension = "/a/manifests/#{@pq_glob_with_extension}"
  end

  it "should return all manifests matching the glob pattern" do
    expect(Dir).to receive(:glob).with(@fq_glob_with_extension).and_return(%w{foo bar})
    allow(FileTest).to receive(:directory?).and_return(false)

    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq(%w{foo bar})
  end

  it "should not return directories" do
    expect(Dir).to receive(:glob).with(@fq_glob_with_extension).and_return(%w{foo bar})

    expect(FileTest).to receive(:directory?).with("foo").and_return(false)
    expect(FileTest).to receive(:directory?).with("bar").and_return(true)
    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq(%w{foo})
  end

  it "should default to the 'init' file if no glob pattern is specified" do
    expect(Puppet::FileSystem).to receive(:exist?).with("/a/manifests/init.pp").and_return(true)

    expect(@mod.match_manifests(nil)).to eq(%w{/a/manifests/init.pp})
  end

  it "should return all manifests matching the glob pattern in all existing paths" do
    expect(Dir).to receive(:glob).with(@fq_glob_with_extension).and_return(%w{a b})

    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq(%w{a b})
  end

  it "should match the glob pattern plus '.pp' if no extension is specified" do
    expect(Dir).to receive(:glob).with("/a/manifests/yay/foo.pp").and_return(%w{yay})

    expect(@mod.match_manifests("yay/foo")).to eq(%w{yay})
  end

  it "should return an empty array if no manifests matched" do
    expect(Dir).to receive(:glob).with(@fq_glob_with_extension).and_return([])

    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq([])
  end

  it "should raise an error if the pattern tries to leave the manifest directory" do
    expect do
      @mod.match_manifests("something/../../*")
    end.to raise_error(Puppet::Module::InvalidFilePattern, 'The pattern "something/../../*" to find manifests in the module "mymod" is invalid and potentially unsafe.')
  end
end

describe Puppet::Module do
  include PuppetSpec::Files

  let!(:modpath) do
    path = tmpdir('modpath')
    PuppetSpec::Modules.create('mymod', path)
    path
  end

  let!(:mymodpath) { File.join(modpath, 'mymod') }

  let!(:mymod_metadata) { File.join(mymodpath, 'metadata.json') }

  let(:mymod) { Puppet::Module.new('mymod', mymodpath, nil) }

  it "should use 'License' in its current path as its metadata file" do
    expect(mymod.license_file).to eq("#{modpath}/mymod/License")
  end

  it "should cache the license file" do
    expect(mymod).to receive(:path).once.and_return(nil)
    mymod.license_file
    mymod.license_file
  end

  it "should use 'metadata.json' in its current path as its metadata file" do
    expect(mymod_metadata).to eq("#{modpath}/mymod/metadata.json")
  end

  it "should not have metadata if it has a metadata file and its data is valid but empty json hash" do
    allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return("{}")

    expect(mymod).not_to be_has_metadata
  end

  it "should not have metadata if it has a metadata file and its data is empty" do
    allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return("")

    expect(mymod).not_to be_has_metadata
  end

  it "should not have metadata if has a metadata file and its data is invalid" do
    allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return("This is some invalid json.\n")
    expect(mymod).not_to be_has_metadata
  end

  it "should know if it is missing a metadata file" do
    allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_raise(Errno::ENOENT)

    expect(mymod).not_to be_has_metadata
  end

  it "should be able to parse its metadata file" do
    expect(mymod).to respond_to(:load_metadata)
  end

  it "should parse its metadata file on initialization if it is present" do
    expect_any_instance_of(Puppet::Module).to receive(:load_metadata)

    Puppet::Module.new("yay", "/path", double("env"))
  end

  it "should tolerate failure to parse" do
    allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return(my_fixture('trailing-comma.json'))

    expect(mymod.has_metadata?).to be_falsey
  end

  describe 'when --strict is warning' do
    before :each do
      Puppet.push_context({strict: :warning})
    end

    it "should warn about a failure to parse" do
      allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return(my_fixture('trailing-comma.json'))

      expect(mymod.has_metadata?).to be_falsey
      expect(@logs).to have_matching_log(/mymod has an invalid and unparsable metadata\.json file/)
    end
  end

    describe 'when --strict is off' do
      before :each do
        Puppet.push_context({strict: :off})
      end

      it "should not warn about a failure to parse" do
        allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return(my_fixture('trailing-comma.json'))

        expect(mymod.has_metadata?).to be_falsey
        expect(@logs).to_not have_matching_log(/mymod has an invalid and unparsable metadata\.json file.*/)
      end

      it "should log debug output about a failure to parse when --debug is on" do
        Puppet[:log_level] = :debug
        allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return(my_fixture('trailing-comma.json'))

        expect(mymod.has_metadata?).to be_falsey
        expect(@logs).to have_matching_log(/mymod has an invalid and unparsable metadata\.json file.*/)
      end
    end

    describe 'when --strict is error' do
      before :each do
        Puppet.push_context({strict: :error})
      end

      it "should fail on a failure to parse" do
        allow(File).to receive(:read).with(mymod_metadata, {:encoding => 'utf-8'}).and_return(my_fixture('trailing-comma.json'))

        expect do
        expect(mymod.has_metadata?).to be_falsey
        end.to raise_error(/mymod has an invalid and unparsable metadata\.json file/)
      end
    end

  def a_module_with_metadata(data)
    allow(File).to receive(:read).with("/path/metadata.json", {:encoding => 'utf-8'}).and_return(data.to_json)
    Puppet::Module.new("foo", "/path", double("env"))
  end

  describe "when loading the metadata file" do
    let(:data) do
      {
        :license       => "GPL2",
        :author        => "luke",
        :version       => "1.0",
        :source        => "http://foo/",
        :dependencies  => []
      }
    end

    %w{source author version license}.each do |attr|
      it "should set #{attr} if present in the metadata file" do
        mod = a_module_with_metadata(data)
        expect(mod.send(attr)).to eq(data[attr.to_sym])
      end

      it "should fail if #{attr} is not present in the metadata file" do
        data.delete(attr.to_sym)
        expect { a_module_with_metadata(data) }.to raise_error(
          Puppet::Module::MissingMetadata,
          "No #{attr} module metadata provided for foo"
        )
      end
    end
  end

  describe "when loading the metadata file from disk" do
    it "should properly parse utf-8 contents" do
      rune_utf8 = "\u16A0\u16C7\u16BB" # ᚠᛇᚻ
      metadata_json = tmpfile('metadata.json')
      File.open(metadata_json, 'w:UTF-8') do |file|
        file.puts <<-EOF
  {
    "license" : "GPL2",
    "author" : "#{rune_utf8}",
    "version" : "1.0",
    "source" : "http://foo/",
    "dependencies" : []
  }
        EOF
      end

      allow_any_instance_of(Puppet::Module).to receive(:metadata_file).and_return(metadata_json)
      mod = Puppet::Module.new('foo', '/path', double('env'))

      mod.load_metadata
      expect(mod.author).to eq(rune_utf8)
    end
  end

  it "should be able to tell if there are local changes" do
    modpath = tmpdir('modpath')
    foo_checksum = 'acbd18db4cc2f85cedef654fccc4a4d8'
    checksummed_module = PuppetSpec::Modules.create(
      'changed',
      modpath,
      :metadata => {
        :checksums => {
          "foo" => foo_checksum,
        }
      }
    )

    foo_path = Pathname.new(File.join(checksummed_module.path, 'foo'))

    IO.binwrite(foo_path, 'notfoo')
    expect(Puppet::ModuleTool::Checksums.new(foo_path).checksum(foo_path)).not_to eq(foo_checksum)

    IO.binwrite(foo_path, 'foo')
    expect(Puppet::ModuleTool::Checksums.new(foo_path).checksum(foo_path)).to eq(foo_checksum)
  end

  it "should know what other modules require it" do
    env = Puppet::Node::Environment.create(:testing, [modpath])

    dependable = PuppetSpec::Modules.create(
      'dependable',
      modpath,
      :metadata => {:author => 'puppetlabs'},
      :environment => env
    )
    PuppetSpec::Modules.create(
      'needy',
      modpath,
      :metadata => {
        :author => 'beggar',
        :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "puppetlabs/dependable"
        }]
      },
      :environment => env
    )
    PuppetSpec::Modules.create(
      'wantit',
      modpath,
      :metadata => {
        :author => 'spoiled',
        :dependencies => [{
            "version_requirement" => "< 5.0.0",
            "name" => "puppetlabs/dependable"
        }]
      },
      :environment => env
    )
    expect(dependable.required_by).to match_array([
      {
        "name"    => "beggar/needy",
        "version" => "9.9.9",
        "version_requirement" => ">= 2.2.0"
      },
      {
        "name"    => "spoiled/wantit",
        "version" => "9.9.9",
        "version_requirement" => "< 5.0.0"
      }
    ])
  end

  context 'when parsing VersionRange' do
    let(:logs) { [] }
    let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }

    it 'can parse a strict range' do
      expect(Puppet::Module.parse_range('>=1.0.0').include?(SemanticPuppet::Version.parse('1.0.1-rc1'))).to be_falsey
    end
  end
end
