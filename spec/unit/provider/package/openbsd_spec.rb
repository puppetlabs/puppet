#!/usr/bin/env rspec
require 'spec_helper'
require 'stringio'

provider_class = Puppet::Type.type(:package).provider(:openbsd)

describe provider_class do
  subject { provider_class }

  def package(args = {})
    defaults = { :name => 'bash', :provider => 'openbsd' }
    Puppet::Type.type(:package).new(defaults.merge(args))
  end

  before :each do
    # Stub some provider methods to avoid needing the actual software
    # installed, so we can test on whatever platform we want.
    provider_class.stubs(:command).with(:pkginfo).returns('/bin/pkg_info')
    provider_class.stubs(:command).with(:pkgadd).returns('/bin/pkg_add')
    provider_class.stubs(:command).with(:pkgdelete).returns('/bin/pkg_delete')
  end

  context "::instances" do
    it "should return nil if execution failed" do
      subject.expects(:execpipe).raises(Puppet::ExecutionFailure, 'wawawa')
      subject.instances.should be_nil
    end

    it "should return the empty set if no packages are listed" do
      subject.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(StringIO.new(''))
      subject.instances.should be_empty
    end

    it "should return all packages when invoked" do
      fixture = File.new(my_fixture('pkginfo.list'))
      subject.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(fixture)
      subject.instances.map(&:name).sort.should ==
        %w{bash bzip2 expat gettext libiconv lzo openvpn python vim wget}.sort
    end
  end

  context "#install" do
    it "should fail if the resource doesn't have a source" do
      provider = subject.new(package())
      expect { provider.install }.
        to raise_error Puppet::Error, /must specify a package source/
    end

    it "should install correctly when given a directory-unlike source" do
      ENV.should_not be_key 'PKG_PATH'

      source = '/whatever.pkg'
      provider = subject.new(package(:source => source))
      provider.expects(:pkgadd).with do |name|
        ENV.should_not be_key 'PKG_PATH'
        name == source
      end

      provider.install
      ENV.should_not be_key 'PKG_PATH'
    end

    it "should install correctly when given a directory-like source" do
      ENV.should_not be_key 'PKG_PATH'

      source = '/whatever/'
      provider = subject.new(package(:source => source))
      provider.expects(:pkgadd).with do |name|
        ENV.should be_key 'PKG_PATH'
        ENV['PKG_PATH'].should == source

        name == provider.resource[:name]
      end

      provider.install
      ENV.should_not be_key 'PKG_PATH'
    end
  end

  context "#get_version" do
    it "should return nil if execution fails" do
      provider = subject.new(package)
      provider.expects(:execpipe).raises(Puppet::ExecutionFailure, 'wawawa')
      provider.get_version.should be_nil
    end

    it "should return the package version if in the output" do
      fixture = File.new(my_fixture('pkginfo.list'))
      provider = subject.new(package(:name => 'bash'))
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I bash}).yields(fixture)
      provider.get_version.should == '3.1.17'
    end

    it "should return the empty string if the package is not present" do
      provider = subject.new(package(:name => 'zsh'))
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I zsh}).yields(StringIO.new(''))
      provider.get_version.should == ''
    end
  end

  context "#query" do
    it "should return the installed version if present" do
      fixture = File.read(my_fixture('pkginfo.detail'))
      provider = subject.new(package(:name => 'bash'))
      provider.expects(:pkginfo).with('bash').returns(fixture)
      provider.query.should == { :ensure => '3.1.17' }
    end

    it "should return nothing if not present" do
      provider = subject.new(package(:name => 'zsh'))
      provider.expects(:pkginfo).with('zsh').returns('')
      provider.query.should be_nil
    end
  end
end
