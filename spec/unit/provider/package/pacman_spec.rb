#! /usr/bin/env ruby
require 'spec_helper'
require 'stringio'


describe Puppet::Type.type(:package).provider(:pacman) do
  let(:no_extra_options) { { :failonfail => true, :combine => true, :custom_environment => {} } }
  let(:executor) { Puppet::Util::Execution }
  let(:resolver) { Puppet::Util }

  let(:resource) { Puppet::Type.type(:package).new(:name => 'package', :provider => 'pacman') }
  let(:provider) { described_class.new(resource) }

  before do
    resolver.stubs(:which).with('/usr/bin/pacman').returns('/usr/bin/pacman')
    described_class.stubs(:which).with('/usr/bin/pacman').returns('/usr/bin/pacman')
    resolver.stubs(:which).with('/usr/bin/yaourt').returns('/usr/bin/yaourt')
    described_class.stubs(:which).with('/usr/bin/yaourt').returns('/usr/bin/yaourt')
    provider.stubs(:group?).returns(false)
  end

  describe "when installing" do
    before do
      provider.stubs(:query).returns({
        :ensure => '1.0'
      })
    end

    it "should call pacman to install the right package quietly when yaourt is not installed" do
      described_class.stubs(:yaourt?).returns(false)
      args = ['--noconfirm', '--needed', '--noprogressbar', '-Sy', resource[:name]]
      provider.expects(:pacman).at_least_once.with(*args).returns ''
      provider.install
    end

    it "should call yaourt to install the right package quietly when yaourt is installed" do
      described_class.stubs(:yaourt?).returns(true)
      args = ['--noconfirm', '--needed', '-S', resource[:name]]
      provider.expects(:yaourt).at_least_once.with(*args).returns ''
      provider.install
    end

    it "should raise a Puppet:Error if the installation failed" do
      executor.stubs(:execute).returns("")
      provider.expects(:query).returns(nil)

      lambda { provider.install }.should raise_error(Puppet::Error)
    end

    it "should raise an Puppet::Error when trying to install a group and allow_virtual is false" do
      provider.stubs(:group?).returns(true)
      resource.stubs(:allow_virtual?).returns(false)
      described_class.stubs(:yaourt?).returns(false)
      lambda { provider.install }.should raise_error(Puppet::Error)
    end

    it "should not raise an Puppet::Error when trying to install a group and allow_virtual is true" do
      provider.stubs(:group?).returns(true)
      resource.stubs(:allow_virtual?).returns(true)
      described_class.stubs(:yaourt?).returns(false)
      executor.stubs(:execute).returns("")
      # should not raise error
      provider.install
    end

    describe "and install_options are given" do
      before do
        resource[:install_options] = ['-x', {'--arg' => 'value'}]
      end

      it "should call pacman to install the right package quietly when yaourt is not installed" do
        described_class.stubs(:yaourt?).returns(false)
        args = ['--noconfirm', '--needed', '--noprogressbar', '-x', '--arg=value', '-Sy', resource[:name]]
        provider.expects(:pacman).at_least_once.with(*args).returns ''
        provider.install
      end

      it "should call yaourt to install the right package quietly when yaourt is installed" do
        described_class.stubs(:yaourt?).returns(true)
        args = ['--noconfirm', '--needed', '-x', '--arg=value', '-S', resource[:name]]
        provider.expects(:yaourt).at_least_once.with(*args).returns ''
        provider.install
      end
    end

    context "when :source is specified" do
      let(:install_seq) { sequence("install") }

      context "recognizable by pacman" do
        %w{
          /some/package/file
          http://some.package.in/the/air
          ftp://some.package.in/the/air
        }.each do |source|
          it "should install #{source} directly" do
            resource[:source] = source

            executor.expects(:execute).
              with(all_of(includes("-Sy"), includes("--noprogressbar")), no_extra_options).
              in_sequence(install_seq).
              returns("")

            executor.expects(:execute).
              with(all_of(includes("-U"), includes(source)), no_extra_options).
              in_sequence(install_seq).
              returns("")

            provider.install
          end
        end
      end

      context "as a file:// URL" do
        let(:actual_file_path) { "/some/package/file" }

        before do
          resource[:source] = "file:///some/package/file"
        end

        it "should install from the path segment of the URL" do
          executor.expects(:execute).
            with(all_of(includes("-Sy"),
                        includes("--noprogressbar"),
                        includes("--noconfirm")),
                 no_extra_options).
            in_sequence(install_seq).
            returns("")

          executor.expects(:execute).
            with(all_of(includes("-U"), includes(actual_file_path)), no_extra_options).
            in_sequence(install_seq).
            returns("")

          provider.install
        end
      end

      context "as a puppet URL" do
        before do
          resource[:source] = "puppet://server/whatever"
        end

        it "should fail" do
          lambda { provider.install }.should raise_error(Puppet::Error)
        end
      end

      context "as a malformed URL" do
        before do
          resource[:source] = "blah://"
        end

        it "should fail" do
          lambda { provider.install }.should raise_error(Puppet::Error)
        end
      end
    end
  end

  describe "when updating" do
    it "should call install" do
      provider.expects(:install).returns("install return value")
      provider.update.should == "install return value"
    end
  end

  describe "when uninstalling" do
    it "should call pacman to remove the right package quietly" do
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-R", resource[:name]]
      executor.expects(:execute).with(args, no_extra_options).returns ""
      provider.uninstall
    end

    it "adds any uninstall_options" do
      resource[:uninstall_options] = ['-x', {'--arg' => 'value'}]
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-x", "--arg=value", "-R", resource[:name]]
      executor.expects(:execute).with(args, no_extra_options).returns ""
      provider.uninstall
    end
  end

  describe "when querying" do

    it "should return the version" do
      executor.
        expects(:execpipe).
        with(["/usr/bin/pacman", "-Q"]).yields(<<EOF)
