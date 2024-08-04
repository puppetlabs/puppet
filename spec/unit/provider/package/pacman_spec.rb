require 'spec_helper'
require 'stringio'

describe Puppet::Type.type(:package).provider(:pacman) do
  let(:no_extra_options) { { :failonfail => true, :combine => true, :custom_environment => {} } }
  let(:executor) { Puppet::Util::Execution }
  let(:resolver) { Puppet::Util }

  let(:resource) { Puppet::Type.type(:package).new(:name => 'package', :provider => 'pacman') }
  let(:provider) { described_class.new(resource) }

  before do
    allow(resolver).to receive(:which).with('/usr/bin/pacman').and_return('/usr/bin/pacman')
    allow(described_class).to receive(:which).with('/usr/bin/pacman').and_return('/usr/bin/pacman')
    allow(resolver).to receive(:which).with('/usr/bin/yaourt').and_return('/usr/bin/yaourt')
    allow(described_class).to receive(:which).with('/usr/bin/yaourt').and_return('/usr/bin/yaourt')
    allow(described_class).to receive(:group?).and_return(false)
    allow(described_class).to receive(:yaourt?).and_return(false)
  end

  describe "when installing" do
    before do
      allow(provider).to receive(:query).and_return({
        :ensure => '1.0'
      })
    end

    it "should call pacman to install the right package quietly when yaourt is not installed" do
      args = ['--noconfirm', '--needed', '--noprogressbar', '-S', resource[:name]]
      expect(provider).to receive(:pacman).at_least(:once).with(*args).and_return('')
      provider.install
    end

    it "should call yaourt to install the right package quietly when yaourt is installed" do
      without_partial_double_verification do
        allow(described_class).to receive(:yaourt?).and_return(true)
        args = ['--noconfirm', '--needed', '--noprogressbar', '-S', resource[:name]]
        expect(provider).to receive(:yaourt).at_least(:once).with(*args).and_return('')
        provider.install
      end
    end

    it "should raise an Puppet::Error if the installation failed" do
      allow(executor).to receive(:execute).and_return("")
      expect(provider).to receive(:query).and_return(nil)

      expect {
        provider.install
      }.to raise_exception(Puppet::Error, /Could not find package/)
    end

    it "should raise an Puppet::Error when trying to install a group and allow_virtual is false" do
      allow(described_class).to receive(:group?).and_return(true)
      resource[:allow_virtual] = false
      expect {
        provider.install
      }.to raise_error(Puppet::Error, /Refusing to install package group/)
    end

    it "should not raise an Puppet::Error when trying to install a group and allow_virtual is true" do
      allow(described_class).to receive(:group?).and_return(true)
      resource[:allow_virtual] = true
      allow(executor).to receive(:execute).and_return("")
      provider.install
    end

    describe "and install_options are given" do
      before do
        resource[:install_options] = ['-x', {'--arg' => 'value'}]
      end

      it "should call pacman to install the right package quietly when yaourt is not installed" do
        args = ['--noconfirm', '--needed', '--noprogressbar', '-x', '--arg=value', '-S', resource[:name]]
        expect(provider).to receive(:pacman).at_least(:once).with(*args).and_return('')
        provider.install
      end

      it "should call yaourt to install the right package quietly when yaourt is installed" do
        without_partial_double_verification do
          expect(described_class).to receive(:yaourt?).and_return(true)
          args = ['--noconfirm', '--needed', '--noprogressbar', '-x', '--arg=value', '-S', resource[:name]]
          expect(provider).to receive(:yaourt).at_least(:once).with(*args).and_return('')
          provider.install
        end
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

            expect(executor).to receive(:execute).
              with(include("-U") & include(source), no_extra_options).
              ordered.
              and_return("")

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
          expect(executor).to receive(:execute).
            with(include("-U") & include(actual_file_path), no_extra_options).
            ordered.
            and_return("")

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
      expect(provider).to receive(:install).and_return("install return value")
      expect(provider.update).to eq("install return value")
    end
  end

  describe "when purging" do
    it "should call pacman to remove the right package and configs quietly" do
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-R", "--nosave", resource[:name]]
      expect(executor).to receive(:execute).with(args, no_extra_options).and_return("")
      provider.purge
    end
  end

  describe "when uninstalling" do
    it "should call pacman to remove the right package quietly" do
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-R", resource[:name]]
      expect(executor).to receive(:execute).with(args, no_extra_options).and_return("")
      provider.uninstall
    end

    it "should call yaourt to remove the right package quietly" do
      without_partial_double_verification do
        allow(described_class).to receive(:yaourt?).and_return(true)
        args = ["--noconfirm", "--noprogressbar", "-R", resource[:name]]
        expect(provider).to receive(:yaourt).with(*args)
        provider.uninstall
      end
    end

    it "adds any uninstall_options" do
      resource[:uninstall_options] = ['-x', {'--arg' => 'value'}]
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-x", "--arg=value", "-R", resource[:name]]
      expect(executor).to receive(:execute).with(args, no_extra_options).and_return("")
      provider.uninstall
    end

    it "should recursively remove packages when given a package group" do
      allow(described_class).to receive(:group?).and_return(true)
      args = ["/usr/bin/pacman", "--noconfirm", "--noprogressbar", "-R", "-s", resource[:name]]
      expect(executor).to receive(:execute).with(args, no_extra_options).and_return("")
      provider.uninstall
    end
  end

  describe "when querying" do
    it "should query pacman" do
      expect(executor).to receive(:execpipe).with(["/usr/bin/pacman", '-Q'])
      expect(executor).to receive(:execpipe).with(["/usr/bin/pacman", '-Sgg', 'package'])
      provider.query
    end

    it "should return the version" do
      expect(executor).to receive(:execpipe).
          with(["/usr/bin/pacman", "-Q"]).and_yield(<<EOF)
