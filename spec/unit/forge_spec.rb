require 'spec_helper'
require 'puppet/forge'
require 'net/http'
require 'puppet_spec/modules'
require 'puppet/module_tool'

describe Puppet::Forge::Forge do
  include PuppetSpec::Files

  let(:response_body) do
  <<-EOF
    [
      {
        "author": "puppetlabs",
        "name": "bacula",
        "tag_list": ["backup", "bacula"],
        "releases": [{"version": "0.0.1"}, {"version": "0.0.2"}],
        "full_name": "puppetlabs/bacula",
        "version": "0.0.2",
        "project_url": "http://github.com/puppetlabs/puppetlabs-bacula",
        "desc": "bacula"
      }
    ]
  EOF
  end
  let(:response) { stub(:body => response_body, :code => '200') }

  before do
    Puppet::Forge::Repository.any_instance.stubs(:make_http_request).returns(response)
    Puppet::Forge::Repository.any_instance.stubs(:retrieve).returns("/tmp/foo")
  end

  let(:forge) { forge = Puppet::Forge::Forge.new('http://forge.puppetlabs.com') }

  describe "the behavior of the search method" do
    context "when there are matches for the search term" do
      before do
        Puppet::Forge::Repository.any_instance.stubs(:make_http_request).returns(response)
      end

      it "should return a list of matches from the forge" do
        forge.search('bacula').should == PSON.load(response_body)
      end
    end

    context "when the connection to the forge fails" do
      let(:response)  { stub(:body => '[]', :code => '404') }

      it "should raise an error" do
        lambda { forge.search('bacula') }.should raise_error RuntimeError
      end
    end
  end

  describe "the behavior of the get_release_packages method" do

    let(:response) do
      stub(:body =>
        { 'fakeauthor/fakemodule' => [
          {
            'file' => 'fakefile',
            'version' => '3.0.0',
            'dependencies' => []
          }],
        }.to_pson
      )
    end

    context "when source is not filesystem or repository" do
      it "should raise an error" do
        params = { :source => 'foo' }
        lambda { forge.get_release_packages(params) }.should
          raise_error(ArgumentError, "Could not determine installation source")
      end
    end

    context "when the source is a repository" do
      let(:params) do
        {
          :source  => :repository,
          :author  => 'fakeauthor',
          :modname => 'fakemodule',
          :version => '0.0.1'
        }
      end

      it "should require author" do
        params.delete(:author)
        lambda { forge.get_release_packages(params) }.should
          raise_error(ArgumentError, ":author and :modename required")
      end

      it "should require modname" do
        params.delete(:modname)
        lambda { forge.get_release_packages(params) }.should
          raise_error(ArgumentError, ":author and :modename required")
      end

      it "should download the release package" do
        forge.get_release_packages(params).should == ["/tmp/foo"]
      end
    end

    context "when the source is a filesystem" do
      it "should require filename" do
        params = { :source => :filesystem }
        lambda { forge.get_release_packages(params) }.should
          raise_error(ArgumentError, ":filename required")
      end
    end
  end

  describe "#find_latest_working_versions" do
    let(:remote_deps) {{
      'matt/awesomemodule' => [
        {
          'file' => 'awesomefile',
          'version' => '3.0.0',
          'dependencies' => [
            ['matt/dependable', ">= 1.0.0"],
            ['matt/nester',     ">= 2.0.0"]
          ]
        },
      ],
      'matt/dependable' => [
        { 'file' => 'dependablefile100', 'version' => '1.0.0', 'dependencies' => [] },
        { 'file' => 'dependablefile101', 'version' => '1.0.1', 'dependencies' => [] },
        { 'file' => 'dependablefile102', 'version' => '1.0.2', 'dependencies' => [] }
      ],
      'matt/nester' => [
        {
          'file' => 'nesterfile',
          'version' => '2.0.0',
          'dependencies' => [ [ 'joe/circular', "= 0.0.1" ] ]
        },
      ],
      'joe/circular' => [
        { 'file' => 'circularfile', 'version' => '0.0.1', 'dependencies' =>  [ ['matt/awesomemodule', ">= 2.0.1" ] ] },
      ]
    }}

    before do
      forge.expects(:remote_dependency_info).returns(remote_deps)
      @modulepath = tmpdir('modulepath')
      Puppet.settings[:modulepath] = @modulepath
    end

    it "should use the latest versions" do
      forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule').should =~ [
        ['matt/awesomemodule', '3.0.0', 'awesomefile'      ],
        ['matt/dependable',    '1.0.2', 'dependablefile102'],
        ['matt/nester',        '2.0.0', 'nesterfile'       ],
        ['joe/circular',       '0.0.1', 'circularfile'     ]
      ]
    end

    it "should use local version when already exists and satisfies constraints" do
      PuppetSpec::Modules.create('dependable', @modulepath, :version => '1.0.1')
      forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule').should =~ [
        ['matt/awesomemodule', '3.0.0', 'awesomefile'      ],
        ['matt/dependable',    '1.0.1', 'dependablefile101'],
        ['matt/nester',        '2.0.0', 'nesterfile'       ],
        ['joe/circular',       '0.0.1', 'circularfile'     ]
      ]
    end

    it "should upgrade local version when necessary to satisfy constraints" do
      PuppetSpec::Modules.create('dependable', @modulepath, :version => '0.0.5')
      PuppetSpec::Modules.create(
        'other_mod',
        @modulepath,
        :dependencies => [{
          "version_requirement" => ">= 0.0.5",
          "name"                => "matt/dependable"
        }]
      )
      PuppetSpec::Modules.create(
        'otro_mod',
        @modulepath,
        :dependencies => [{
          "version_requirement" => "<= 1.0.1",
          "name"                => "matt/dependable"
        }]
      )

      forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule').should =~ [
        ['matt/awesomemodule', '3.0.0', 'awesomefile'      ],
        ['matt/dependable',    '1.0.1', 'dependablefile101'],
        ['matt/nester',        '2.0.0', 'nesterfile'       ],
        ['joe/circular',       '0.0.1', 'circularfile'     ]
      ]
    end

    it "should error when a local version of a dependency has no version metadata" do
      PuppetSpec::Modules.create('dependable', @modulepath, :version => '')
      expect { forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule') }.to raise_error(
        RuntimeError,
        'A local version of the dependable module exists without version info'
      )
    end

    it "should error when a local version of a dependency has a non-semver version" do
      PuppetSpec::Modules.create('dependable', @modulepath, :version => '1.1')
      expect { forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule') }.to raise_error(
        RuntimeError,
        'A local version of the dependable module declares a non semantic version (1.1)'
      )
    end

    it "should error when a local version of a dependency has a different forge name" do
      PuppetSpec::Modules.create('dependable', @modulepath, :author => 'notmatt')
      expect { forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule') }.to raise_error(
        RuntimeError,
        "A local version of the dependable module exists but has a different name (notmatt/dependable)"
      )
    end

    it "should error when a local version of a dependency has no metadata" do
      PuppetSpec::Modules.create('dependable', @modulepath, :nometadata => true)
      expect { forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule') }.to raise_error(
        RuntimeError,
        "A local version of the dependable module exists but has no metadata"
      )
    end

    it "should error when a local version can't be upgraded to satisfy constraints" do
      PuppetSpec::Modules.create(
        'dependnotable',
        @modulepath,
        :dependencies => [{
          "version_requirement" => "< 1.0.0",
          "name"                => "matt/dependable"
        }]
      )
      PuppetSpec::Modules.create('dependable', @modulepath, :version => '0.0.5')
      expect { forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule') }.to raise_error(
        RuntimeError,
        'No working versions for matt/dependable'
      )
    end

    it "should error when no version for a dependency meets constraints" do
      PuppetSpec::Modules.create(
        'dependnotable',
        @modulepath,
        :dependencies => [{
          "version_requirement" => "< 1.0.0",
          "name"                => "matt/dependable"
        }]
      )
      expect { forge.send(:resolve_remote_and_local_constraints, 'matt', 'awesomemodule') }.to raise_error(
        RuntimeError,
        'No working versions for matt/dependable'
      )
    end

  end

end
