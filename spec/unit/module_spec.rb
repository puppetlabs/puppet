#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/modules'
require 'puppet/module_tool/checksums'

describe Puppet::Module do
  include PuppetSpec::Files

  let(:env) { mock("environment") }
  let(:path) { "/path" }
  let(:name) { "mymod" }
  let(:mod) { Puppet::Module.new(name, path, env) }

  before do
    # This is necessary because of the extra checks we have for the deprecated
    # 'plugins' directory
    Puppet::FileSystem.stubs(:exist?).returns false
  end

  it "should have a class method that returns a named module from a given environment" do
    env = Puppet::Node::Environment.create(:myenv, [])
    env.expects(:module).with(name).returns "yep"
    Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
      Puppet::Module.find(name, "myenv").should == "yep"
    end
  end

  it "should return nil if asked for a named module that doesn't exist" do
    env = Puppet::Node::Environment.create(:myenv, [])
    env.expects(:module).with(name).returns nil
    Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
      Puppet::Module.find(name, "myenv").should be_nil
    end
  end

  describe "attributes" do
    it "should support a 'version' attribute" do
      mod.version = 1.09
      mod.version.should == 1.09
    end

    it "should support a 'source' attribute" do
      mod.source = "http://foo/bar"
      mod.source.should == "http://foo/bar"
    end

    it "should support a 'project_page' attribute" do
      mod.project_page = "http://foo/bar"
      mod.project_page.should == "http://foo/bar"
    end

    it "should support an 'author' attribute" do
      mod.author = "Luke Kanies <luke@madstop.com>"
      mod.author.should == "Luke Kanies <luke@madstop.com>"
    end

    it "should support a 'license' attribute" do
      mod.license = "GPL2"
      mod.license.should == "GPL2"
    end

    it "should support a 'summary' attribute" do
      mod.summary = "GPL2"
      mod.summary.should == "GPL2"
    end

    it "should support a 'description' attribute" do
      mod.description = "GPL2"
      mod.description.should == "GPL2"
    end

    it "should support specifying a compatible puppet version" do
      mod.puppetversion = "0.25"
      mod.puppetversion.should == "0.25"
    end
  end

  it "should validate that the puppet version is compatible" do
    mod.puppetversion = "0.25"
    Puppet.expects(:version).returns "0.25"
    mod.validate_puppet_version
  end

  it "should fail if the specified puppet version is not compatible" do
    mod.puppetversion = "0.25"
    Puppet.stubs(:version).returns "0.24"
    lambda { mod.validate_puppet_version }.should raise_error(Puppet::Module::IncompatibleModule)
  end

  describe "when finding unmet dependencies" do
    before do
      Puppet::FileSystem.unstub(:exist?)
      @modpath = tmpdir('modpath')
      Puppet.settings[:modulepath] = @modpath
    end

    it "should list modules that are missing" do
      metadata_file = "#{@modpath}/needy/metadata.json"
      Puppet::FileSystem.expects(:exist?).with(metadata_file).returns true
      mod = PuppetSpec::Modules.create(
        'needy',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar"
          }]
        }
      )
      mod.unmet_dependencies.should == [{
        :reason => :missing,
        :name   => "baz/foobar",
        :version_constraint => ">= 2.2.0",
        :parent => { :name => 'puppetlabs/needy', :version => 'v9.9.9' },
        :mod_details => { :installed_version => nil }
      }]
    end

    it "should list modules that are missing and have invalid names" do
      metadata_file = "#{@modpath}/needy/metadata.json"
      Puppet::FileSystem.expects(:exist?).with(metadata_file).returns true
      mod = PuppetSpec::Modules.create(
        'needy',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar=bar"
          }]
        }
      )
      mod.unmet_dependencies.should == [{
        :reason => :missing,
        :name   => "baz/foobar=bar",
        :version_constraint => ">= 2.2.0",
        :parent => { :name => 'puppetlabs/needy', :version => 'v9.9.9' },
        :mod_details => { :installed_version => nil }
      }]
    end

    it "should list modules with unmet version requirement" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      ['test_gte_req', 'test_specific_req', 'foobar'].each do |mod_name|
        metadata_file = "#{@modpath}/#{mod_name}/metadata.json"
        Puppet::FileSystem.stubs(:exist?).with(metadata_file).returns true
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

      mod.unmet_dependencies.should == [{
        :reason => :version_mismatch,
        :name   => "baz/foobar",
        :version_constraint => ">= 2.2.0",
        :parent => { :version => "v9.9.9", :name => "puppetlabs/test_gte_req" },
        :mod_details => { :installed_version => "2.0.0" }
      }]

      mod2.unmet_dependencies.should == [{
        :reason => :version_mismatch,
        :name   => "baz/foobar",
        :version_constraint => "v1.0.0",
        :parent => { :version => "v9.9.9", :name => "puppetlabs/test_specific_req" },
        :mod_details => { :installed_version => "2.0.0" }
      }]

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

      mod.unmet_dependencies.should be_empty
    end

    it "should consider a dependency without a semantic version to be unmet" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      metadata_file = "#{@modpath}/foobar/metadata.json"
      Puppet::FileSystem.expects(:exist?).with(metadata_file).times(3).returns true
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

      mod.unmet_dependencies.should == [{
        :reason => :non_semantic_version,
        :parent => { :version => "v9.9.9", :name => "puppetlabs/foobar" },
        :mod_details => { :installed_version => "5.1" },
        :name => "baz/foobar",
        :version_constraint => ">= 0.0.0"
      }]
    end

    it "should have valid dependencies when no dependencies have been specified" do
      mod = PuppetSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :dependencies => []
        }
      )

      mod.unmet_dependencies.should == []
    end

    it "should only list unmet dependencies" do
      env = Puppet::Node::Environment.create(:testing, [@modpath])

      [name, 'satisfied'].each do |mod_name|
        metadata_file = "#{@modpath}/#{mod_name}/metadata.json"
        Puppet::FileSystem.expects(:exist?).with(metadata_file).twice.returns true
      end
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

      mod.unmet_dependencies.should == [{
        :reason => :missing,
        :mod_details => { :installed_version => nil },
        :parent => { :version => "v9.9.9", :name => "puppetlabs/#{name}" },
        :name => "baz/notsatisfied",
        :version_constraint => ">= 2.2.0"
      }]
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

      mod.unmet_dependencies.should be_empty
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
    Puppet::Module.find(nil, "myenv").should be_nil
  end

  it "should provide support for logging" do
    Puppet::Module.ancestors.should be_include(Puppet::Util::Logging)
  end

  it "should be able to be converted to a string" do
    mod.to_s.should == "Module #{name}(#{path})"
  end

  it "should fail if its name is not alphanumeric" do
    lambda { Puppet::Module.new(".something", "/path", env) }.should raise_error(Puppet::Module::InvalidName)
  end

  it "should require a name at initialization" do
    lambda { Puppet::Module.new }.should raise_error(ArgumentError)
  end

  it "should accept an environment at initialization" do
    Puppet::Module.new("foo", "/path", env).environment.should == env
  end

  describe '#modulepath' do
    it "should return the directory the module is installed in, if a path exists" do
      mod = Puppet::Module.new("foo", "/a/foo", env)
      mod.modulepath.should == '/a'
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
      Puppet::FileSystem.expects(:exist?).with(module_file).returns true
      mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should == module_file
    end

    it "should consider #{filetype} to be present if their base directory exists" do
      module_file = File.join(path, dirname)
      Puppet::FileSystem.expects(:exist?).with(module_file).returns true
      mod.send(filetype.to_s + "?").should be_true
    end

    it "should consider #{filetype} to be absent if their base directory does not exist" do
      module_file = File.join(path, dirname)
      Puppet::FileSystem.expects(:exist?).with(module_file).returns false
      mod.send(filetype.to_s + "?").should be_false
    end

    it "should return nil if asked to return individual #{filetype} that don't exist" do
      module_file = File.join(path, dirname, "my/file")
      Puppet::FileSystem.expects(:exist?).with(module_file).returns false
      mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should be_nil
    end

    it "should return the base directory if asked for a nil path" do
      base = File.join(path, dirname)
      Puppet::FileSystem.expects(:exist?).with(base).returns true
      mod.send(filetype.to_s.sub(/s$/, ''), nil).should == base
    end
  end

  it "should return the path to the plugin directory" do
    mod.plugin_directory.should == File.join(path, "lib")
  end