otherpackage 1.2.3.4
package 1.01.3-2
yetanotherpackage 1.2.3.4
EOF
      expect(executor).to receive(:execpipe).with(['/usr/bin/pacman', '-Sgg', 'package']).and_yield('')

      expect(provider.query).to eq({ :name => 'package', :ensure => '1.01.3-2', :provider => :pacman,  })
    end

    it "should return a hash indicating that the package is missing" do
      expect(executor).to receive(:execpipe).twice.and_yield("")
      expect(provider.query).to be_nil
    end

    it "should raise an error if execpipe fails" do
      expect(executor).to receive(:execpipe).and_raise(Puppet::ExecutionFailure.new("ERROR!"))

      expect { provider.query }.to raise_error(RuntimeError)
    end

    describe 'when querying a group' do
      before :each do
        expect(executor).to receive(:execpipe).with(['/usr/bin/pacman', '-Q']).and_yield('foo 1.2.3')
        expect(executor).to receive(:execpipe).with(['/usr/bin/pacman', '-Sgg', 'package']).and_yield('package foo')
      end

      it 'should warn when allow_virtual is false' do
        resource[:allow_virtual] = false
        expect(provider).to receive(:warning)
        provider.query
      end

      it 'should not warn allow_virtual is true' do
        resource[:allow_virtual] = true
        expect(described_class).not_to receive(:warning)
        provider.query
      end
    end
  end

  describe "when determining instances" do
    it "should retrieve installed packages and groups" do
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Q'])
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Sgg'])
      described_class.instances
    end

    it "should return installed packages" do
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Q']).and_yield(StringIO.new("package1 1.23-4\npackage2 2.00\n"))
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Sgg']).and_yield("")
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
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Q']).and_yield(<<EOF)
package1 1.00
package2 1.00
EOF
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Sgg']).and_yield(<<EOF)
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
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Q']).and_yield(<<EOF)
package1 1.00
EOF
      expect(described_class).to receive(:execpipe).with(["/usr/bin/pacman", '-Sgg']).and_yield(<<EOF)
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
      expect(described_class).to receive(:execpipe).with(['/usr/bin/pacman', '-Sgg', 'group1']).and_yield(<<EOF)
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
      expect(described_class).to receive(:execpipe).and_raise(Puppet::ExecutionFailure.new("ERROR!"))
      expect { described_class.instances }.to raise_error(RuntimeError)
    end

    it "should warn on invalid input" do
      expect(described_class).to receive(:execpipe).twice.and_yield(StringIO.new("blah"))
      expect(described_class).to receive(:warning).with("Failed to match line 'blah'")
      expect(described_class.instances).to eq([])
    end
  end

  describe "when determining the latest version" do
    it "should get query pacman for the latest version" do
      expect(executor).to receive(:execute).
        ordered.
        with(['/usr/bin/pacman', '-Sp', '--print-format', '%v', resource[:name]], no_extra_options).
        and_return("")

      provider.latest
    end

    it "should return the version number from pacman" do
      expect(executor).to receive(:execute).at_least(:once).and_return("1.00.2-3\n")

      expect(provider.latest).to eq("1.00.2-3")
    end

    it "should return a virtual group version when resource is a package group" do
      allow(described_class).to receive(:group?).and_return(true)
      expect(executor).to receive(:execute).with(['/usr/bin/pacman', '-Sp', '--print-format', '%n %v', resource[:name]], no_extra_options).ordered.
        and_return(<<EOF)
