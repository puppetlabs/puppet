shared_examples "RHEL package provider" do |provider_class, provider_name|
  describe provider_name do
    let(:name) { 'mypackage' }
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => name,
        :ensure   => :installed,
        :provider => provider_name
      )
    end
    let(:provider) do
      provider = provider_class.new
      provider.resource = resource
      provider
    end
    let(:arch) { 'x86_64' }
    let(:arch_resource) do
      Puppet::Type.type(:package).new(
        :name     => "#{name}.#{arch}",
        :ensure   => :installed,
        :provider => provider_name
      )
    end
    let(:arch_provider) do
      provider = provider_class.new
      provider.resource = arch_resource
      provider
    end

    case provider_name
    when 'yum'
      let(:error_level) { '0' }
    when 'dnf'
      let(:error_level) { '1' }
    when 'tdnf'
      let(:error_level) { '1' }
    end

    case provider_name
    when 'yum'
      let(:upgrade_command) { 'update' }
    when 'dnf'
      let(:upgrade_command) { 'upgrade' }
    when 'tdnf'
      let(:upgrade_command) { 'upgrade' }
    end

    before do
      allow(provider_class).to receive(:command).with(:cmd).and_return("/usr/bin/#{provider_name}")
      allow(provider).to receive(:rpm).and_return('rpm')
      allow(provider).to receive(:get).with(:version).and_return('1')
      allow(provider).to receive(:get).with(:release).and_return('1')
      allow(provider).to receive(:get).with(:arch).and_return('i386')
    end

    describe 'provider features' do
      it { is_expected.to be_versionable }
      it { is_expected.to be_install_options }
      it { is_expected.to be_virtual_packages }
    end
    # provider should repond to the following methods
     [:install, :latest, :update, :purge, :install_options].each do |method|
       it "should have a(n) #{method}" do
         expect(provider).to respond_to(method)
      end
    end
    describe 'when installing' do
      before(:each) do
        allow(Puppet::Util).to receive(:which).with("rpm").and_return("/bin/rpm")
        allow(provider).to receive(:which).with("rpm").and_return("/bin/rpm")
        expect(Puppet::Util::Execution).to receive(:execute).with(["/bin/rpm", "--version"], {:combine => true, :custom_environment => {}, :failonfail => true}).and_return(Puppet::Util::Execution::ProcessOutput.new("4.10.1\n", 0)).at_most(:once)
        allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return('6')
      end

      it "should call #{provider_name} install for :installed" do
        allow(resource).to receive(:should).with(:ensure).and_return(:installed)
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :install, 'mypackage'])
        provider.install
      end

      if provider_name == 'yum'
        context 'on el-5' do
          before(:each) do
            allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return('5')
          end

          it "should catch #{provider_name} install failures when status code is wrong" do
            allow(resource).to receive(:should).with(:ensure).and_return(:installed)
            expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-e', error_level, '-y', :install, name]).and_return(Puppet::Util::Execution::ProcessOutput.new("No package #{name} available.", 0))
            expect {
              provider.install
            }.to raise_error(Puppet::Error, "Could not find package #{name}")
          end
        end
      end

      it 'should use :install to update' do
        expect(provider).to receive(:install)
        provider.update
      end

      it 'should be able to set version' do
        version = '1.2'
        resource[:ensure] = version
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :install, "#{name}-#{version}"])
        allow(provider).to receive(:query).and_return(:ensure => version)
        provider.install
      end
      it 'should handle partial versions specified' do
        version = '1.3.4'
        resource[:ensure] = version
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :install, 'mypackage-1.3.4'])
        allow(provider).to receive(:query).and_return(:ensure => '1.3.4-1.el6')
        provider.install
      end

      it 'should be able to downgrade' do
        current_version = '1.2'
        version = '1.0'
        resource[:ensure] = '1.0'
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :downgrade, "#{name}-#{version}"])
        allow(provider).to receive(:query).and_return({:ensure => current_version}, {:ensure => version})
        provider.install
      end

      it 'should be able to upgrade' do
        current_version = '1.0'
        version = '1.2'
        resource[:ensure] = '1.2'
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', upgrade_command, "#{name}-#{version}"])
        allow(provider).to receive(:query).and_return({:ensure => current_version}, {:ensure => version})
        provider.install
      end

      it 'should not run upgrade command if absent and ensure latest' do
        current_version = ''
        version = '1.2'
        resource[:ensure] = :latest
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :install, name])
        allow(provider).to receive(:query).and_return({:ensure => current_version}, {:ensure => version})
        provider.install
      end

      it 'should run upgrade command if present and ensure latest' do
        current_version = '1.0'
        version = '1.2'
        resource[:ensure] = :latest
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', upgrade_command, name])
        allow(provider).to receive(:query).and_return({:ensure => current_version}, {:ensure => version})
        provider.install
      end

      it 'should accept install options' do
        resource[:ensure] = :installed
        resource[:install_options] = ['-t', {'-x' => 'expackage'}]
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', ['-t', '-x=expackage'], :install, name])
        provider.install
      end

      it 'allow virtual packages' do
        resource[:ensure] = :installed
        resource[:allow_virtual] = true
        expect(Puppet::Util::Execution).not_to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :list, name])
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :install, name])
        provider.install
      end

      it 'moves architecture to end of version' do
        version = '1.2.3'
        arch_resource[:ensure] = version
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-d', '0', '-e', error_level, '-y', :install, "#{name}-#{version}.#{arch}"])
        allow(arch_provider).to receive(:query).and_return(:ensure => version)
        arch_provider.install
      end
    end

    describe 'when uninstalling' do
      it 'should use erase to purge' do
        expect(Puppet::Util::Execution).to receive(:execute).with(["/usr/bin/#{provider_name}", '-y', :erase, name])
        provider.purge
      end
    end

    it 'should be versionable' do
      expect(provider).to be_versionable
    end

    describe 'determining the latest version available for a package' do
      it "passes the value of enablerepo install_options when querying" do
        resource[:install_options] = [
          {'--enablerepo' => 'contrib'},
          {'--enablerepo' => 'centosplus'},
        ]
        allow(provider).to receive(:properties).and_return({:ensure => '3.4.5'})
        expect(described_class).to receive(:latest_package_version).with(name, [], ['contrib', 'centosplus'], [])
        provider.latest
      end

      it "passes the value of disablerepo install_options when querying" do
        resource[:install_options] = [
          {'--disablerepo' => 'updates'},
          {'--disablerepo' => 'centosplus'},
        ]
        allow(provider).to receive(:properties).and_return({:ensure => '3.4.5'})
        expect(described_class).to receive(:latest_package_version).with(name, ['updates', 'centosplus'], [], [])
        provider.latest
      end

      it "passes the value of disableexcludes install_options when querying" do
        resource[:install_options] = [
          {'--disableexcludes' => 'main'},
          {'--disableexcludes' => 'centosplus'},
        ]
        allow(provider).to receive(:properties).and_return({:ensure => '3.4.5'})
        expect(described_class).to receive(:latest_package_version).with(name, [], [], ['main', 'centosplus'])
        provider.latest
      end

      describe 'and a newer version is not available' do
        before :each do
          allow(described_class).to receive(:latest_package_version).with(name, [], [], []).and_return(nil)
        end

        it 'raises an error the package is not installed' do
          allow(provider).to receive(:properties).and_return({:ensure => :absent})
          expect {
            provider.latest
          }.to raise_error(Puppet::DevError, 'Tried to get latest on a missing package')
        end

        it 'returns version of the currently installed package' do
          allow(provider).to receive(:properties).and_return({:ensure => '3.4.5'})
          expect(provider.latest).to eq('3.4.5')
        end
      end

      describe 'and a newer version is available' do
        let(:latest_version) do
          {
            :name     => name,
            :epoch    => '1',
            :version  => '2.3.4',
            :release  => '5',
            :arch     => 'i686',
          }
        end

        it 'includes the epoch in the version string' do
          allow(described_class).to receive(:latest_package_version).with(name, [], [], []).and_return(latest_version)
          expect(provider.latest).to eq('1:2.3.4-5')
        end
      end
    end

    describe "lazy loading of latest package versions" do
      before { described_class.clear }
      after { described_class.clear }
      let(:mypackage_version) do
        {
          :name     => name,
          :epoch    => '1',
          :version  => '2.3.4',
          :release  => '5',
          :arch     => 'i686',
        }
      end
      let(:mypackage_newerversion) do
        {
          :name     => name,
          :epoch    => '1',
          :version  => '4.5.6',
          :release  => '7',
          :arch     => 'i686',
        }
      end
      let(:latest_versions) { {name => [mypackage_version]} }
      let(:enabled_versions) { {name => [mypackage_newerversion]} }

      it "returns the version hash if the package was found" do
        expect(described_class).to receive(:check_updates).with([], [], []).once.and_return(latest_versions)
        version = described_class.latest_package_version(name, [], [], [])
        expect(version).to eq(mypackage_version)
      end

      it "is nil if the package was not found in the query" do
        expect(described_class).to receive(:check_updates).with([], [], []).once.and_return(latest_versions)
        version = described_class.latest_package_version('nopackage', [], [], [])
        expect(version).to be_nil
      end

      it "caches the package list and reuses that for subsequent queries" do
        expect(described_class).to receive(:check_updates).with([], [], []).once.and_return(latest_versions)
        2.times {
          version = described_class.latest_package_version(name, [], [], [])
          expect(version).to eq mypackage_version
        }
      end

      it "caches separate lists for each combination of 'disablerepo' and 'enablerepo' and 'disableexcludes'" do
        expect(described_class).to receive(:check_updates).with([], [], []).once.and_return(latest_versions)
        expect(described_class).to receive(:check_updates).with(['disabled'], ['enabled'], ['disableexcludes']).once.and_return(enabled_versions)
        2.times {
          version = described_class.latest_package_version(name, [], [], [])
          expect(version).to eq mypackage_version
        }
        2.times {
          version = described_class.latest_package_version(name, ['disabled'], ['enabled'], ['disableexcludes'])
          expect(version).to eq(mypackage_newerversion)
        }
      end
    end

    describe "executing #{provider_name} check-update" do
      it "passes repos to enable to '#{provider_name} check-update'" do
        expect(Puppet::Util::Execution).to receive(:execute).with(
          %W[/usr/bin/#{provider_name} check-update --enablerepo=updates --enablerepo=centosplus],
          any_args
        ).and_return(double(:exitstatus => 0))
        described_class.check_updates([], %W[updates centosplus], [])
      end

      it "passes repos to disable to '#{provider_name} check-update'" do
        expect(Puppet::Util::Execution).to receive(:execute).with(
          %W[/usr/bin/#{provider_name} check-update --disablerepo=updates --disablerepo=centosplus],
          any_args
        ).and_return(double(:exitstatus => 0))
        described_class.check_updates(%W[updates centosplus], [], [])
      end

      it "passes a combination of repos to enable and disable to '#{provider_name} check-update'" do
        expect(Puppet::Util::Execution).to receive(:execute).with(
          %W[/usr/bin/#{provider_name} check-update --disablerepo=updates --disablerepo=centosplus --enablerepo=os --enablerepo=contrib ],
          any_args
        ).and_return(double(:exitstatus => 0))
        described_class.check_updates(%W[updates centosplus], %W[os contrib], [])
      end

      it "passes disableexcludes to '#{provider_name} check-update'" do
        expect(Puppet::Util::Execution).to receive(:execute).with(
          %W[/usr/bin/#{provider_name} check-update --disableexcludes=main --disableexcludes=centosplus],
          any_args
        ).and_return(double(:exitstatus => 0))
        described_class.check_updates([], [], %W[main centosplus])
      end

      it "passes all options to '#{provider_name} check-update'" do
        expect(Puppet::Util::Execution).to receive(:execute).with(
          %W[/usr/bin/#{provider_name} check-update --disablerepo=a --disablerepo=b --enablerepo=c --enablerepo=d --disableexcludes=e --disableexcludes=f],
          any_args
        ).and_return(double(:exitstatus => 0))
        described_class.check_updates(%W[a b], %W[c d], %W[e f])
      end

      it "returns an empty hash if '#{provider_name} check-update' returned 0" do
        expect(Puppet::Util::Execution).to receive(:execute).and_return(double(:exitstatus => 0))
        expect(described_class.check_updates([], [], [])).to be_empty
      end

      it "returns a populated hash if '#{provider_name} check-update returned 100'" do
        output = double(:exitstatus => 100)
        expect(Puppet::Util::Execution).to receive(:execute).and_return(output)
        expect(described_class).to receive(:parse_updates).with(output).and_return({:has => :updates})
        expect(described_class.check_updates([], [], [])).to eq({:has => :updates})
      end

      it "returns an empty hash if '#{provider_name} check-update' returned an exit code that was not 0 or 100" do
        expect(Puppet::Util::Execution).to receive(:execute).and_return(double(:exitstatus => 1))
        expect(described_class).to receive(:warning).with("Could not check for updates, \'/usr/bin/#{provider_name} check-update\' exited with 1")
        expect(described_class.check_updates([], [], [])).to eq({})
      end
    end

    describe "parsing a line from #{provider_name} check-update" do
      it "splits up the package name and architecture fields" do
        checkupdate = %W[curl.i686 7.32.0-10.fc20]
        parsed = described_class.update_to_hash(*checkupdate)
        expect(parsed[:name]).to eq 'curl'
        expect(parsed[:arch]).to eq 'i686'
      end

      it "splits up the epoch, version, and release fields" do
        checkupdate = %W[dhclient.i686 12:4.1.1-38.P1.el6.centos]
        parsed = described_class.update_to_hash(*checkupdate)
        expect(parsed[:epoch]).to eq '12'
        expect(parsed[:version]).to eq '4.1.1'
        expect(parsed[:release]).to eq '38.P1.el6.centos'
      end

      it "sets the epoch to 0 when an epoch is not specified" do
        checkupdate = %W[curl.i686 7.32.0-10.fc20]
        parsed = described_class.update_to_hash(*checkupdate)
        expect(parsed[:epoch]).to eq '0'
        expect(parsed[:version]).to eq '7.32.0'
        expect(parsed[:release]).to eq '10.fc20'
      end
    end
  end
end
