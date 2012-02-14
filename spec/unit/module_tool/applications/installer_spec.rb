require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::Module::Tool::Applications::Installer do
  include PuppetSpec::Files

  # install single module
  # module with multiple levels of dependencies
  # module with circular dependencies
  #   version mismatch - boom
  #     foo > 2 -> bar > 2
  #     bar -> foo < 2
  #   no mismatch - should be fine
  #     foo > 2 -> bar > 2
  #     bar > 2 -> foo > 2
  # dependency conflicts as a install
  #   remote foo -> bar > 2 -> baz
  #       -> bing -> bar > 2 < 3 -> baz
  #   local bong -> bar > 2.2
  #
  #   foo {
  #
  #   }
  #   bar {
  #     deps_on_me => > 2 < 3 > 2.2
  #     versions {
  #       2.0
  #       2.5 deps => baz
  #       (server not send maybe) 5.0 deps => baz
  #     }
  #   }
  #
  #   bing {
  #     deps_on_me => foo
  #     versions {
  #       1.0 deps => bar >2 < 3
  #     }
  #   }
  # module with remote dependency constraints that don't work with already installed modules
  #   foo -> bar > 2
  #   bar 1.1 already installed
  #   baz already installed -> bar < 2


  it "should install a specific version"
  it "should prompt to overwrite"
  it "should output warnings"

  let(:installer_class) { Puppet::Module::Tool::Applications::Installer }

  context "when the source is a repository" do
    it "should require a valid name" do
      lambda { installer_class.run('puppet', params) }.should
        raise_error(ArgumentError, "Could not install module with invalid name: puppet")
    end
  end

  describe ".resolve_remote_and_local_constraints" do
    let(:remote_deps) {{
      'puppetlabs/awesomemodule' => [
        {
          'file' => 'awesomefile',
          'version' => '3.0.0',
          'dependencies' => [
            ['puppetlabs/dependable', ">= 1.0.0"],
            ['puppetlabs/nester',     ">= 2.0.0"]
          ]
        },
      ],
      'puppetlabs/dependable' => [
        { 'file' => 'dependablefile100', 'version' => '1.0.0', 'dependencies' => [] },
        { 'file' => 'dependablefile101', 'version' => '1.0.1', 'dependencies' => [] },
        { 'file' => 'dependablefile102', 'version' => '1.0.2', 'dependencies' => [] }
      ],
      'puppetlabs/nester' => [
        {
          'file' => 'nesterfile',
          'version' => '2.0.0',
          'dependencies' => [ [ 'joe/circular', "= 0.0.1" ] ]
        },
      ],
      'joe/circular' => [
        { 'file' => 'circularfile', 'version' => '0.0.1', 'dependencies' =>  [ ['puppetlabs/awesomemodule', ">= 2.0.1" ] ] },
      ]
    }}

    let(:installer) { installer = installer_class.new('puppetlabs/awesomemodule') }

    before do
      @modulepath = tmpdir('modulepath')
      Puppet.settings[:modulepath] = @modulepath

      # always having a local version without metadata is useful to make sure
      # everything works well in that situation
      PuppetSpec::Modules.create('notdirectlyaffectinstall', @modulepath)
    end

    it "should use the latest versions" do
      installer.send(:resolve_remote_and_local_constraints, remote_deps).should =~ [
        ['puppetlabs/awesomemodule', '3.0.0', 'awesomefile'      ],
        ['puppetlabs/dependable',    '1.0.2', 'dependablefile102'],
        ['puppetlabs/nester',        '2.0.0', 'nesterfile'       ],
        ['joe/circular',             '0.0.1', 'circularfile'     ]
      ]
    end

    it "should not install if the module is already installed" do
    end

    it "should use local version when already exists and satisfies constraints" do
      PuppetSpec::Modules.create(
        'dependable',
        @modulepath,
        :metadata => { :version => '1.0.1' }
      )
      installer.send(:resolve_remote_and_local_constraints, remote_deps).should =~ [
        ['puppetlabs/awesomemodule', '3.0.0', 'awesomefile'      ],
        ['puppetlabs/nester',        '2.0.0', 'nesterfile'       ],
        ['joe/circular',             '0.0.1', 'circularfile'     ]
      ]
    end

    it "should upgrade local version when necessary to satisfy constraints" do
      PuppetSpec::Modules.create(
        'dependable',
        @modulepath,
        :metadata => { :version => '0.0.5' }
      )
      PuppetSpec::Modules.create(
        'other_mod',
        @modulepath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 0.0.5",
            "name"                => "puppetlabs/dependable"
          }]
        }
      )
      PuppetSpec::Modules.create(
        'otro_mod',
        @modulepath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => "<= 1.0.1",
            "name"                => "puppetlabs/dependable"
          }]
        }
      )

      installer.send(:resolve_remote_and_local_constraints, remote_deps).should =~ [
        ['puppetlabs/awesomemodule', '3.0.0', 'awesomefile'      ],
        ['puppetlabs/dependable',    '1.0.1', 'dependablefile101'],
        ['puppetlabs/nester',        '2.0.0', 'nesterfile'       ],
        ['joe/circular',             '0.0.1', 'circularfile'     ]
      ]
    end

    it "should error when a local module needs upgrading to satisfy constraints but has changes" do
      foo_checksum = 'd3b07384d113edec49eaa6238ad5ff00'
      checksummed_module = PuppetSpec::Modules.create(
        'dependable',
        @modulepath,
        :metadata => {
          :version => '0.0.5',
          :checksums => {
            "foo" => foo_checksum,
          }
        }
      )

      foo_path = Pathname.new(File.join(checksummed_module.path, 'foo'))
      File.open(foo_path, 'w') { |f| f.puts 'notfoo' }
      checksummed_module.has_local_changes?.should be_true

      expect { installer.send(:resolve_remote_and_local_constraints, remote_deps) }.to raise_error(
        RuntimeError,
        "Module puppetlabs/dependable (1.0.2) needs to be installed to satisfy contraints, but can't be because it has local changes"
      )
    end

    it "should error when a local version of a dependency has no version metadata" do
      PuppetSpec::Modules.create('dependable', @modulepath, :metadata => {:version => ''})
      expect { installer.send(:resolve_remote_and_local_constraints, remote_deps) }.to raise_error(
        RuntimeError,
        'A local version of the dependable module exists without version info'
      )
    end

    it "should error when a local version of a dependency has a non-semver version" do
      PuppetSpec::Modules.create('dependable', @modulepath, :metadata => {:version => '1.1'})
      expect { installer.send(:resolve_remote_and_local_constraints, remote_deps) }.to raise_error(
        RuntimeError,
        'A local version of the dependable module declares a non semantic version (1.1)'
      )
    end

    it "should error when a local version of a dependency has a different forge name" do
      PuppetSpec::Modules.create('dependable', @modulepath, :metadata => {:author => 'notpuppetlabs'})
      expect { installer.send(:resolve_remote_and_local_constraints, remote_deps) }.to raise_error(
        RuntimeError,
        "A local version of the dependable module exists but has a different name (notpuppetlabs/dependable)"
      )
    end

    it "should error when a local version of a dependency has no metadata" do
      PuppetSpec::Modules.create('dependable', @modulepath)
      expect { installer.send(:resolve_remote_and_local_constraints, remote_deps) }.to raise_error(
        RuntimeError,
        "A local version of the dependable module exists but has no metadata"
      )
    end

    it "should error when a local version can't be upgraded to satisfy constraints" do
      PuppetSpec::Modules.create(
        'dependnotable',
        @modulepath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => "< 1.0.0",
            "name"                => "puppetlabs/dependable"
          }]
        }
      )
      PuppetSpec::Modules.create('dependable', @modulepath, :metadata => {:version => '0.0.5'})
      expect { installer.send(:resolve_remote_and_local_constraints, remote_deps) }.to raise_error(
        RuntimeError,
        'No working versions for puppetlabs/dependable'
      )
    end

    it "should error when no version for a dependency meets constraints" do
      PuppetSpec::Modules.create(
        'dependnotable',
        @modulepath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => "< 1.0.0",
            "name"                => "puppetlabs/dependable"
          }]
        }
      )
      expect { installer.send(:resolve_remote_and_local_constraints, remote_deps) }.to raise_error(
        RuntimeError,
        'No working versions for puppetlabs/dependable'
      )
    end
  end

  context "when the source is a filesystem" do
    before do
      @sourcedir = tmpdir('sourcedir')
    end

    it "should error if it can't parse the name" do
      filemod = File.join(@sourcedir, 'notparseable')
      File.open(filemod, 'w') {|f| f.puts 'ha ha cant parse'}
      expect { installer_class.run(filemod) }.to raise_error(
        ArgumentError,
        'Could not parse filename to obtain the username, module name and version.  (notparseable)'
      )
    end

    it "should try to get_release_package_from_filesystem if it has a valid name" do
      filemod = File.join(@sourcedir, 'author-modname-1.0.0.tar.gz')
      File.open(filemod, 'w') {|f| f.puts 'not really a tar'}

      Puppet::Forge::Forge.
        expects(:get_release_package_from_filesystem).
        returns ['fake_cache_path']
      Puppet::Module::Tool::Applications::Unpacker.expects(:run).with(['fake_cache_path'], {})

      installer_class.run(filemod)
    end
  end
end
