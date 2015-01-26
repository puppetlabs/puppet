require 'spec_helper'
require 'puppet/module_tool/install_directory'

describe Puppet::ModuleTool::InstallDirectory do
  def expect_normal_results
    results = installer.run
    expect(results[:installed_modules].length).to eq 1
    expect(results[:installed_modules][0][:module]).to eq("pmtacceptance-stdlib")
    expect(results[:installed_modules][0][:version][:vstring]).to eq("1.0.0")
    results
  end

  it "(#15202) creates the install directory" do
    target_dir = the_directory('foo', :directory? => false, :exist? => false)
    target_dir.expects(:mkpath)

    install = Puppet::ModuleTool::InstallDirectory.new(target_dir)

    install.prepare('pmtacceptance-stdlib', '1.0.0')
  end

  it "(#15202) errors when the directory is not accessible" do
    target_dir = the_directory('foo', :directory? => false, :exist? => false)
    target_dir.expects(:mkpath).raises(Errno::EACCES)

    install = Puppet::ModuleTool::InstallDirectory.new(target_dir)

    expect {
      install.prepare('module', '1.0.1')
    }.to raise_error(
      Puppet::ModuleTool::Errors::PermissionDeniedCreateInstallDirectoryError
    )
  end

  it "(#15202) errors when an entry along the path is not a directory" do
    target_dir = the_directory("foo/bar", :exist? => false, :directory? => false)
    target_dir.expects(:mkpath).raises(Errno::EEXIST)

    install = Puppet::ModuleTool::InstallDirectory.new(target_dir)

    expect {
      install.prepare('module', '1.0.1')
    }.to raise_error(Puppet::ModuleTool::Errors::InstallPathExistsNotDirectoryError)
  end

  it "(#15202) simply re-raises an unknown error" do
    target_dir = the_directory("foo/bar", :exist? => false, :directory? => false)
    target_dir.expects(:mkpath).raises("unknown error")

    install = Puppet::ModuleTool::InstallDirectory.new(target_dir)

    expect { install.prepare('module', '1.0.1') }.to raise_error("unknown error")
  end

  it "(#15202) simply re-raises an unknown system call error" do
    target_dir = the_directory("foo/bar", :exist? => false, :directory? => false)
    target_dir.expects(:mkpath).raises(SystemCallError, "unknown")

    install = Puppet::ModuleTool::InstallDirectory.new(target_dir)

    expect { install.prepare('module', '1.0.1') }.to raise_error(SystemCallError)
  end

  def the_directory(name, options)
    dir = mock("Pathname<#{name}>")
    dir.stubs(:exist?).returns(options.fetch(:exist?, true))
    dir.stubs(:directory?).returns(options.fetch(:directory?, true))
    dir
  end
end
