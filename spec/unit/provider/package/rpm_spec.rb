#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:rpm)

describe provider_class do
  subject { provider_class }

  let (:packages) do
    <<-RPM_OUTPUT
    cracklib-dicts 0 2.8.9 3.3 x86_64 :DESC: The standard CrackLib dictionaries
    basesystem 0 8.0 5.1.1.el5.centos noarch :DESC: The skeleton package which defines a simple Red Hat Enterprise Linux system
    chkconfig 0 1.3.30.2 2.el5 x86_64 :DESC: A system tool for maintaining the /etc/rc*.d hierarchy
    myresource 0 1.2.3.4 5.el4 noarch :DESC: Now with summary
    mysummaryless 0 1.2.3.4 5.el4 noarch :DESC:
    RPM_OUTPUT
  end

  let(:resource_name) { 'myresource' }
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => resource_name,
      :ensure   => :installed
    )
  end

  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  let(:nevra_format) { %Q{'%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH} :DESC: %{SUMMARY}\\n'} }
  let(:execute_options) do
    {:failonfail => true, :combine => true, :custom_environment => {}}
  end
  let(:rpm_version) { "RPM version 5.0.0\n" }

  before(:each) do
    Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
    subject.stubs(:which).with("rpm").returns("/bin/rpm")
    subject.instance_variable_set("@current_version", nil)
    Puppet::Type::Package::ProviderRpm.expects(:execute).with(["/bin/rpm", "--version"]).returns(rpm_version).at_most_once
    Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "--version"], execute_options).returns(rpm_version).at_most_once
  end

  describe "self.instances" do
    describe "with a modern version of RPM" do
      it "should include all the modern flags" do
        Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf #{nevra_format}").yields(packages)

        installed_packages = subject.instances
      end
    end

    describe "with a version of RPM < 4.1" do
      let(:rpm_version) { "RPM version 4.0.2\n" }
      it "should exclude the --nosignature flag" do
        Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa  --nodigest --qf #{nevra_format}").yields(packages)

        installed_packages = subject.instances
      end
    end

    describe "with a version of RPM < 4.0.2" do
      let(:rpm_version) { "RPM version 3.0.5\n" }
      it "should exclude the --nodigest flag" do
        Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa   --qf #{nevra_format}").yields(packages)

        installed_packages = subject.instances
      end
    end

    it "returns an array of packages" do
      Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf #{nevra_format}").yields(packages)

      installed_packages = subject.instances

      installed_packages[0].properties.should ==
        {
          :provider => :rpm,
          :name => "cracklib-dicts",
          :epoch => "0",
          :version => "2.8.9",
          :release => "3.3",
          :arch => "x86_64",
          :ensure => "2.8.9-3.3",
          :description => "The standard CrackLib dictionaries",
        }
      installed_packages[1].properties.should ==
        {
          :provider => :rpm,
          :name => "basesystem",
          :epoch => "0",
          :version => "8.0",
          :release => "5.1.1.el5.centos",
          :arch => "noarch",
          :ensure => "8.0-5.1.1.el5.centos",
          :description => "The skeleton package which defines a simple Red Hat Enterprise Linux system",
        }
      installed_packages[2].properties.should ==
        {
          :provider => :rpm,
          :name => "chkconfig",
          :epoch => "0",
          :version => "1.3.30.2",
          :release => "2.el5",
          :arch => "x86_64",
          :ensure => "1.3.30.2-2.el5",
          :description => "A system tool for maintaining the /etc/rc*.d hierarchy",
        }
      installed_packages.last.properties.should ==
        {
          :provider    => :rpm,
          :name        => "mysummaryless",
          :epoch       => "0",
          :version     => "1.2.3.4",
          :release     => "5.el4",
          :arch        => "noarch",
          :ensure      => "1.2.3.4-5.el4",
          :description => "",
        }
    end
  end

  describe "#install" do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed,
        :source   => '/path/to/package'
      )
    end

    describe "when not already installed" do
      it "should only include the '-i' flag" do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-i", '/path/to/package'], execute_options)
        provider.install
      end
   end

   describe "when an older version is installed" do
     before(:each) do
       # Force the provider to think a version of the package is already installed
       # This is real hacky. I'm sorry.  --jeffweiss 25 Jan 2013
       provider.instance_variable_get('@property_hash')[:ensure] = '1.2.3.3'
     end

     it "should include the '-U --oldpackage' flags" do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", ["-U", "--oldpackage"], '/path/to/package'], execute_options)
        provider.install
     end
   end
  end

  describe "#latest" do
    it "should retrieve version string after querying rpm for version from source file" do
      resource.expects(:[]).with(:source).returns('source-string')
      Puppet::Util::Execution.expects(:execfail).with(["/bin/rpm", "-q", "--qf", nevra_format, "-p", "source-string"], Puppet::Error).returns("myresource 0 1.2.3.4 5.el4 noarch :DESC:\n")
      provider.latest.should == "1.2.3.4-5.el4"
    end
  end

  describe "#uninstall" do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed
      )
    end

    describe "on a modern RPM" do
      before(:each) do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-q",  "myresource", '--nosignature', '--nodigest', "--qf", nevra_format], execute_options).returns("myresource 0 1.2.3.4 5.el4 noarch :DESC:\n")
      end

      let(:rpm_version) { "RPM version 4.10.0\n" }

      it "should include the architecture in the package name" do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-e", 'myresource-1.2.3.4-5.el4.noarch'], execute_options).returns('').at_most_once
        provider.uninstall
      end
    end

    describe "on an ancient RPM" do
      before(:each) do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-q",  "myresource", '', '', '--qf', nevra_format], execute_options).returns("myresource 0 1.2.3.4 5.el4 noarch :DESC:\n")
      end

      let(:rpm_version) { "RPM version 3.0.6\n" }

      it "should exclude the architecture from the package name" do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-e", 'myresource-1.2.3.4-5.el4'], execute_options).returns('').at_most_once
        provider.uninstall
      end
    end

  end

  describe "parsing" do
    let(:resource_name) { 'name' }

    def parser_test(rpm_output_string, gold_hash, number_of_warnings = 0)
      Puppet.expects(:warning).times(number_of_warnings)
      Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-q", resource_name, "--nosignature", "--nodigest", "--qf", nevra_format], execute_options).returns(rpm_output_string)
      provider.query.should == gold_hash
    end

    ['name', 'epoch', 'version', 'release', 'arch'].each do |field|
      let('delimiter') { ':DESC:' }
      let(:package_hash) do
        {
          :name => 'name',
          :epoch => 'epoch',
          :version => 'version',
          :release => 'release',
          :arch => 'arch',
          :description => 'a description',
          :provider => :rpm,
          :ensure => 'version-release',
        }
      end
      let(:line) { 'name epoch version release arch :DESC: a description' }

      it "should still parse if #{field} is replaced by delimiter" do
        parser_test(
          line.gsub(field, delimiter),
          package_hash.merge(
            field.to_sym => delimiter,
            :ensure => 'version-release'.gsub(field, delimiter)
          )
        )
      end

    end

    it "should still parse if missing description" do
      parser_test(
        line.gsub(/#{delimiter} .+$/, delimiter),
        package_hash.merge(:description => '')
      )
    end

    it "should still parse if description contains a new line" do
      parser_test(
        line.gsub(/#{delimiter} .+$/, "#{delimiter} whoops\nnewline"),
        package_hash.merge(:description => 'whoops')
      )
    end

    it "should warn but not fail if line is unparseable" do
      parser_test('bad data', {}, 1)
    end
  end

  describe ".nodigest" do
    { '4.0'   => nil,
      '4.0.1' => nil,
      '4.0.2' => '--nodigest',
      '4.0.3' => '--nodigest',
      '4.1'   => '--nodigest',
      '5'     => '--nodigest',
    }.each do |version, expected|
      describe "when current version is #{version}" do
        it "should return #{expected.inspect}" do
          subject.stubs(:current_version).returns(version)
          subject.nodigest.should == expected
        end
      end
    end
  end

  describe ".nosignature" do
    { '4.0.3' => nil,
      '4.1'   => '--nosignature',
      '4.1.1' => '--nosignature',
      '4.2'   => '--nosignature',
      '5'     => '--nosignature',
    }.each do |version, expected|
      describe "when current version is #{version}" do
        it "should return #{expected.inspect}" do
          subject.stubs(:current_version).returns(version)
          subject.nosignature.should == expected
        end
      end
    end
  end
end