end

describe Puppet::Module, "when finding matching manifests" do
  before do
    @mod = Puppet::Module.new("mymod", "/a", mock("environment"))
    @pq_glob_with_extension = "yay/*.xx"
    @fq_glob_with_extension = "/a/manifests/#{@pq_glob_with_extension}"
  end

  it "should return all manifests matching the glob pattern" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns(%w{foo bar})
    FileTest.stubs(:directory?).returns false

    @mod.match_manifests(@pq_glob_with_extension).should == %w{foo bar}
  end

  it "should not return directories" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns(%w{foo bar})

    FileTest.expects(:directory?).with("foo").returns false
    FileTest.expects(:directory?).with("bar").returns true
    @mod.match_manifests(@pq_glob_with_extension).should == %w{foo}
  end

  it "should default to the 'init' file if no glob pattern is specified" do
    Puppet::FileSystem.expects(:exist?).with("/a/manifests/init.pp").returns(true)
    Puppet::FileSystem.expects(:exist?).with("/a/manifests/init.rb").returns(false)

    @mod.match_manifests(nil).should == %w{/a/manifests/init.pp}
  end

  it "should return all manifests matching the glob pattern in all existing paths" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns(%w{a b})

    @mod.match_manifests(@pq_glob_with_extension).should == %w{a b}
  end

  it "should match the glob pattern plus '.{pp,rb}' if no extention is specified" do
    Dir.expects(:glob).with("/a/manifests/yay/foo.{pp,rb}").returns(%w{yay})

    @mod.match_manifests("yay/foo").should == %w{yay}
  end

  it "should return an empty array if no manifests matched" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns([])

    @mod.match_manifests(@pq_glob_with_extension).should == []
  end

  it "should raise an error if the pattern tries to leave the manifest directory" do
    expect do
      @mod.match_manifests("something/../../*")
    end.to raise_error(Puppet::Module::InvalidFilePattern, 'The pattern "something/../../*" to find manifests in the module "mymod" is invalid and potentially unsafe.')
  end