otherpackage 1.2.3.4
package 1.01.3-2
yetanotherpackage 1.2.3.4
EOF

      provider.query.should == { :ensure => "1.01.3-2" }
    end

    it "should return a hash indicating that the package is missing" do
      executor.expects(:execpipe).yields("")
      provider.query.should == {
        :ensure => :absent,
        :status => 'missing',
        :name => resource[:name],
        :error => 'ok',
      }
    end

    it "should return a hash indicating that the package is missing on error" do
      executor.expects(:execpipe).raises(Puppet::ExecutionFailure.new("ERROR!"))

      lambda { provider.query }.should raise_error(RuntimeError)
    end

    it "should warn when querying a group and allow_virtual is false" do
      provider.stubs(:group?).returns(true)
      resource.stubs(:allow_virtual?).returns(false)
      provider.expects(:warning)
      provider.query
    end

    it "should not warn when querying a group and allow_virtual is true" do
      provider.stubs(:group?).returns(true)
      resource.stubs(:allow_virtual?).returns(false)
      described_class.expects(:warning).never
      provider.query
    end
  end

  describe "when determining instances" do
    it "should retrieve installed packages and groups" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q'])
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Qg'])
      described_class.instances
    end

    it "should return installed packages" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q']).yields(StringIO.new("package1 1.23-4\npackage2 2.00\n"))
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Qg']).yields("")
      instances = described_class.instances

      instances.length.should == 2

      instances[0].properties.should == {
        :provider => :pacman,
        :ensure => '1.23-4',
        :name => 'package1'
      }

      instances[1].properties.should == {
        :provider => :pacman,
        :ensure => '2.00',
        :name => 'package2'
      }
    end

    it "should return completely installed groups with a virtual version together with packages" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q']).yields(<<EOF)
