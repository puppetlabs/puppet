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
    described_class.stubs(:group?).returns(false)
    described_class.stubs(:yaourt?).returns(false)
  end

  describe "when installing" do
    before do
      provider.stubs(:query).returns({
        :ensure => '1.0'
      })
    end

    it "should call pacman to install the right package quietly when yaourt is not installed" do
      args = ['--noconfirm', '--needed', '--noprogressbar', '-Sy', resource[:name]]
      provider.expects(:pacman).at_least_once.with(*args).returns ''
      provider.install
    end

    it "should call yaourt to install the right package quietly when yaourt is installed" do
      described_class.stubs(:yaourt?).returns(true)
      args = ['--noconfirm', '--needed', '--noprogressbar', '-Sy', resource[:name]]
      provider.expects(:yaourt).at_least_once.with(*args).returns ''
      provider.install
    end

    it "should raise an Puppet::Error if the installation failed" do
      executor.stubs(:execute).returns("")
      provider.expects(:query).returns(nil)

      expect {
        provider.install
      }.to raise_exception(Puppet::Error, /Could not find package/)
    end

    it "should raise an Puppet::Error when trying to install a group and allow_virtual is false" do
      described_class.stubs(:group?).returns(true)
      resource[:allow_virtual] = false
      expect {
        provider.install
      }.to raise_error(Puppet::Error, /Refusing to install package group/)
    end

    it "should not raise an Puppet::Error when trying to install a group and allow_virtual is true" do
      described_class.stubs(:group?).returns(true)
      resource[:allow_virtual] = true
      executor.stubs(:execute).returns("")
      provider.install
    end

    describe "and install_options are given" do
      before do
        resource[:install_options] = ['-x', {'--arg' => 'value'}]
      end

      it "should call pacman to install the right package quietly when yaourt is not installed" do
        args = ['--noconfirm', '--needed', '--noprogressbar', '-x', '--arg=value', '-Sy', resource[:name]]
        provider.expects(:pacman).at_least_once.with(*args).returns ''
        provider.install
      end

      it "should call yaourt to install the right package quietly when yaourt is installed" do
        described_class.stubs(:yaourt?).returns(true)
        args = ['--noconfirm', '--needed', '--noprogressbar', '-x', '--arg=value', '-Sy', resource[:name]]
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
          expect {
            provider.install
          }.to raise_error(Puppet::Error, /puppet:\/\/ URL is not supported/)
        end
      end

      context "as an unsupported URL scheme" do
        before do
          resource[:source] = "blah://foo.com"
        end

        it "should fail" do
          expect {
            provider.install
          }.to raise_error(Puppet::Error, /Source blah:\/\/foo\.com is not supported/)
        end
      end
    end
  end

  describe "when updating" do
    it "should call install" do
      provider.expects(:install).returns("install return value")
      expect(provider.update).to eq("install return value")
    end
  end

  describe "when uninstalling" do
    it "should call pacman to remove the right package quietly" do
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-R", resource[:name]]
      executor.expects(:execute).with(args, no_extra_options).returns ""
      provider.uninstall
    end

    it "should call yaourt to remove the right package quietly" do
      described_class.stubs(:yaourt?).returns(true)
      args = ["--noconfirm", "--noprogressbar", "-R", resource[:name]]
      provider.expects(:yaourt).with(*args)
      provider.uninstall
    end

    it "adds any uninstall_options" do
      resource[:uninstall_options] = ['-x', {'--arg' => 'value'}]
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-x", "--arg=value", "-R", resource[:name]]
      executor.expects(:execute).with(args, no_extra_options).returns ""
      provider.uninstall
    end

    it "should recursively remove packages when given a package group" do
      described_class.stubs(:group?).returns(true)
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-R", "-s", resource[:name]]
      executor.expects(:execute).with(args, no_extra_options).returns ""
      provider.uninstall
    end
  end

  describe "when querying" do
    it "should query pacman" do
      executor.expects(:execpipe).with(["/usr/bin/pacman", '-Q'])
      executor.expects(:execpipe).with(["/usr/bin/pacman", '-Sgg', 'package'])
      provider.query
    end

    it "should return the version" do
      executor.
          expects(:execpipe).
          with(["/usr/bin/pacman", "-Q"]).yields(<<EOF)
otherpackage 1.2.3.4
package 1.01.3-2
yetanotherpackage 1.2.3.4
EOF
      executor.expects(:execpipe).with(['/usr/bin/pacman', '-Sgg', 'package']).yields('')

      expect(provider.query).to eq({ :name => 'package', :ensure => '1.01.3-2', :provider => :pacman,  })
    end

    it "should return a hash indicating that the package is missing" do
      executor.expects(:execpipe).twice.yields("")
      expect(provider.query).to be_nil
    end

    it "should raise an error if execpipe fails" do
      executor.expects(:execpipe).raises(Puppet::ExecutionFailure.new("ERROR!"))

      expect { provider.query }.to raise_error(RuntimeError)
    end

    describe 'when querying a group' do
      before :each do
        executor.expects(:execpipe).with(['/usr/bin/pacman', '-Q']).yields('foo 1.2.3')
        executor.expects(:execpipe).with(['/usr/bin/pacman', '-Sgg', 'package']).yields('package foo')
      end

      it 'should warn when allow_virtual is false' do
        resource[:allow_virtual] = false
        provider.expects(:warning)
        provider.query
      end

      it 'should not warn allow_virtual is true' do
        resource[:allow_virtual] = true
        described_class.expects(:warning).never
        provider.query
      end
    end
  end

  describe "when determining instances" do
    it "should retrieve installed packages and groups" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q'])
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Sgg'])
      described_class.instances
    end

    it "should return installed packages" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q']).yields(StringIO.new("package1 1.23-4\npackage2 2.00\n"))
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Sgg']).yields("")
      instances = described_class.instances

      expect(instances.length).to eq(2)

      expect(instances[0].properties).to eq({
          :provider => :pacman,
          :ensure => '1.23-4',
          :name => 'package1'
      })

      expect(instances[1].properties).to eq({
          :provider => :pacman,
          :ensure => '2.00',
          :name => 'package2'
      })
    end

    it "should return completely installed groups with a virtual version together with packages" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q']).yields(<<EOF)
