require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'
require 'semver'

describe Puppet::ModuleTool::Shared do
  include PuppetSpec::Files

  let(:modpath)    { File.join(tmpdir('test_shared'), 'modpath') }
  let(:stdlib_pkg) { File.join(modpath, 'pmtacceptance-stdlib-0.0.1.tar.gz') }
  let(:fake_env)   { Puppet::Node::Environment.new('fake_env') }

  let(:forge) {
    forge = mock('Puppet::Forge')

    forge.stubs(:multiple_remote_dependency_info).returns(remote_dependency_info)
    forge.stubs(:uri).returns('forge-dev.puppetlabs.com')
    remote_dependency_info.each_key do |mod|
      remote_dependency_info[mod].each do |release|
        forge.stubs(:retrieve).with(release['file']).returns("/fake_cache#{release['file']}")
      end
    end

    forge
  }

  let(:test_shared) {
    # we need a class to include the shared module in to be able to call
    # the instance methods the module defines
    test_shared = Class.new() do
      include Puppet::ModuleTool::Shared

      # provide access to important fields
      attr_reader :installed, :conditions, :available
    end.new()

    # initialize some widely used fields
    test_shared.instance_exec(fake_env, forge) do |environment, forge|
      @environment = environment
      @forge = forge
      @action = :install
      @force = false
    end

    test_shared.stubs(:options).returns({
      :target_dir => modpath,
    })

    test_shared
  }

  let(:remote_dependency_info) do
    {
      'pmtacceptance/stdlib' => [
        {
          'version'      => '1.0.0',
          'file'         => '/pmtacceptance-stdlib-1.0.0.tar.gz',
          'dependencies' => [],
        },
        {
          'version'      => '0.0.2',
          'file'         => '/pmtacceptance-stdlib-0.0.2.tar.gz',
          'dependencies' => [],
        },
        {
          'version'      => '0.0.1',
          'file'         => '/pmtacceptance-stdlib-0.0.1.tar.gz',
          'dependencies' => [],
        },
      ],
      'pmtacceptance/java' => [
        {
          'version'      => '1.7.1',
          'file'         => '/pmtacceptance-java-1.7.1.tar.gz',
          'dependencies' => [
            ['pmtacceptance/stdlib', '>= 0.5.0'],
          ],
        },
        {
          'version'      => '1.7.0',
          'file'         => '/pmtacceptance-java-1.7.0.tar.gz',
          'dependencies' => [
            ['pmtacceptance/stdlib', '>= 0.0.1'],
          ],
        },
      ],
      'pmtacceptance/apollo' => [
        {
          'version' => '0.0.3',
          'file'    => '/pmtacceptance-apollo-0.0.3.tar.gz',
          'dependencies' => [
            ['pmtacceptance/java', '>= 1.8.0'],
            ['pmtacceptance/stdlib', '>= 1.0.0'],
          ],
        },
        {
          'version' => '0.0.2',
          'file'    => '/pmtacceptance-apollo-0.0.2.tar.gz',
          'dependencies' => [
            ['pmtacceptance/java', '1.7.1'],
            ['pmtacceptance/stdlib', '>= 0.5.0'],
          ],
        },
        {
          'version' => '0.0.1',
          'file'    => '/pmtacceptance-apollo-0.0.1.tar.gz',
          'dependencies' => [
            ['pmtacceptance/java', '1.7.1'],
            ['pmtacceptance/stdlib', '>= 0.0.1'],
          ],
        },
      ]
    }
  end

  before do
    FileUtils.mkdir_p(modpath)
    fake_env.modulepath = [modpath]
    FileUtils.touch(stdlib_pkg)
    Puppet.settings[:modulepath] = modpath
  end


  describe 'the behavior of .read_module_package_metadata' do
    let (:metadata) {
      {
        'name' => 'bar'
      }
    }

    before do
      Zlib::GzipWriter.open(stdlib_pkg) do |gzip|
        Puppet::Util::Archive::Tar::Minitar::Writer.open(gzip) do |tar|
          serialized_metadata = PSON.pretty_generate(metadata)
          tar.add_file_simple('baz/metadata.json',
            :mode => 0644,
            :size => serialized_metadata.bytesize
          ) do |entry|
            entry.write(serialized_metadata)
          end
        end
      end
    end

    after do
      # discard the file content
      File.open(stdlib_pkg, 'w') {}
    end

    it 'should return the module metadata when the parameter represents a module package' do
      pending('porting to Windows', :if => Puppet.features.microsoft_windows?) do
        test_shared.read_module_package_metadata(stdlib_pkg).should == metadata
      end
    end

    it 'should return nil when the parameter does not represent a module package' do
      pending('porting to Windows', :if => Puppet.features.microsoft_windows?) do
        test_shared.read_module_package_metadata('pmtacceptance-apollo-0.0.2.tar').should be_nil
      end
    end
  end

  describe 'the behavior of .get_local_constraints' do
    let (:module1) {
      module1 = mock('Puppet::Module')
      module1.stubs(:forge_name).returns('pmtacceptance/module1')
      module1.stubs(:name).returns('module1')
      module1.stubs(:version).returns('0.5.0')
      module1.stubs(:dependencies).returns([
        {
          'name'                => 'pmtacceptance/stdlib',
          'version_requirement' => '>= 1.8.0',
        },
        {
          'name'                => 'pmtacceptance/module3',
          'version_requirement' => '>= 1.0.0',
        }
      ])
      module1
    }
    let (:module2) {
      module2 = mock('Puppet::Module')
      module2.stubs(:forge_name).returns('pmtacceptance/module2')
      module2.stubs(:name).returns('module2')
      module2.stubs(:version).returns('1.0.0')
      module2.stubs(:dependencies).returns([
        {
          'name'                => 'pmtacceptance/stdlib',
          'version_requirement' => '>= 2.0.0',
        },
      ])
      module2
    }

    before do
      fake_env.expects(:modules_by_path).returns({
        nil => [ module1, module2 ]
      })
    end

    it 'should collect metadata of all locally installed modules as reported by Puppet::Node::Environment.modules_by_path' do
      pending('porting to Windows', :if => Puppet.features.microsoft_windows?) do
        test_shared.get_local_constraints()

        # we need to break cycles in the data structure otherwise rspec fails
        # to compare it successfully; we do it by separating dependencies into
        # their own hash
        installed = test_shared.installed
        dependencies = {}
        installed.each_key do |k|
          dependencies[k] = installed[k].map do |r|
            r.delete(:dependencies)
          end
        end

        module1_info = {
          :module_name  => module1.forge_name.tr('/', '-'),
          :version      => module1.version,
          :semver       => test_shared.safe_semver(module1.version),
          :module       => module1,
        }
        module2_info = {
          :module_name  => module2.forge_name.tr('/', '-'),
          :version      => module2.version,
          :semver       => test_shared.safe_semver(module2.version),
          :module       => module2,
        }

        installed.should == {
          module1.forge_name.tr('/', '-') => [ module1_info ],
          module2.forge_name.tr('/', '-') => [ module2_info ],
        }

        dependencies.should == {
          module1.forge_name.tr('/', '-') => [
            module1.dependencies.map { |d|
              {
                :source     => module1_info,
                :target     => d['name'].tr('/', '-'),
                :constraint => d['version_requirement'],
                :range      => test_shared.safe_range(d['version_requirement']),
              }
            }
          ],
          module2.forge_name.tr('/', '-') => [
            module2.dependencies.map { |d|
              {
                :source     => module2_info,
                :target     => d['name'].tr('/', '-'),
                :constraint => d['version_requirement'],
                :range      => test_shared.safe_range(d['version_requirement']),
              }
            }
          ],
        }
      end
    end

    it 'should collect dependencies from all locally installed modules as reported by Puppet::Node::Environment.modules_by_path' do
      pending('porting to Windows', :if => Puppet.features.microsoft_windows?) do
        test_shared.get_local_constraints()

        # we need to break cycles in the data structure otherwise rspec fails
        # to compare it successfully; we do it by discardig dependencies
        # from the release info structures
        test_shared.installed.each_value do |m|
          m.each do |r|
            r.delete(:dependencies)
          end
        end

        module1_info = {
          :module_name  => module1.forge_name.tr('/', '-'),
          :version      => module1.version,
          :semver       => test_shared.safe_semver(module1.version),
          :module       => module1,
        }
        module2_info = {
          :module_name  => module2.forge_name.tr('/', '-'),
          :version      => module2.version,
          :semver       => test_shared.safe_semver(module2.version),
          :module       => module2,
        }

        test_shared.conditions.should == {
          'pmtacceptance-module3' => [
            {
                :source     => module1_info,
                :target     => 'pmtacceptance-module3',
                :constraint => '>= 1.0.0',
                :range      => test_shared.safe_range('>= 1.0.0'),
            },
          ],
          'pmtacceptance-stdlib' => [
            {
                :source     => module1_info,
                :target     => 'pmtacceptance-stdlib',
                :constraint => '>= 1.8.0',
                :range      => test_shared.safe_range('>= 1.8.0'),
            },
            {
                :source     => module2_info,
                :target     => 'pmtacceptance-stdlib',
                :constraint => '>= 2.0.0',
                :range      => test_shared.safe_range('>= 2.0.0'),
            },
          ],
        }
      end
    end
  end

  describe 'the behavior of .get_remote_constraints' do
    let(:module_name) { 'pmtacceptance-tomcat' }
    let(:version) { '3.x' }

    before do
      test_shared.instance_exec(module_name, version) do |module_name, version|
        # initialize the installed modules information
        @installed = Hash.new { |h,k| h[k] = [] }
        @conditions = Hash.new { |h,k| h[k] = [] }
        @module_name = module_name
        @version = version
      end
    end

    it 'should query Forge for the module which was requested for installation/upgrade when NOT installing/upgrading from a local tarball' do
      pending('porting to Windows', :if => Puppet.features.microsoft_windows?) do
        forge.expects(:multiple_remote_dependency_info).with([
          [Puppet::ModuleTool.username_and_modname_from(module_name).join('/'), version],
        ]).returns({})

        test_shared.get_remote_constraints(nil)
      end
    end

    it 'should query Forge for all dependencies of the module which was requested for installation/upgrade when installing/upgrading from a local tarball' do
      pending('porting to Windows', :if => Puppet.features.microsoft_windows?) do
        release_info = {
          :module_name  => 'pmtacceptance-kerberos',
          :version      => '1.0.0',
          :semver       => test_shared.safe_semver('1.0.0'),
          :url          => 'file:/tmp/pmtacceptance-kerberos-1.0.0.tar.gz',
        }
        release_info[:dependencies] = [
          {
            :source     => release_info,
            :target     => 'pmtacceptance-stdlib',
            :constraint => '1.x',
            :range      => test_shared.safe_range('1.x'),
          },
          {
            :source     => release_info,
            :target     => 'pmtacceptance-ntp',
            :constraint => '>= 0.0.2',
            :range      => test_shared.safe_range('>= 0.0.2'),
          },
        ]

        forge.expects(:multiple_remote_dependency_info).with(release_info[:dependencies].map { |d|
          [Puppet::ModuleTool.username_and_modname_from(d[:target]).join('/'), d[:constraint]]
        }).returns({})

        test_shared.get_remote_constraints(release_info)
      end
    end

    it 'should collect metadata of all modules received in the Forge query response' do
      pending('porting to Windows', :if => Puppet.features.microsoft_windows?) do
        test_shared.get_remote_constraints(nil)

        # we need to break cycles in the data structure otherwise rspec fails
        # to compare it successfully; we do it by separating dependencies into
        # their own hash
        available = test_shared.available
        dependencies = {}
        available.each_key do |k|
          dependencies[k] = available[k].map do |r|
            r.delete(:dependencies)
          end
        end

        expected_available = {}
        remote_dependency_info.each_key do |k|
          module_name = k.tr('/', '-')
          expected_available[module_name] = remote_dependency_info[k].map { |r|
            info = {
              :module_name => module_name,
              :version     => r['version'],
              :semver      => test_shared.safe_semver(r['version']),
              :url         => r['file'],
              :previous    => nil,
            }
            info[:dependencies] = r['dependencies'].map { |d|
              {
                :source     => info,
                :target     => d.first.tr('/', '-'),
                :constraint => d.last,
                :range      => test_shared.safe_range(d.last),
              }
            }
            info
          }.sort { |a,b| b[:semver] <=> a[:semver] }
        end

        # again, we need to break cycles in the data structure
        expected_dependencies = {}
        expected_available.each_key do |k|
          expected_dependencies[k] = expected_available[k].map do |r|
            r.delete(:dependencies)
          end
        end

        available.should == expected_available
        dependencies.should == expected_dependencies
      end
    end
  end

  describe 'the behavior of .get_candidates' do
    let(:module_name) { 'pmtacceptance-stdlib' }
    let(:version) { '>= 0.0.2' }
    let(:range) { test_shared.safe_range(version) }

    before do
      test_shared.instance_exec(module_name, version) do |module_name, version|
        # initialize the installed modules information
        @installed = Hash.new { |h,k| h[k] = [] }
        @conditions = Hash.new { |h,k| h[k] = [] }
        @module_name = module_name
        @version = version
      end
      # initialize the available modules information
      test_shared.get_remote_constraints(nil)
    end

    it 'should select all releases satisfying the constraints in the dependencies' do
      (candidates, preferred) = test_shared.get_candidates({ module_name => [{
        :target => module_name,
        :constraint => version,
        :range => range,
      }] }, {})

      # note that we do not need to break the cycles in the data structure here as members of the compared arrays
      # are the exact same objects in which case rspec doesn't perfrom a deep compare and therefore is unaffected
      # by the cycles
      candidates.should == [test_shared.available[module_name].select { |r| range === r[:semver] }]
    end

    it 'should raise an exception if the constraints are in conflict with an already selected release' do
      lambda {
        (candidates, preferred) = test_shared.get_candidates({ module_name => [{
          :target => module_name,
          :constraint => version,
          :range => range,
        }] }, { module_name => test_shared.available[module_name].last })
      }.should raise_error(
        Puppet::ModuleTool::Errors::NoVersionsSatisfyError,
        "Could not install '#{module_name}' (#{version}); module '#{module_name}' cannot satisfy dependencies"
      )
    end

    it 'should raise an exception if no release satisfies the constraints' do
      # pretend that only the oldest version is available
      test_shared.available[module_name] = [test_shared.available[module_name].last]

      lambda {
        (candidates, preferred) = test_shared.get_candidates({ module_name => [{
          :target => module_name,
          :constraint => version,
          :range => range,
        }] }, {})
      }.should raise_error(
        Puppet::ModuleTool::Errors::NoVersionsSatisfyError,
        "Could not install '#{module_name}' (#{version}); module '#{module_name}' cannot satisfy dependencies"
      )
    end
  end

  describe 'the behavior of .check_resolution' do
    let(:checked_release) {
      checked_version = '1.0.0'
      {
        :module_name  => 'pmtacceptance-stdlib',
        :version      => checked_version,
        :semver       => test_shared.safe_semver(checked_version),
        :url          => '/foo',
        :previous     => nil,
        :dependencies => [],
      }
    }
    let(:module_name) { 'pmtacceptance-ntp' }
    let(:version) { '2.0.0' }

    before do
      test_shared.instance_exec(module_name, version) do |module_name, version|
        @module_name = module_name
        @version = version
      end
    end

    it 'should raise an exception if the resolution does not satisfy constriants imposed by already installed module releases' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/java')
      local_module.stubs(:name).returns('java')
      local_module.stubs(:version).returns('0.5.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([
        {
          'name'                => 'pmtacceptance/stdlib',
          'version_requirement' => '>= 1.8.0',
        },
      ])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      # compile the information about locally installed module releases
      # (actually the above stubbed one which imposes a constraint
      # that is not satisfied by the release checked below)
      test_shared.get_local_constraints()

      lambda {
        test_shared.check_resolution(checked_release, {})
      }.should raise_error(
        Puppet::ModuleTool::Errors::NoVersionsSatisfyError,
        "Could not install '#{module_name}' (v#{version}); module '#{checked_release[:module_name]}' cannot satisfy dependencies"
      )
    end

    it 'should raise an exception if the resolution is a downgrade of an already installed module release' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('1.8.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      # compile the information about locally installed module releases
      # (actually the above stubbed one which is a newer release
      # than the checked below)
      test_shared.get_local_constraints()

      # link the previously installed module release with the checked one
      # as would be the case if the code had been running live
      checked_release[:previous] = test_shared.installed[checked_release[:module_name]].first

      lambda {
        test_shared.check_resolution(checked_release, {})
      }.should raise_error(
        Puppet::ModuleTool::Errors::NewerInstalledError,
        "Won't downgrade '#{local_module.forge_name.tr('/', '-')}' (v#{local_module.version})"
      )
    end

    it 'should raise an exception if the resolution would replace an aleardy installed module release with local modifications' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('0.5.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(true) # pretend local changes
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      # compile the information about locally installed module releases
      # (actually the above stubbed one)
      test_shared.get_local_constraints()

      # link the previously installed module release with the checked one
      # as would be the case if the code was running live
      checked_release[:previous] = test_shared.installed[checked_release[:module_name]].first

      lambda {
        test_shared.check_resolution(checked_release, {})
      }.should raise_error(
        Puppet::ModuleTool::Errors::LocalChangesError,
        "Could not upgrade '#{local_module.forge_name.tr('/', '-')}'; module is installed"
      )
    end

    it 'should NOT raise any exception if --force was specified' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/java')
      local_module.stubs(:name).returns('java')
      local_module.stubs(:version).returns('0.5.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([
        {
          'name'                => 'pmtacceptance/stdlib',
          'version_requirement' => '>= 1.8.0',
        },
      ])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      # compile the information about locally installed module releases
      # (actually the above stubbed one which imposes a contraint
      # that is not satisfied by the release checked below)
      test_shared.get_local_constraints()

      test_shared.instance_exec do
        @force = true
      end

      lambda {
        # if @force was false then this would raise the exception below
        test_shared.check_resolution(checked_release, {})
      }.should_not raise_error(
        Puppet::ModuleTool::Errors::NoVersionsSatisfyError,
        "Could not install '#{module_name}' (v#{version}); module '#{checked_release[:module_name]}' cannot satisfy dependencies"
      )
    end

    it 'should NOT raise any exception if an already installed module is to be checked' do
      local_modules = []

      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/java')
      local_module.stubs(:name).returns('java')
      local_module.stubs(:version).returns('0.5.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([
        {
          'name'                => 'pmtacceptance/stdlib',
          'version_requirement' => '>= 1.8.0',
        },
      ])
      local_modules << local_module

      # note that this module release does not satisfy the dependency constraint
      # of the module above (being of version 0.5.0 while the above module
      # requires version >= 1.8.0)
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('0.5.0')
      local_module.stubs(:dependencies).returns([])
      local_modules << local_module

      fake_env.expects(:modules_by_path).returns({
        nil => local_modules
      })

      # compile the information about locally installed module releases
      # (actually the above stubbed ones which introduce an unsatisfied
      # dependency of an already installed module)
      test_shared.get_local_constraints()

      lambda {
        # if the release was not already installed this would riase the exception below
        test_shared.check_resolution(test_shared.installed[local_module.forge_name.tr('/', '-')].first, {})
      }.should_not raise_error(
        Puppet::ModuleTool::Errors::NoVersionsSatisfyError,
        "Could not install '#{module_name}' (v#{version}); module '#{checked_release[:module_name]}' cannot satisfy dependencies"
      )
    end

    it 'should NOT raise any exception if all checks succeed' do
      fake_env.expects(:modules_by_path).returns({
        nil => []
      })

      # intialize the structures describing the already installed module releases
      test_shared.get_local_constraints()

      lambda {
        test_shared.check_resolution(checked_release, {})
      }.should_not raise_error
    end
  end

  describe 'the behavior of .resolve_constraints' do
    # given a module name, find the module's release which is included in the specified resolution
    def find_in_resolution(resolution, module_name)
      return nil if resolution.empty?

      dependencies = []
      resolution.each do |r|
        release = r[:release]
        return release if release[:module_name] == module_name
        dependencies += r[:dependencies]
      end

      find_in_resolution(dependencies, module_name)
    end

    it 'should produce a tree like structure representing the resolution of the module being installed/upgraded and its dependencies' do
      module_name = 'pmtacceptance-java'
      version = '>= 0.0.2'
      range = test_shared.safe_range(version)

      test_shared.instance_exec(module_name, version) do |module_name, version|
        # initialize the installed modules information
        @installed = Hash.new { |h,k| h[k] = [] }
        @conditions = Hash.new { |h,k| h[k] = [] }
        @module_name = module_name
        @version = version
      end
      # initialize the available modules information
      test_shared.get_remote_constraints(nil)

      resolution = test_shared.resolve_constraints({ module_name => [{
        :target => module_name,
        :constraint => version,
        :range => range,
      }] })

      # note that we do not need to break the cycles in the data structure here as members of the compared arrays
      # are the exat same objects in which case rspec doesn't perfrom a deep compare and therefore is unaffected
      # by the cycles
      release = test_shared.available[module_name].first
      resolution.should == [{
        :release => release,
        :dependencies => release[:dependencies].map { |d|
          {
            :release => test_shared.available[d[:target]].select { |r| d[:range] === r[:semver] }.first,
            :dependencies => []
          }
        }
      }]
    end

    it 'should find a resolution even if it means using older releases of some modules' do
      module_name = 'pmtacceptance-apollo'
      version = '>= 0.0.0'
      range = test_shared.safe_range(version)

      test_shared.instance_exec(module_name) do |module_name|
        # initialize the local module information structures
        @installed = Hash.new { |h,k| h[k] = [] }
        @conditions = Hash.new { |h,k| h[k] = [] }
        @module_name = module_name
        @version = nil
      end

      # gather the available modules information
      test_shared.get_remote_constraints(nil)

      resolution = test_shared.resolve_constraints({ module_name => [{
        :target => module_name,
        :constraint => version,
        :range => range,
      }] })

      # verify that the found resolution does not include the newest release of the requested module
      release = find_in_resolution(resolution, module_name)
      release.should_not be_nil
      release.should_not == test_shared.available[module_name].first
    end

    it 'should use an already installed module release if it satisfies constraints' do
      module_name = 'pmtacceptance-apollo'
      version = '>= 0.0.0'
      range = test_shared.safe_range(version)

      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('0.5.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      test_shared.instance_exec(module_name, version) do |module_name, version|
        @module_name = module_name
        @version = version
      end

      # compile the information about locally installed module releases
      # (actually the above stubbed one which is an older release of a module
      # than what we stub elsewhere to be available from Forge)
      test_shared.get_local_constraints()

      # gather the available modules information
      test_shared.get_remote_constraints(nil)

      resolution = test_shared.resolve_constraints({ module_name => [{
        :target => module_name,
        :constraint => version,
        :range => range,
      }] })

      # verify that the resolution tree does not include any release
      # of the pmtacceptance-stdlib module which means that the already
      # installed release of that module was selected but as it is
      # an already installed release it was left out of the tree
      # (which is not supposed to contain already installed module
      # releases unless some dependencies of such releases are being
      # installed/upgraded and therefore included in the tree)
      find_in_resolution(resolution, local_module.forge_name.tr('/', '-')).should be_nil
    end

    it 'should replace the already installed release if never release is available and --force is used' do
      module_name = 'pmtacceptance-apollo'
      version = '>= 0.0.0'
      range = test_shared.safe_range(version)

      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/apollo')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('0.0.3')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(true)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      test_shared.instance_exec(module_name, version) do |module_name, version|
        @module_name = module_name
        @version = version
        @force = true
      end

      # compile the information about locally installed module releases
      # (actually the above stubbed one which is an older release of a module
      # than what we stub elsewhere to be available from Forge)
      test_shared.get_local_constraints()

      # gather the available modules information
      test_shared.get_remote_constraints(nil)

      resolution = test_shared.resolve_constraints({ module_name => [{
        :target => module_name,
        :constraint => version,
        :range => range,
      }] })

      # verify that the resolution tree includes a releses of the
      # requested module different from that already installed
      release = find_in_resolution(resolution, local_module.forge_name.tr('/', '-'))
      release.should_not be_nil
      release.should_not == test_shared.installed[local_module.forge_name.tr('/', '-')].first
    end

    it 'should upgrade local version when necessary to satisfy constraints' do
      module_name = 'pmtacceptance-apollo'
      version = '>= 0.0.0'
      range = test_shared.safe_range(version)

      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('0.1.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      test_shared.instance_exec(module_name, version) do |module_name, version|
        # initialize the installed modules information
        @module_name = module_name
        @version = version
      end

      # compile the information about locally installed module releases
      # (actually the above stubbed one which is an older release of a module
      # than what we stub elsewhere to be available from Forge)
      test_shared.get_local_constraints()

      # gather the available modules information
      test_shared.get_remote_constraints(nil)

      resolution = test_shared.resolve_constraints({ module_name => [{
        :target => module_name,
        :constraint => version,
        :range => range,
      }] })

      # verify that the resolution tree contains a newer release
      # of the pmtacceptance-stdlib module than that already installed
      find_in_resolution(resolution, local_module.forge_name.tr('/', '-'))[:semver].should >
        test_shared.installed[local_module.forge_name.tr('/', '-')].first[:semver]
    end
  end

  describe 'the behavior of .resolve_install_conflicts' do
    let(:module_name) { 'pmtacceptance-apollo' }
    let(:version) { '>= 0.0.0' }

    let(:checked_resolution) {
      resolved_release_version = '1.0.0'
      [
        {
          :release => {
            :module_name  => 'pmtacceptance-stdlib',
            :version      => resolved_release_version,
            :semver       => test_shared.safe_semver(resolved_release_version),
            :url          => '/foo',
            :previous     => nil,
            :dependencies => [],
          },
          :dependencies => [],
        },
      ]
    }

    before do
      test_shared.instance_exec(module_name, version) do |module_name, version|
        # initialize the installed modules information
        @installed = Hash.new { |h,k| h[k] = [] }
        @conditions = Hash.new { |h,k| h[k] = [] }
        @module_name = module_name
        @version = version
      end
    end

    it 'should raise an exception when a local version of a module has no metadata' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/appolo')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:path).returns(test_shared.options[:target_dir])
      local_module.stubs(:version).returns('0.1.0')
      local_module.stubs(:has_metadata?).returns(false)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        test_shared.options[:target_dir] => [ local_module ]
      })

      lambda {
        test_shared.resolve_install_conflicts(checked_resolution)
      }.should raise_error(
        Puppet::ModuleTool::Errors::InstallConflictError,
        "'#{module_name}' (#{version}) requested; Installation conflict"
      )
    end

    it 'should raise an exception when a local version of a module has a different forge name' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('puppetlabs/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:path).returns(test_shared.options[:target_dir])
      local_module.stubs(:version).returns('0.1.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        test_shared.options[:target_dir] => [ local_module ]
      })

      lambda {
        test_shared.resolve_install_conflicts(checked_resolution)
      }.should raise_error(
        Puppet::ModuleTool::Errors::InstallConflictError,
        "'#{module_name}' (#{version}) requested; Installation conflict"
      )
    end
  end

  describe 'the behavior of .dependencies_statisfied_locally?' do
    let(:target) { 'pmtacceptance-stdlib' }
    let(:constraint) { '>= 1.0.0' }

    let(:dependencies) {
      [
        {
          :target     => target,
          :constraint => constraint,
          :range      => test_shared.safe_range(constraint),
        }
      ]
    }

    it 'should return true if dependencies are satisfied locally' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('1.0.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      # compile the information about locally installed module releases
      # (actually the above stubbed one)
      test_shared.get_local_constraints()

      test_shared.dependencies_statisfied_locally?(dependencies).should be_true
    end

    it 'should return false if dependencies are not satisfied locally' do
      local_module = mock('Puppet::Module')
      local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
      local_module.stubs(:name).returns('stdlib')
      local_module.stubs(:version).returns('0.5.0')
      local_module.stubs(:has_metadata?).returns(true)
      local_module.stubs(:has_local_changes?).returns(false)
      local_module.stubs(:dependencies).returns([])

      fake_env.expects(:modules_by_path).returns({
        nil => [ local_module ]
      })

      # compile the information about locally installed module releases
      # (actually the above stubbed one)
      test_shared.get_local_constraints()

      test_shared.dependencies_statisfied_locally?(dependencies).should be_false
    end
  end
end