package1 1.00
package2 1.00
EOF
      # -Qg: What is currently installed
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Qg']).yields(<<EOF)
group1 package1
group1 package2
EOF
      # -Sg: All packages belonging to a group. group1 is completly installed
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Sg', 'group1']).yields(<<EOF)
group1 package1
group1 package2
EOF
      instances = described_class.instances

      instances.length.should == 3

      instances[0].properties.should == {
        :provider => :pacman,
        :ensure   => '1.00',
        :name     => 'package1'
      }
      instances[1].properties.should == {
        :provider => :pacman,
        :ensure   => '1.00',
        :name     => 'package2'
      }
      instances[2].properties.should == {
        :provider => :pacman,
        :ensure   => "\npackage1 1.00\npackage2 1.00\n",
        :name     => 'group1'
      }
    end

    it "should not return partially installed packages" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q']).yields(<<EOF)
package1 1.00
EOF
      # -Qg: What is currently installed
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Qg']).yields(<<EOF)
group1 package1
EOF
      # -Sg: All packages belonging to a group. group1 is completly installed
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Sg', 'group1']).yields(<<EOF)
group1 package1
group1 package2
EOF
      instances = described_class.instances

      instances.length.should == 1

      instances[0].properties.should == {
        :provider => :pacman,
        :ensure   => '1.00',
        :name     => 'package1'
      }
    end

    it "should sort package names in virtual group versions" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Sg', 'group1']).yields(<<EOF)
group1 aa
group1 b
group1 a
EOF
      package_versions= {
        'a' => '1',
        'aa' => '1',
        'b' => '1',
      }

      virtual_group_version = described_class.get_virtual_group_version("group1", package_versions)
      virtual_group_version.should == ["\na 1\naa 1\nb 1\n", true]
    end

    it "should return nil on error" do
      described_class.expects(:execpipe).raises(Puppet::ExecutionFailure.new("ERROR!"))
      lambda { described_class.instances }.should raise_error(RuntimeError)
    end

    it "should warn on invalid input" do
      described_class.expects(:execpipe).twice.yields(StringIO.new("blah"))
      described_class.expects(:warning).with("Failed to match line 'blah'")
      described_class.instances.should == []
    end
  end

  describe "when determining the latest version" do
    it "should refresh package list" do
      get_latest_version = sequence("get_latest_version")
      executor.
        expects(:execute).
        in_sequence(get_latest_version).
        with(['/usr/bin/pacman', '-Sy'], no_extra_options)

      executor.
        stubs(:execute).
        in_sequence(get_latest_version).
        returns("")

      provider.latest
    end

    it "should get query pacman for the latest version" do
      get_latest_version = sequence("get_latest_version")
      executor.
        stubs(:execute).
        in_sequence(get_latest_version)

      executor.
        expects(:execute).
        in_sequence(get_latest_version).
        with(['/usr/bin/pacman', '-Sp', '--print-format', '%v', resource[:name]], no_extra_options).
        returns("")

      provider.latest
    end

    it "should return the version number from pacman" do
      executor.
        expects(:execute).
        at_least_once().
        returns("1.00.2-3\n")

      provider.latest.should == "1.00.2-3"
    end

    it "should return a virtual group version when resource is a package group" do
      provider.stubs(:group?).returns(true)
      get_latest_version = sequence("get_latest_version")
      executor.
        stubs(:execute).
        with(['/usr/bin/pacman', '-Sy'], no_extra_options).
        in_sequence(get_latest_version)

      executor.
        expects(:execute).
        in_sequence(get_latest_version).
        with(['/usr/bin/pacman', '-Sp', '--print-format', '%n %v', resource[:name]], no_extra_options).
        returns(<<EOF)
package2 1.0.1
package1 1.0.0
EOF
      # The virtual group version is the package list prepended with \n and sorted in format <package> <version>
      provider.latest.should == <<EOF

package1 1.0.0
package2 1.0.1
EOF
    end
  end
end