package2 1.0.1
package1 1.0.0
EOF
      expect(provider.latest).to eq('package1 1.0.0, package2 1.0.1')
    end
  end

  describe 'when determining if a resource is a group' do
    before do
      allow(described_class).to receive(:group?).and_call_original
    end

    it 'should return false on non-zero pacman exit' do
      allow(executor).to receive(:execute).with(['/usr/bin/pacman', '-Sg', 'git'], {:failonfail => true, :combine => true, :custom_environment => {}}).and_raise(Puppet::ExecutionFailure, 'error')
      expect(described_class.group?('git')).to eq(false)
    end

    it 'should return false on empty pacman output' do
      allow(executor).to receive(:execute).with(['/usr/bin/pacman', '-Sg', 'git'], {:failonfail => true, :combine => true, :custom_environment => {}}).and_return('')
      expect(described_class.group?('git')).to eq(false)
    end

    it 'should return true on non-empty pacman output' do
      allow(executor).to receive(:execute).with(['/usr/bin/pacman', '-Sg', 'vim-plugins'], {:failonfail => true, :combine => true, :custom_environment => {}}).and_return('vim-plugins vim-a')
      expect(described_class.group?('vim-plugins')).to eq(true)
    end
  end

  describe 'when querying installed groups' do
    let(:installed_packages) { {'package1' => '1.0', 'package2' => '2.0', 'package3' => '3.0'} }
    let(:groups) { [['foo package1'], ['foo package2'], ['bar package3'], ['bar package4'], ['baz package5']] }

    it 'should raise an error on non-zero pacman exit without a filter' do
      expect(executor).to receive(:open).with('| /usr/bin/pacman -Sgg 2>&1').and_return('error!')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(1)
      expect { described_class.get_installed_groups(installed_packages) }.to raise_error(Puppet::ExecutionFailure, 'error!')
    end

    it 'should return empty groups on non-zero pacman exit with a filter' do
      expect(executor).to receive(:open).with('| /usr/bin/pacman -Sgg git 2>&1').and_return('')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(1)
      expect(described_class.get_installed_groups(installed_packages, 'git')).to eq({})
    end

    it 'should return empty groups on empty pacman output' do
      pipe = double()
      expect(pipe).to receive(:each_line)
      expect(executor).to receive(:open).with('| /usr/bin/pacman -Sgg 2>&1').and_yield(pipe).and_return('')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(0)
      expect(described_class.get_installed_groups(installed_packages)).to eq({})
    end

    it 'should return groups on non-empty pacman output' do
      pipe = double()
      pipe_expectation = receive(:each_line)
      groups.each { |group| pipe_expectation = pipe_expectation.and_yield(*group) }
      expect(pipe).to pipe_expectation
      expect(executor).to receive(:open).with('| /usr/bin/pacman -Sgg 2>&1').and_yield(pipe).and_return('')
      expect(Puppet::Util::Execution).to receive(:exitstatus).and_return(0)
      expect(described_class.get_installed_groups(installed_packages)).to eq({'foo' => 'package1 1.0, package2 2.0'})
    end
  end
end