end

describe Puppet::Module do
  include PuppetSpec::Files
  before do
    @modpath = tmpdir('modpath')
    @module = PuppetSpec::Modules.create('mymod', @modpath)
  end

  it "should use 'License' in its current path as its metadata file" do
    @module.license_file.should == "#{@modpath}/mymod/License"
  end

  it "should cache the license file" do
    @module.expects(:path).once.returns nil
    @module.license_file
    @module.license_file
  end

  it "should use 'metadata.json' in its current path as its metadata file" do
    @module.metadata_file.should == "#{@modpath}/mymod/metadata.json"
  end

  it "should have metadata if it has a metadata file and its data is not empty" do
    Puppet::FileSystem.expects(:exist?).with(@module.metadata_file).returns true
    File.stubs(:read).with(@module.metadata_file).returns "{\"foo\" : \"bar\"}"

    @module.should be_has_metadata
  end

  it "should have metadata if it has a metadata file and its data is not empty" do
    Puppet::FileSystem.expects(:exist?).with(@module.metadata_file).returns true
    File.stubs(:read).with(@module.metadata_file).returns "{\"foo\" : \"bar\"}"

    @module.should be_has_metadata
  end

  it "should not have metadata if has a metadata file and its data is empty" do
    Puppet::FileSystem.expects(:exist?).with(@module.metadata_file).returns true
    File.stubs(:read).with(@module.metadata_file).returns "/*
+-----------------------------------------------------------------------+
|                                                                       |
|                    ==> DO NOT EDIT THIS FILE! <==                     |
|                                                                       |
|   You should edit the `Modulefile` and run `puppet-module build`      |
|   to generate the `metadata.json` file for your releases.             |
|                                                                       |
+-----------------------------------------------------------------------+
*/

