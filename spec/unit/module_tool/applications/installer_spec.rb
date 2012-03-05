require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'
require 'semver'

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
  before do
  end

  let(:installer_class) { Puppet::Module::Tool::Applications::Installer }

  context "when the source is a repository" do
    it "should require a valid name" do
      lambda { installer_class.run('puppet', params) }.should
        raise_error(ArgumentError, "Could not install module with invalid name: puppet")
    end
  end

  let(:remote_deps) {{
    'puppetlabs/awesomemodule' => [
      {
        'file' => 'awesomefile',
        'version' => '3.0.0',
        'dependencies' => [
          ['puppetlabs/dependable', "1.0.x"   ],
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

  let(:remote_dependency_info) do
    {
      "pmtacceptance/stdlib" => [
        { "dependencies" => [],
          "version"      => "0.0.1",
          "file"         => "/pmtacceptance-stdlib-0.0.1.tar.gz" },
        { "dependencies" => [],
          "version"      => "0.0.2",
          "file"         => "/pmtacceptance-stdlib-0.0.2.tar.gz" },
        { "dependencies" => [],
          "version"      => "1.0.0",
          "file"         => "/pmtacceptance-stdlib-1.0.0.tar.gz" }
      ],
      "pmtacceptance/java" => [
        { "dependencies" => [["pmtacceptance/stdlib", ">= 0.0.1"]],
          "version"      => "1.7.0",
          "file"         => "/pmtacceptance-java-1.7.0.tar.gz" },
        { "dependencies" => [["pmtacceptance/stdlib", "1.0.0"]],
          "version"      => "1.7.1",
          "file"         => "/pmtacceptance-java-1.7.1.tar.gz" }
      ],
      "pmtacceptance/apollo" => [
        { "dependencies" => [
            ["pmtacceptance/java", ">= 1.7.0"],
            ["pmtacceptance/stdlib", ">= 1.0.0"]
          ],
          "version" => "0.0.1",
          "file"=> "/pmtacceptance-apollo-0.0.1.tar.gz" }
      ]
    }
  end

  describe "the behavior of get_local_constraints" do
    before do
      Puppet.settings[:modulepath] = modulepath

      PuppetSpec::Modules.create(
        'dependable',
        modulepath,
        :metadata => { :version => '1.0.1' }
      )

      PuppetSpec::Modules.create(
        'other_mod',
        modulepath,
        :metadata => {
          :version => '1.0.0',
          :dependencies => [{
            "version_requirement" => ">= 0.0.5",
            "name"                => "puppetlabs/dependable"
          }]
        }
      )
    end

    let(:modulepath) { tmpdir('modulepath') }

    it "shoud return the local module constraints" do
      expected_output = {
        "puppetlabs-other_mod@1.0.0" => {
          "puppetlabs-dependable" => ">= 0.0.5"
        },
        "puppetlabs-dependable@1.0.1" => {}
      }

      installer = installer_class.new('puppetlabs/awesomefile')
      installer.send(:get_local_constraints).should == expected_output
    end

    it "should set the @installed instance variable" do
      expected_output = {
        "puppetlabs-other_mod"  => "1.0.0",
        "puppetlabs-dependable" => "1.0.1"
      }

      installer = installer_class.new('puppetlabs/awesomefile')
      installer.send(:get_local_constraints)
      installer.instance_variable_get(:@installed).should == expected_output
    end

    it "should set the @conditions instance variable" do
      expected_output = {
        "puppetlabs-dependable" => [
          {
            :dependency => ">= 0.0.5",
            :version    => "1.0.0",
            :module     => "puppetlabs-other_mod"
         }
        ]
      }

      installer = installer_class.new('puppetlabs/awesomefile')
      installer.send(:get_local_constraints)
      installer.instance_variable_get(:@conditions).should == expected_output
    end
  end

  describe "the behavior of get_remote_constraints" do
    before do
      Puppet::Forge.stubs(:remote_dependency_info).returns(remote_dependency_info)
    end

    let(:remote_dependency_info) do
      {
        "pmtacceptance/stdlib" => [
          { "dependencies" => [],
            "version"      => "0.0.1",
            "file"         => "/pmtacceptance-stdlib-0.0.1.tar.gz" },
          { "dependencies" => [],
            "version"      => "0.0.2",
            "file"         => "/pmtacceptance-stdlib-0.0.2.tar.gz" },
          { "dependencies" => [],
            "version"      => "1.0.0",
            "file"         => "/pmtacceptance-stdlib-1.0.0.tar.gz" }
        ],
        "pmtacceptance/java" => [
          { "dependencies" => [["pmtacceptance/stdlib", ">= 0.0.1"]],
            "version"      => "1.7.0",
            "file"         => "/pmtacceptance-java-1.7.0.tar.gz" },
          { "dependencies" => [["pmtacceptance/stdlib", "1.0.0"]],
            "version"      => "1.7.1",
            "file"         => "/pmtacceptance-java-1.7.1.tar.gz" }
        ],
        "pmtacceptance/apollo" => [
          { "dependencies" => [
              ["pmtacceptance/java", ">= 1.7.0"],
              ["pmtacceptance/stdlib", ">= 1.0.0"]
            ],
            "version" => "0.0.1",
            "file"=> "/pmtacceptance-apollo-0.0.1.tar.gz" }
        ]
      }
    end

    it "should return remote constraints" do
      expected_output = {
        "pmtacceptance-stdlib@1.0.0" => {},
        "pmtacceptance-stdlib@0.0.1" => {},
        "pmtacceptance-apollo@0.0.1" => {
          "pmtacceptance-stdlib" => ">= 1.0.0",
          "pmtacceptance-java"   => ">= 1.7.0"
        },
        "pmtacceptance-stdlib@0.0.2" => {},
        "pmtacceptance-java@1.7.0"   => {"pmtacceptance-stdlib" => ">= 0.0.1"},
        "pmtacceptance-java@1.7.1"   => {"pmtacceptance-stdlib" => "1.0.0"}
      }

      installer = installer_class.new('puppetlabs/awesomefile')
      installer.send(:get_remote_constraints).should == expected_output
    end

    it "should set the @versions instance variable" do
      expected_output = {
        "pmtacceptance-stdlib" => [
          {:semver => SemVer.new("0.0.1"), :vstring => "0.0.1"},
          {:semver => SemVer.new("0.0.2"), :vstring => "0.0.2"},
          {:semver => SemVer.new("1.0.0"), :vstring => "1.0.0"}
        ],
        "pmtacceptance-java" => [
          {:semver => SemVer.new("1.7.0"), :vstring => "1.7.0"},
          {:semver => SemVer.new("1.7.1"), :vstring => "1.7.1"}
        ],
        "pmtacceptance-apollo" => [
          {:semver => SemVer.new("0.0.1"), :vstring => "0.0.1"}
        ]
      }

      installer = installer_class.new('puppetlabs/awesomefile')
      installer.send(:get_remote_constraints)
      installer.instance_variable_get(:@versions).should == expected_output
    end

    it "should set the @urls instance variable" do
      expected_output = {
        "pmtacceptance-stdlib@1.0.0" => "/pmtacceptance-stdlib-1.0.0.tar.gz",
        "pmtacceptance-stdlib@0.0.1" => "/pmtacceptance-stdlib-0.0.1.tar.gz",
        "pmtacceptance-apollo@0.0.1" => "/pmtacceptance-apollo-0.0.1.tar.gz",
        "pmtacceptance-stdlib@0.0.2" => "/pmtacceptance-stdlib-0.0.2.tar.gz",
        "pmtacceptance-java@1.7.0"   => "/pmtacceptance-java-1.7.0.tar.gz",
        "pmtacceptance-java@1.7.1"   => "/pmtacceptance-java-1.7.1.tar.gz"
      }

      installer = installer_class.new('puppetlabs/awesomefile')
      installer.send(:get_remote_constraints)
      installer.instance_variable_get(:@urls).should == expected_output
    end
  end

  describe "the behavior of resolve_constraints" do
    let(:versions) do
      {
        "pmtacceptance-stdlib" => [
          {:semver => SemVer.new("0.0.1"), :vstring => "0.0.1"},
          {:semver => SemVer.new("0.0.2"), :vstring => "0.0.2"},
          {:semver => SemVer.new("1.0.0"), :vstring => "1.0.0"}
        ],
        "pmtacceptance-java" => [
          {:semver => SemVer.new("1.7.0"), :vstring => "1.7.0"},
          {:semver => SemVer.new("1.7.1"), :vstring => "1.7.1"}
        ],
        "pmtacceptance-apollo" => [
          {:semver => SemVer.new("0.0.1"), :vstring => "0.0.1"}
        ]
      }
    end

    let(:urls) do
      {
        "pmtacceptance-stdlib@1.0.0" => "/pmtacceptance-stdlib-1.0.0.tar.gz",
        "pmtacceptance-stdlib@0.0.1" => "/pmtacceptance-stdlib-0.0.1.tar.gz",
        "pmtacceptance-apollo@0.0.1" => "/pmtacceptance-apollo-0.0.1.tar.gz",
        "pmtacceptance-stdlib@0.0.2" => "/pmtacceptance-stdlib-0.0.2.tar.gz",
        "pmtacceptance-java@1.7.0"   => "/pmtacceptance-java-1.7.0.tar.gz",
        "pmtacceptance-java@1.7.1"   => "/pmtacceptance-java-1.7.1.tar.gz"
      }
    end

    let(:remote) do
      {
        "pmtacceptance-stdlib@1.0.0" => {},
        "pmtacceptance-stdlib@0.0.1" => {},
        "pmtacceptance-apollo@0.0.1" => {
          "pmtacceptance-stdlib" => ">= 1.0.0",
          "pmtacceptance-java"   => ">= 1.7.0"
        },
        "pmtacceptance-stdlib@0.0.2" => {},
        "pmtacceptance-java@1.7.0"   => {"pmtacceptance-stdlib" => ">= 0.0.1"},
        "pmtacceptance-java@1.7.1"   => {"pmtacceptance-stdlib" => "1.0.0"}
      }
    end

    context "when there are no installed modules" do
      let(:conditions) { Hash.new { |h,k| h[k] = [] } }
      let(:installed)  { Hash.new }
      let(:installer) do
        installer = installer_class.new('pmtacceptance/apollo')
        installer.instance_variable_set(:@installed, installed)
        installer.instance_variable_set(:@conditions, conditions)
        installer.instance_variable_set(:@versions, versions)
        installer.instance_variable_set(:@urls, urls)
        installer.instance_variable_set(:@remote, remote)
        installer
      end

      it "should resolve constraints" do
        expected_output = [
          { :module       => "pmtacceptance-apollo",
            :dependencies => [
              { :module       => "pmtacceptance-stdlib",
                :dependencies => [],
                :version      => {:semver => SemVer.new('1.0.0'), :vstring => "1.0.0"},
                :file         => "/pmtacceptance-stdlib-1.0.0.tar.gz",
                :action       => :install,
                :previous_version => nil },
              { :module       => "pmtacceptance-java",
                :dependencies => [],
                :version      => {:semver => SemVer.new('1.7.1'), :vstring => "1.7.1"},
                :file         => "/pmtacceptance-java-1.7.1.tar.gz",
                :action       => :install,
                :previous_version => nil }
            ],
           :version => {:semver => SemVer.new('0.0.1'), :vstring => "0.0.1"},
           :file    => "/pmtacceptance-apollo-0.0.1.tar.gz",
           :action  => :install,
           :previous_version => nil
          }
        ]

        results = installer.send(:resolve_constraints, {'pmtacceptance-apollo' => '0.0.1'})
        expected_output[0].keys.each do |key|
          if key == :dependencies
            next
          end
          results[0][key].should == expected_output[0][key]
        end
      end

      it "should use the latest versions" do
        expected_output = [
          { :module       => "pmtacceptance-stdlib",
            :dependencies => [],
            :action       => :install,
            :version      => {:semver => SemVer.new('1.0.0'), :vstring => "1.0.0"},
            :file         => "/pmtacceptance-stdlib-1.0.0.tar.gz",
            :previous_version => nil
          }
        ]

        installer.send(:resolve_constraints, {'pmtacceptance-stdlib' => '>= 0.0.0'}).should == expected_output
      end

      context "when there are modules installed" do
        let(:installed) do
          { 'pmtacceptance-stdlib' => "1.0.0" }
        end

        it "should use local version when already exists and satisfies constraints" do
          installer.send(:resolve_constraints, {'pmtacceptance-stdlib' => '>= 0.0.0'}).should == []
          installer.send(:resolve_constraints, {'pmtacceptance-stdlib' => '1.0.0'}).should == []
        end

        it "should reinstall the local version and if force is used" do
          expected_output = [
            { :action       => :install,
              :dependencies => [],
              :version      => {:semver => SemVer.new('1.0.0'), :vstring => "1.0.0"},
              :previous_version => "1.0.0",
              :file         => "/pmtacceptance-stdlib-1.0.0.tar.gz",
              :module       => "pmtacceptance-stdlib"
            }
          ]
          installer.instance_variable_set(:@force, true)
          installer.send(:resolve_constraints, {'pmtacceptance-stdlib' => '1.0.0'}).should == expected_output
        end

        it "should upgrade local version when necessary to satisfy constraints" do
          expected_version_hash = {
            :semver  => SemVer.new('1.0.0'),
            :vstring => "1.0.0"
          }
          installer.instance_variable_set(:@installed, {'pmtacceptance-stdlib' => "0.0.5"})
          result = installer.send(:resolve_constraints, {'pmtacceptance-stdlib' => '1.0.0'})
          result[0][:action].should  == :upgrade
          result[0][:version].should == expected_version_hash
        end

        it "should error when a local version can't be upgraded to satisfy constraints" do
          broken_remote = {
            "pmtacceptance-broken@1.0.0" => {"pmtacceptance-stdlib" => ">= 10.0.0"}
          }
          broken_versions = {
            "pmtacceptance-broken" => [
              {:semver => SemVer.new("1.0.0"), :vstring => "1.0.0"}
            ]
          }

          broken_remote.merge!(remote_dependency_info)
          broken_versions.merge!(versions)

          installer.instance_variable_set(:@installed, {'pmtacceptance-stdlib' => "1.0.0"})
          installer.instance_variable_set(:@remote, broken_remote)
          installer.instance_variable_set(:@versions, broken_versions)

          lambda do
            installer.send(:resolve_constraints, {'pmtacceptance-broken' => '1.0.0'})
          end.should raise_error (RuntimeError, "No versions satisfy!")
        end
      end

      context "when a local module needs upgrading to satisfy constraints but has changes" do
        it "should error"
        it "should warn and continue if force is used"
      end

      it "should error when a local version of a dependency has no version metadata"
      it "should error when a local version of a dependency has a non-semver version"
      it "should error when a local version of a dependency has a different forge name"
      it "should error when a local version of a dependency has no metadata"
      it "should warn and skip a dependency with no version that satisfies constraints if force is used"

      it "should error when no version for a dependency meets constraints" do
        lambda do
          installer.send(:resolve_constraints, {'pmtacceptance-apollo' => '5.0.0'})
        end.should raise_error (RuntimeError, "No versions satisfy!")
      end

      context "when 'options[:ignore_dependencies]' is set to true" do
        it "should ignore dependencies" do
          installer.stubs(:options).returns({:ignore_dependencies => true})

          results = installer.send(:resolve_constraints, {'pmtacceptance-apollo' => '0.0.1'})
          results[0][:dependencies].should == []
        end
      end
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

    it "should try to get_release_package_from_filesystem if it has a valid name"
  end
end
