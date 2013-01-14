#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:rpm)

describe provider_class do
  subject { provider_class }

  let (:packages) do
    <<-RPM_OUTPUT
    cracklib-dicts 0 2.8.9 3.3 x86_64
    basesystem 0 8.0 5.1.1.el5.centos noarch
    chkconfig 0 1.3.30.2 2.el5 x86_64
    RPM_OUTPUT
  end

  describe "self.instances" do
    it "returns an array of packages" do
      Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "--version"], {:failonfail => true, :combine => true, :custom_environment => {}}).returns("RPM version 5.x")
      Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
      subject.stubs(:which).with("rpm").returns("/bin/rpm")
      Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf '%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n'").yields(packages)

      installed_packages = subject.instances

      installed_packages[0].properties.should ==
        {
          :provider => :rpm,
          :name => "cracklib-dicts",
          :epoch => "0",
          :version => "2.8.9",
          :release => "3.3",
          :arch => "x86_64",
          :ensure => "2.8.9-3.3"
        }
      installed_packages[1].properties.should ==
        {
          :provider => :rpm,
          :name => "basesystem",
          :epoch => "0",
          :version => "8.0",
          :release => "5.1.1.el5.centos",
          :arch => "noarch",
          :ensure => "8.0-5.1.1.el5.centos"
        }
      installed_packages[2].properties.should ==
        {
          :provider => :rpm,
          :name => "chkconfig",
          :epoch => "0",
          :version => "1.3.30.2",
          :release => "2.el5",
          :arch => "x86_64",
          :ensure => "1.3.30.2-2.el5"
        }
    end
  end
end