{}"

    @module.should_not be_has_metadata
  end

  it "should know if it is missing a metadata file" do
    Puppet::FileSystem.expects(:exist?).with(@module.metadata_file).returns false

    @module.should_not be_has_metadata
  end

  it "should be able to parse its metadata file" do
    @module.should respond_to(:load_metadata)
  end

  it "should parse its metadata file on initialization if it is present" do
    Puppet::Module.any_instance.expects(:has_metadata?).returns true
    Puppet::Module.any_instance.expects(:load_metadata)

    Puppet::Module.new("yay", "/path", mock("env"))
  end

  it "should tolerate failure to parse" do
    Puppet::FileSystem.expects(:exist?).with(@module.metadata_file).returns true
    File.stubs(:read).with(@module.metadata_file).returns(my_fixture('trailing-comma.json'))

    @module.has_metadata?.should be_false
  end

  def a_module_with_metadata(data)
    text = data.to_pson

    mod = Puppet::Module.new("foo", "/path", mock("env"))
    mod.stubs(:metadata_file).returns "/my/file"
    File.stubs(:read).with("/my/file").returns text
    mod
  end

  describe "when loading the metadata file" do
    before do
      @data = {
        :license       => "GPL2",
        :author        => "luke",
        :version       => "1.0",
        :source        => "http://foo/",
        :puppetversion => "0.25",
        :dependencies  => []
      }
      @module = a_module_with_metadata(@data)
    end

    %w{source author version license}.each do |attr|
      it "should set #{attr} if present in the metadata file" do
        @module.load_metadata
        @module.send(attr).should == @data[attr.to_sym]
      end

      it "should fail if #{attr} is not present in the metadata file" do
        @data.delete(attr.to_sym)
        @text = @data.to_pson
        File.stubs(:read).with("/my/file").returns @text
        lambda { @module.load_metadata }.should raise_error(
          Puppet::Module::MissingMetadata,
          "No #{attr} module metadata provided for foo"
        )
      end
    end

    it "should set puppetversion if present in the metadata file" do
      @module.load_metadata
      @module.puppetversion.should == @data[:puppetversion]
    end

    context "when versionRequirement is used for dependency version info" do
      before do
        @data = {
          :license       => "GPL2",
          :author        => "luke",
          :version       => "1.0",
          :source        => "http://foo/",
          :puppetversion => "0.25",
          :dependencies  => [
            {
              "versionRequirement" => "0.0.1",
              "name" => "pmtacceptance/stdlib"
            },
            {
              "versionRequirement" => "0.1.0",
              "name" => "pmtacceptance/apache"
            }
          ]
        }
        @module = a_module_with_metadata(@data)
      end

      it "should set the dependency version_requirement key" do
        @module.load_metadata
        @module.dependencies[0]['version_requirement'].should == "0.0.1"
      end

      it "should set the version_requirement key for all dependencies" do
        @module.load_metadata
        @module.dependencies[0]['version_requirement'].should == "0.0.1"
        @module.dependencies[1]['version_requirement'].should == "0.1.0"
      end
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
    Puppet::ModuleTool::Checksums.new(foo_path).checksum(foo_path).should_not == foo_checksum
    checksummed_module.has_local_changes?.should be_true

    IO.binwrite(foo_path, 'foo')

    Puppet::ModuleTool::Checksums.new(foo_path).checksum(foo_path).should == foo_checksum
    checksummed_module.has_local_changes?.should be_false
  end

  it "should know what other modules require it" do
    env = Puppet::Node::Environment.create(:testing, [@modpath])

    dependable = PuppetSpec::Modules.create(
      'dependable',
      @modpath,
      :metadata => {:author => 'puppetlabs'},
      :environment => env
    )
    PuppetSpec::Modules.create(
      'needy',
      @modpath,
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
      @modpath,
      :metadata => {
        :author => 'spoiled',
        :dependencies => [{
            "version_requirement" => "< 5.0.0",
            "name" => "puppetlabs/dependable"
        }]
      },
      :environment => env
    )
    dependable.required_by.should =~ [
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
    ]
  end
end