package1 1.00
package2 1.00
EOF
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Sgg']).yields(<<EOF)
group1 package1
group1 package2
EOF
      instances = described_class.instances

      expect(instances.length).to eq(3)

      expect(instances[0].properties).to eq({
        :provider => :pacman,
        :ensure   => '1.00',
        :name     => 'package1'
      })
      expect(instances[1].properties).to eq({
        :provider => :pacman,
        :ensure   => '1.00',
        :name     => 'package2'
      })
      expect(instances[2].properties).to eq({
        :provider => :pacman,
        :ensure   => 'package1 1.00, package2 1.00',
        :name     => 'group1'
      })
    end

    it "should not return partially installed packages" do
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Q']).yields(<<EOF)
package1 1.00
EOF
      described_class.expects(:execpipe).with(["/usr/bin/pacman", '-Sgg']).yields(<<EOF)
group1 package1
group1 package2
EOF
      instances = described_class.instances

      expect(instances.length).to eq(1)

      expect(instances[0].properties).to eq({
        :provider => :pacman,
        :ensure   => '1.00',
        :name     => 'package1'
      })
    end

    it 'should sort package names for installed groups' do
      described_class.expects(:execpipe).with(['/usr/bin/pacman', '-Sgg', 'group1']).yields(<<EOF)
group1 aa
group1 b
group1 a
EOF
      package_versions= {
        'a' => '1',
        'aa' => '1',
        'b' => '1',
      }

      virtual_group_version = described_class.get_installed_groups(package_versions, 'group1')
      expect(virtual_group_version).to eq({ 'group1' => 'a 1, aa 1, b 1' })
    end

    it "should return nil on error" do
      described_class.expects(:execpipe).raises(Puppet::ExecutionFailure.new("ERROR!"))
      expect { described_class.instances }.to raise_error(RuntimeError)
    end

    it "should warn on invalid input" do
      described_class.expects(:execpipe).twice.yields(StringIO.new("blah"))
      described_class.expects(:warning).with("Failed to match line 'blah'")
      expect(described_class.instances).to eq([])
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

      expect(provider.latest).to eq("1.00.2-3")
    end

    it "should return a virtual group version when resource is a package group" do
      described_class.stubs(:group?).returns(true)
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
      expect(provider.latest).to eq('package1 1.0.0, package2 1.0.1')
    end
  end

  describe 'when determining if a resource is a group' do
    before do
      described_class.unstub(:group?)
    end

    it 'should return false on non-zero pacman exit' do
      executor.stubs(:execute).with(['/usr/bin/pacman', '-Sg', 'git'], {:failonfail => true, :combine => true, :custom_environment => {}}).raises(Puppet::ExecutionFailure, 'error')
      expect(described_class.group?('git')).to eq(false)
    end

    it 'should return false on empty pacman output' do
      executor.stubs(:execute).with(['/usr/bin/pacman', '-Sg', 'git'], {:failonfail => true, :combine => true, :custom_environment => {}}).returns ''
      expect(described_class.group?('git')).to eq(false)
    end

    it 'should return true on non-empty pacman output' do
      executor.stubs(:execute).with(['/usr/bin/pacman', '-Sg', 'vim-plugins'], {:failonfail => true, :combine => true, :custom_environment => {}}).returns 'vim-plugins vim-a'
      expect(described_class.group?('vim-plugins')).to eq(true)
    end
  end

  describe 'when querying installed groups' do
    let(:installed_packages) { {'package1' => '1.0', 'package2' => '2.0', 'package3' => '3.0'} }
    let(:groups) { [['foo package1'], ['foo package2'], ['bar package3'], ['bar package4'], ['baz package5']] }

    it 'should raise an error on non-zero pacman exit without a filter' do
      executor.expects(:open).with('| /usr/bin/pacman -Sgg 2>&1').returns 'error!'
      $CHILD_STATUS.stubs(:exitstatus).returns 1
      expect { described_class.get_installed_groups(installed_packages) }.to raise_error(Puppet::ExecutionFailure, 'error!')
    end

    it 'should return empty groups on non-zero pacman exit with a filter' do
      executor.expects(:open).with('| /usr/bin/pacman -Sgg git 2>&1').returns ''
      $CHILD_STATUS.stubs(:exitstatus).returns 1
      expect(described_class.get_installed_groups(installed_packages, 'git')).to eq({})
    end

    it 'should return empty groups on empty pacman output' do
      pipe = stub()
      pipe.expects(:each_line)
      executor.expects(:open).with('| /usr/bin/pacman -Sgg 2>&1').yields(pipe).returns ''
      $CHILD_STATUS.stubs(:exitstatus).returns 0
      expect(described_class.get_installed_groups(installed_packages)).to eq({})
    end

    it 'should return groups on non-empty pacman output' do
      pipe = stub()
      pipe.expects(:each_line).multiple_yields(*groups)
      executor.expects(:open).with('| /usr/bin/pacman -Sgg 2>&1').yields(pipe).returns ''
      $CHILD_STATUS.stubs(:exitstatus).returns 0
      expect(described_class.get_installed_groups(installed_packages)).to eq({'foo' => 'package1 1.0, package2 2.0'})
    end
  end

end
