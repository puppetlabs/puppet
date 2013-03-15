require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'
require 'semver'

describe Puppet::ModuleTool::Applications::Installer, :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  before do
    FileUtils.mkdir_p(modpath1)
    fake_env.modulepath = [modpath1]
    FileUtils.touch(stdlib_pkg)
    Puppet.settings[:modulepath] = modpath1
  end

  let(:unpacker)        { stub(:run) }
  let(:installer_class) { Puppet::ModuleTool::Applications::Installer }
  let(:modpath1)        { File.join(tmpdir("installer"), "modpath1") }
  let(:stdlib_pkg)      { File.join(modpath1, "pmtacceptance-stdlib-0.0.1.tar.gz") }
  let(:fake_env)        { Puppet::Node::Environment.new('fake_env') }
  let(:options)         { { :target_dir => modpath1 } }

  let(:forge) do
    forge = mock("Puppet::Forge")

    forge.stubs(:multiple_remote_dependency_info).returns(remote_dependency_info)
    forge.stubs(:uri).returns('forge-dev.puppetlabs.com')
    remote_dependency_info.each_key do |mod|
      remote_dependency_info[mod].each do |release|
        forge.stubs(:retrieve).with(release['file']).returns("/fake_cache#{release['file']}")
      end
    end

    forge
  end

  let(:install_dir) do
    install_dir = mock("Puppet::ModuleTool::InstallDirectory")
    install_dir.stubs(:prepare)
    Puppet::ModuleTool::InstallDirectory.stubs(:new).returns(install_dir)
    install_dir
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
            ["pmtacceptance/java", "1.7.1"],
            ["pmtacceptance/stdlib", "0.0.1"]
          ],
          "version" => "0.0.1",
          "file"    => "/pmtacceptance-apollo-0.0.1.tar.gz" },
        { "dependencies" => [
            ["pmtacceptance/java", ">= 1.7.0"],
            ["pmtacceptance/stdlib", ">= 1.0.0"]
          ],
          "version" => "0.0.2",
          "file"    => "/pmtacceptance-apollo-0.0.2.tar.gz" }
      ]
    }
  end

  def installer_run(*args)
    installer = installer_class.new(*args)
    installer.instance_exec(fake_env) { |environment|
      @environment = environment
    }

    installer.run
  end

  context "when the source is a repository" do
    it "should require a valid name" do
      lambda { installer_class.run('puppet', params) }.should
        raise_error(ArgumentError, "Could not install module with invalid name: puppet")
    end

    it "should install the requested module" do
      pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
        Puppet::ModuleTool::Applications::Unpacker.expects(:new).
          with('/fake_cache/pmtacceptance-stdlib-1.0.0.tar.gz', options).
          returns(unpacker)
        results = installer_run('pmtacceptance-stdlib', forge, options)
        results[:installed_modules].length.should == 1
        results[:installed_modules][0][:module].should == "pmtacceptance-stdlib"
        results[:installed_modules][0][:version][:vstring].should == "1.0.0"
      end
    end

    context "should check the target directory" do
      def expect_normal_unpacker
        Puppet::ModuleTool::Applications::Unpacker.expects(:new).
          with('/fake_cache/pmtacceptance-stdlib-1.0.0.tar.gz', options).
          returns(unpacker)
      end

      def expect_normal_results
        results
      end

      it "(#15202) prepares the install directory" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          expect_normal_unpacker
          install_dir.expects(:prepare).with("pmtacceptance-stdlib", "latest")
          results = installer_run('pmtacceptance-stdlib', forge, options)
          results[:installed_modules].length.should == 1
          results[:installed_modules][0][:module].should == "pmtacceptance-stdlib"
          results[:installed_modules][0][:version][:vstring].should == "1.0.0"
        end
      end

      it "(#15202) reports an error when the install directory cannot be prepared" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          install_dir.expects(:prepare).with("pmtacceptance-stdlib", "latest").
            raises(Puppet::ModuleTool::Errors::PermissionDeniedCreateInstallDirectoryError.new("original", :module => "pmtacceptance-stdlib"))
          results = installer_run('pmtacceptance-stdlib', forge, options)
          results[:result].should == :failure
          results[:error][:oneline].should =~ /Permission is denied/
        end
      end
    end

    context "when the requested module has dependencies" do
      it "should install dependencies" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-stdlib-1.0.0.tar.gz', options).
            returns(unpacker)
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-java-1.7.1.tar.gz', options).
            returns(unpacker)

          results = installer_run('pmtacceptance-apollo', forge, options)
          installed_dependencies = results[:installed_modules][0][:dependencies]

          dependencies = installed_dependencies.inject({}) do |result, dep|
            result[dep[:module]] = dep[:version][:vstring]
            result
          end

          dependencies.length.should == 2
          dependencies['pmtacceptance-java'].should   == '1.7.1'
          dependencies['pmtacceptance-stdlib'].should == '1.0.0'
        end
      end

      it "should install requested module if the '--force' flag is used" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :force => true, :target_dir => modpath1 }
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          results = installer_run('pmtacceptance-apollo', forge, options)
          results[:installed_modules][0][:module].should == "pmtacceptance-apollo"
        end
      end

      it "should not install dependencies if the '--force' flag is used" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :force => true, :target_dir => modpath1 }
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          results = installer_run('pmtacceptance-apollo', forge, options)
          dependencies = results[:installed_modules][0][:dependencies]
          dependencies.should == []
        end
      end

      it "should not install dependencies if the '--ignore-dependencies' flag is used" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :ignore_dependencies => true, :target_dir => modpath1 }
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          results = installer_run('pmtacceptance-apollo', forge, options)
          dependencies = results[:installed_modules][0][:dependencies]
          dependencies.should == []
        end
      end

      it "should set an error if dependencies can't be resolved" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :version => '0.0.1', :target_dir => modpath1 }
          oneline = "Could not install 'pmtacceptance-apollo' (v0.0.1); module 'pmtacceptance-stdlib' cannot satisfy dependencies"
          multiline = <<-MSG.strip
Could not install module 'pmtacceptance-apollo' (v0.0.1)
  No version of 'pmtacceptance-stdlib' will satisfy dependencies
    'pmtacceptance-apollo' (v0.0.1) requires 'pmtacceptance-stdlib' (v0.0.1)
    'pmtacceptance-java' (v1.7.1) requires 'pmtacceptance-stdlib' (v1.0.0)
    Use `puppet module install --ignore-dependencies` to install only this module
MSG

          results = installer_class.run('pmtacceptance-apollo', forge, options)
          results[:result].should == :failure
          results[:error][:oneline].should == oneline
          results[:error][:multiline].should == multiline
        end
      end
    end
  end
end
