require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pkg), unless: Puppet::Util::Platform.jruby? do
  let (:resource) { Puppet::Resource.new(:package, 'dummy', :parameters => {:name => 'dummy', :ensure => :latest}) }
  let (:provider) { described_class.new(resource) }

  before(:all) do
    if Puppet::Util::Platform.windows?
      # Get a pid for $CHILD_STATUS to latch on to
      command = "cmd.exe /c \"exit 0\""
      Puppet::Util::Execution.execute(command, {:failonfail => false})
    else
      Puppet::Util::Execution.execute('exit 0', {:failonfail => false})
    end
  end

  before :each do
    allow(described_class).to receive(:command).with(:pkg).and_return('/bin/pkg')
  end

  def self.it_should_respond_to(*actions)
    actions.each do |action|
      it "should respond to :#{action}" do
        expect(provider).to respond_to(action)
      end
    end
  end

  it_should_respond_to :install, :uninstall, :update, :query, :latest

  context 'default' do
    [ 10 ].each do |ver|
      it "should not be the default provider on Solaris #{ver}" do
        allow(Facter).to receive(:value).with(:osfamily).and_return(:Solaris)
        allow(Facter).to receive(:value).with(:kernelrelease).and_return("5.#{ver}")
        allow(Facter).to receive(:value).with(:operatingsystem).and_return(:Solaris)
        allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("#{ver}")
        expect(described_class).to_not be_default
      end
    end

    [ 11, 12 ].each do |ver|
      it "should be the default provider on Solaris #{ver}" do
        allow(Facter).to receive(:value).with(:osfamily).and_return(:Solaris)
        allow(Facter).to receive(:value).with(:kernelrelease).and_return("5.#{ver}")
        allow(Facter).to receive(:value).with(:operatingsystem).and_return(:Solaris)
        allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("#{ver}")
        expect(described_class).to be_default
      end
    end
  end

  it "should be versionable" do
    expect(described_class).to be_versionable
  end

  describe "#methods" do
    context ":pkg_state" do
      it "should raise error on unknown values" do
        expect {
          expect(described_class.pkg_state('extra')).to
        }.to raise_error(ArgumentError, /Unknown format/)
      end

      ['known', 'installed'].each do |k|
        it "should return known values" do
          expect(described_class.pkg_state(k)).to eq({:status => k})
        end
      end
    end

    context ":ifo_flag" do
      it "should raise error on unknown values" do
        expect {
          expect(described_class.ifo_flag('x--')).to
        }.to raise_error(ArgumentError, /Unknown format/)
      end

      {'i--' => 'installed', '---'=> 'known'}.each do |k, v|
        it "should return known values" do
          expect(described_class.ifo_flag(k)).to eq({:status => v})
        end
      end
    end

    context ":parse_line" do
      it "should raise error on unknown values" do
        expect {
          expect(described_class.parse_line('pkg (mypkg) 1.2.3.4 i-- zzz')).to
        }.to raise_error(ArgumentError, /Unknown line format/)
      end

      {
        'pkg://omnios/SUNWcs@0.5.11,5.11-0.151006:20130506T161045Z    i--' => {:name => 'SUNWcs', :ensure => '0.5.11,5.11-0.151006:20130506T161045Z', :status => 'installed', :provider => :pkg, :publisher => 'omnios'},
        'pkg://omnios/incorporation/jeos/illumos-gate@11,5.11-0.151006:20130506T183443Z if-' => {:name => 'incorporation/jeos/illumos-gate', :ensure => "11,5.11-0.151006:20130506T183443Z", :mark => :hold, :status => 'installed', :provider => :pkg, :publisher => 'omnios'},
        'pkg://solaris/SUNWcs@0.5.11,5.11-0.151.0.1:20101105T001108Z      installed  -----' => {:name => 'SUNWcs', :ensure => '0.5.11,5.11-0.151.0.1:20101105T001108Z', :status => 'installed', :provider => :pkg, :publisher => 'solaris'},
       }.each do |k, v|
        it "[#{k}] should correctly parse" do
          expect(described_class.parse_line(k)).to eq(v)
        end
      end
    end

    context ":latest" do
      before do
        expect(described_class).to receive(:pkg).with(:refresh)
      end

      it "should work correctly for ensure latest on solaris 11 (UFOXI) when there are no further packages to install" do
        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.installed')))
        expect(provider.latest).to eq('1.0.6,5.11-0.175.0.0.0.2.537:20131230T130000Z')
      end

      it "should work correctly for ensure latest on solaris 11 in the presence of a certificate expiration warning" do
        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.certificate_warning')))
        expect(provider.latest).to eq("1.0.6-0.175.0.0.0.2.537")
      end

      it "should work correctly for ensure latest on solaris 11(known UFOXI)" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(['/bin/pkg', 'update', '-n', 'dummy'], {:failonfail => false, :combine => true})
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)

        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.known')))
        expect(provider.latest).to eq('1.0.6,5.11-0.175.0.0.0.2.537:20131230T130000Z')
      end

      it "should work correctly for ensure latest on solaris 11 (IFO)" do
        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.ifo.installed')))
        expect(provider.latest).to eq('1.0.6,5.11-0.175.0.0.0.2.537:20131230T130000Z')
      end

      it "should work correctly for ensure latest on solaris 11(known IFO)" do
        expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'update', '-n', 'dummy'], {:failonfail => false, :combine => true}).and_return('')
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)

        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.ifo.known')))
        expect(provider.latest).to eq('1.0.6,5.11-0.175.0.0.0.2.537:20131230T130000Z')
      end

      it "issues a warning when the certificate has expired" do
        warning = "Certificate '/var/pkg/ssl/871b4ed0ade09926e6adf95f86bf17535f987684' for publisher 'solarisstudio', needed to access 'https://pkg.oracle.com/solarisstudio/release/', will expire in '29' days."
        expect(Puppet).to receive(:warning).with("pkg warning: #{warning}")

        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.certificate_warning')))
        provider.latest
      end

      it "doesn't issue a warning when the certificate hasn't expired" do
        expect(Puppet).not_to receive(:warning).with(/pkg warning/)

        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.installed')))
        provider.latest
      end

      it "applies install options if available" do
        resource[:install_options] = ['--foo', {'--bar' => 'baz'}]
        expect(described_class).to receive(:pkg).with(:list,'-Hvn','dummy').and_return(File.read(my_fixture('dummy_solaris11.known')))
        expect(Puppet::Util::Execution).to receive(:execute)
            .with(['/bin/pkg', 'update', '-n', '--foo', '--bar=baz', 'dummy'], {failonfail: false, combine: true})
        provider.latest
      end
    end

    context ":instances" do
      it "should correctly parse lines on solaris 11" do
        expect(described_class).to receive(:pkg).with(:list, '-Hv').and_return(File.read(my_fixture('solaris11')))
        expect(described_class).not_to receive(:warning)
        instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure) }}
        expect(instances.size).to eq(2)
        expect(instances[0]).to eq({:name => 'dummy/dummy', :ensure => '3.0,5.11-0.175.0.0.0.2.537:20131230T130000Z'})
        expect(instances[1]).to eq({:name => 'dummy/dummy2', :ensure => '1.8.1.2-0.175.0.0.0.2.537:20131230T130000Z'})
      end

      it "should fail on incorrect lines" do
        fake_output = File.read(my_fixture('incomplete'))
        expect(described_class).to receive(:pkg).with(:list,'-Hv').and_return(fake_output)
        expect {
          described_class.instances
        }.to raise_error(ArgumentError, /Unknown line format pkg/)
      end

      it "should fail on unknown package status" do
        expect(described_class).to receive(:pkg).with(:list,'-Hv').and_return(File.read(my_fixture('unknown_status')))
        expect {
          described_class.instances
        }.to raise_error(ArgumentError, /Unknown format pkg/)
      end
    end

    context ":query" do
      context "on solaris 10" do
        it "should find the package" do
          expect(Puppet::Util::Execution).to receive(:execute)
            .with(['/bin/pkg', 'list', '-Hv', 'dummy'], {:failonfail => false, :combine => true})
            .and_return(Puppet::Util::Execution::ProcessOutput.new(File.read(my_fixture('dummy_solaris10')), 0))
          allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
          expect(provider.query).to eq({
            :name      => 'dummy',
            :ensure    => '2.5.5,5.10-0.111:20131230T130000Z',
            :publisher => 'solaris',
            :status    => 'installed',
            :provider  => :pkg,
          })
        end

        it "should return :absent when the package is not found" do
          expect(Puppet::Util::Execution).to receive(:execute)
            .with(['/bin/pkg', 'list', '-Hv', 'dummy'], {:failonfail => false, :combine => true})
            .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
          allow($CHILD_STATUS).to receive(:exitstatus).and_return(1)
          expect(provider.query).to eq({:ensure => :absent, :name => "dummy"})
        end
      end

      context "on solaris 11" do
        it "should find the package" do
          allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
          expect(Puppet::Util::Execution).to receive(:execute)
            .with(['/bin/pkg', 'list', '-Hv', 'dummy'], {:failonfail => false, :combine => true})
            .and_return(Puppet::Util::Execution::ProcessOutput.new(File.read(my_fixture('dummy_solaris11.installed')), 0))
          expect(provider.query).to eq({
            :name      => 'dummy',
            :status    => 'installed',
            :ensure    => '1.0.6,5.11-0.175.0.0.0.2.537:20131230T130000Z',
            :publisher => 'solaris',
            :provider  => :pkg,
          })
        end

        it "should return :absent when the package is not found" do
          expect(Puppet::Util::Execution).to receive(:execute)
            .with(['/bin/pkg', 'list', '-Hv', 'dummy'], {:failonfail => false, :combine => true})
            .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
          allow($CHILD_STATUS).to receive(:exitstatus).and_return(1)
          expect(provider.query).to eq({:ensure => :absent, :name => "dummy"})
        end
      end

      it "should return fail when the packageline cannot be parsed" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(['/bin/pkg', 'list', '-Hv', 'dummy'], {:failonfail => false, :combine => true})
          .and_return(Puppet::Util::Execution::ProcessOutput.new(File.read(my_fixture('incomplete')), 0))
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
        expect {
          provider.query
        }.to raise_error(ArgumentError, /Unknown line format/)
      end
    end

    context ":install" do
      [
        { :osrel => '11.0', :flags => ['--accept'] },
        { :osrel => '11.2', :flags => ['--accept', '--sync-actuators-timeout', '900'] },
      ].each do |hash|
        context "with :operatingsystemrelease #{hash[:osrel]}" do
          before :each do
            allow(Facter).to receive(:value).with(:operatingsystemrelease).and_return(hash[:osrel])
          end

          it "should support install options" do
            resource[:install_options] = ['--foo', {'--bar' => 'baz'}]
            expect(provider).to receive(:query).and_return({:ensure => :absent})
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(provider).to receive(:unhold)
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'install', *hash[:flags], '--foo', '--bar=baz', 'dummy'], {:failonfail => false, :combine => true})
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.install
          end

          it "should accept all licenses" do
            expect(provider).to receive(:query).with(no_args).and_return({:ensure => :absent})
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'install', *hash[:flags], 'dummy'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.install
          end

          it "should install specific version(1)" do
            # Should install also check if the version installed is the same version we are asked to install? or should we rely on puppet for that?
            resource[:ensure] = '0.0.7,5.11-0.151006:20131230T130000Z'
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'list', '-Hv', 'dummy'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('pkg://foo/dummy@0.0.6,5.11-0.151006:20131230T130000Z  installed -----', 0))
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'update', *hash[:flags], 'dummy@0.0.7,5.11-0.151006:20131230T130000Z'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
            provider.install
          end

          it "should install specific version(2)" do
            resource[:ensure] = '0.0.8'
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'list', '-Hv', 'dummy'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('pkg://foo/dummy@0.0.7,5.11-0.151006:20131230T130000Z  installed -----', 0))
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'update', *hash[:flags], 'dummy@0.0.8'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.install
          end

          it "should downgrade to specific version" do
            resource[:ensure] = '0.0.7'
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(provider).to receive(:query).with(no_args).and_return({:ensure => '0.0.8,5.11-0.151106:20131230T130000Z'})
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'update', *hash[:flags], 'dummy@0.0.7'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
            provider.install
          end

          it "should install any if version is not specified" do
            resource[:ensure] = :present
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(provider).to receive(:query).with(no_args).and_return({:ensure => :absent})
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'install', *hash[:flags], 'dummy'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.install
          end

          it "should install if no version was previously installed, and a specific version was requested" do
            resource[:ensure] = '0.0.7'
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(provider).to receive(:query).with(no_args).and_return({:ensure => :absent})
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
            expect(Puppet::Util::Execution).to receive(:execute)
              .with(['/bin/pkg', 'install', *hash[:flags], 'dummy@0.0.7'], {:failonfail => false, :combine => true})
              .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.install
          end

          it "installs the latest matching version when given implicit version, and none are installed" do
            resource[:ensure] = '1.0-0.151006'
            is = :absent
            expect(provider).to receive(:query).with(no_args).and_return({:ensure => is})
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(described_class).to receive(:pkg)
              .with(:list, '-Hvfa', 'dummy@1.0-0.151006')
              .and_return(Puppet::Util::Execution::ProcessOutput.new(File.read(my_fixture('dummy_implicit_version')), 0))
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'install', '-n', 'dummy@1.0,5.11-0.151006:20140220T084443Z'], {:failonfail => false, :combine => true})
            expect(provider).to receive(:unhold).with(no_args)
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'install', *hash[:flags], 'dummy@1.0,5.11-0.151006:20140220T084443Z'], {:failonfail => false, :combine => true})
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.insync?(is)
            provider.install
          end

          it "updates to the latest matching version when given implicit version" do
            resource[:ensure] = '1.0-0.151006'
            is = '1.0,5.11-0.151006:20140219T191204Z'
            expect(provider).to receive(:query).with(no_args).and_return({:ensure => is})
            expect(provider).to receive(:properties).and_return({:mark => :hold})
            expect(described_class).to receive(:pkg).with(:list, '-Hvfa', 'dummy@1.0-0.151006').and_return(File.read(my_fixture('dummy_implicit_version')))
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'update', '-n', 'dummy@1.0,5.11-0.151006:20140220T084443Z'], {:failonfail => false, :combine => true})
            expect(provider).to receive(:unhold).with(no_args)
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'update', *hash[:flags], 'dummy@1.0,5.11-0.151006:20140220T084443Z'], {:failonfail => false, :combine => true})
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.insync?(is)
            provider.install
          end

          it "issues a warning when an implicit version number is used, and in sync" do
            resource[:ensure] = '1.0-0.151006'
            is = '1.0,5.11-0.151006:20140220T084443Z'
            expect(provider).to receive(:warning).with("Implicit version 1.0-0.151006 has 3 possible matches")
            expect(described_class).to receive(:pkg)
              .with(:list, '-Hvfa', 'dummy@1.0-0.151006')
              .and_return(Puppet::Util::Execution::ProcessOutput.new(File.read(my_fixture('dummy_implicit_version')), 0))
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'update', '-n', 'dummy@1.0,5.11-0.151006:20140220T084443Z'], {:failonfail => false, :combine => true})
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(4)
            provider.insync?(is)
          end

          it "issues a warning when choosing a version number for an implicit match" do
            resource[:ensure] = '1.0-0.151006'
            is = :absent
            expect(provider).to receive(:warning).with("Implicit version 1.0-0.151006 has 3 possible matches")
            expect(provider).to receive(:warning).with("Selecting version '1.0,5.11-0.151006:20140220T084443Z' for implicit '1.0-0.151006'")
            expect(described_class).to receive(:pkg).with(:list, '-Hvfa', 'dummy@1.0-0.151006').and_return(File.read(my_fixture('dummy_implicit_version')))
            expect(Puppet::Util::Execution).to receive(:execute).with(['/bin/pkg', 'install', '-n', 'dummy@1.0,5.11-0.151006:20140220T084443Z'], {:failonfail => false, :combine => true})
            allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
            provider.insync?(is)
          end
        end
      end
    end

    context ":update" do
      it "should not raise error if not necessary" do
        expect(provider).to receive(:install).with(true).and_return({:exit => 0})
        provider.update
      end

      it "should not raise error if not necessary (2)" do
        expect(provider).to receive(:install).with(true).and_return({:exit => 4})
        provider.update
      end

      it "should raise error if necessary" do
        expect(provider).to receive(:install).with(true).and_return({:exit => 1})
        expect {
          provider.update
        }.to raise_error(Puppet::Error, /Unable to update/)
      end
    end

    context ":uninstall" do
      it "should support current pkg version" do
        expect(described_class).to receive(:pkg).with(:version).and_return('630e1ffc7a19')
        expect(described_class).to receive(:pkg).with([:uninstall, resource[:name]])
        expect(provider).to receive(:properties).and_return({:hold => false})

        provider.uninstall
      end

      it "should support original pkg commands" do
        expect(described_class).to receive(:pkg).with(:version).and_return('052adf36c3f4')
        expect(described_class).to receive(:pkg).with([:uninstall, '-r', resource[:name]])
        expect(provider).to receive(:properties).and_return({:hold => false})

        provider.uninstall
      end
    end
  end
end
