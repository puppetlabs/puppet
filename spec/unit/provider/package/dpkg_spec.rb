require 'spec_helper'
require 'stringio'

describe Puppet::Type.type(:package).provider(:dpkg) do
  let(:bash_version) { '4.2-5ubuntu3' }
  let(:bash_installed_output) { "install ok installed bash #{bash_version}\n" }
  let(:bash_installed_io) { StringIO.new(bash_installed_output) }
  let(:vim_installed_output) { "install ok installed vim 2:7.3.547-6ubuntu5\n" }
  let(:all_installed_io) { StringIO.new([bash_installed_output, vim_installed_output].join) }
  let(:args) { ['-W', '--showformat', %Q{'${Status} ${Package} ${Version}\\n'}] }
  let(:execute_options) do
    {:failonfail => true, :combine => true, :custom_environment => {}}
  end
  let(:resource_name) { 'package' }
  let(:resource) { double('resource', :[] => resource_name) }
  let(:provider) { described_class.new(resource) }

  it "has documentation" do
    expect(described_class.doc).to be_instance_of(String)
  end

  context "when listing all instances" do
    let(:execpipe_args) { args.unshift('myquery') }

    before do
      allow(described_class).to receive(:command).with(:dpkgquery).and_return('myquery')
    end

    it "creates and return an instance for a single dpkg-query entry" do
      expect(Puppet::Util::Execution).to receive(:execpipe).with(execpipe_args).and_yield(bash_installed_io)

      installed = double('bash')
      expect(described_class).to receive(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg).and_return(installed)

      expect(described_class.instances).to eq([installed])
    end

    it "parses multiple dpkg-query multi-line entries in the output" do
      expect(Puppet::Util::Execution).to receive(:execpipe).with(execpipe_args).and_yield(all_installed_io)

      bash = double('bash')
      expect(described_class).to receive(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg).and_return(bash)
      vim = double('vim')
      expect(described_class).to receive(:new).with(:ensure => "2:7.3.547-6ubuntu5", :error => "ok", :desired => "install", :name => "vim", :status => "installed", :provider => :dpkg).and_return(vim)

      expect(described_class.instances).to eq([bash, vim])
    end

    it "continues without failing if it encounters bad lines between good entries" do
      expect(Puppet::Util::Execution).to receive(:execpipe).with(execpipe_args).and_yield(StringIO.new([bash_installed_output, "foobar\n", vim_installed_output].join))

      bash = double('bash')
      vim = double('vim')
      expect(described_class).to receive(:new).twice.and_return(bash, vim)

      expect(described_class.instances).to eq([bash, vim])
    end
  end

  context "when querying the current state" do
    let(:dpkgquery_path) { '/bin/dpkg-query' }
    let(:query_args) do
      args.unshift(dpkgquery_path)
      args.push(resource_name)
    end

    def dpkg_query_execution_returns(output)
      expect(Puppet::Util::Execution).to receive(:execute).with(query_args, execute_options).and_return(Puppet::Util::Execution::ProcessOutput.new(output, 0))
    end

    before do
      allow(Puppet::Util).to receive(:which).with('/usr/bin/dpkg-query').and_return(dpkgquery_path)
    end

    it "considers the package purged if dpkg-query fails" do
      allow(Puppet::Util::Execution).to receive(:execute).with(query_args, execute_options).and_raise(Puppet::ExecutionFailure.new("eh"))

      expect(provider.query[:ensure]).to eq(:purged)
    end

    it "returns a hash of the found package status for an installed package" do
      dpkg_query_execution_returns(bash_installed_output)

      expect(provider.query).to eq({:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg})
    end

    it "considers the package absent if the dpkg-query result cannot be interpreted" do
      dpkg_query_execution_returns('some-bad-data')

      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "fails if an error is discovered" do
      dpkg_query_execution_returns(bash_installed_output.gsub("ok","error"))

      expect { provider.query }.to raise_error(Puppet::Error)
    end

    it "considers the package purged if it is marked 'not-installed'" do
      not_installed_bash = bash_installed_output.gsub("installed", "not-installed")
      not_installed_bash.gsub!(bash_version, "")
      dpkg_query_execution_returns(not_installed_bash)

      expect(provider.query[:ensure]).to eq(:purged)
    end

    it "considers the package absent if it is marked 'config-files'" do
      dpkg_query_execution_returns(bash_installed_output.gsub("installed","config-files"))
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "considers the package absent if it is marked 'half-installed'" do
      dpkg_query_execution_returns(bash_installed_output.gsub("installed","half-installed"))
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "considers the package absent if it is marked 'unpacked'" do
      dpkg_query_execution_returns(bash_installed_output.gsub("installed","unpacked"))
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "considers the package absent if it is marked 'half-configured'" do
      dpkg_query_execution_returns(bash_installed_output.gsub("installed","half-configured"))
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "considers the package held if its state is 'hold'" do
      dpkg_query_execution_returns(bash_installed_output.gsub("install","hold"))
      expect(provider.query[:ensure]).to eq(:held)
    end

    context "parsing tests" do
      let(:resource_name) { 'name' }
      let(:package_hash) do
        {
          :desired => 'desired',
          :error => 'ok',
          :status => 'status',
          :name => resource_name,
          :ensure => 'ensure',
          :provider => :dpkg,
        }
      end
      let(:package_not_found_hash) do
        {:ensure => :purged, :status => 'missing', :name => resource_name, :error => 'ok'}
      end

      def parser_test(dpkg_output_string, gold_hash, number_of_debug_logs = 0)
        dpkg_query_execution_returns(dpkg_output_string)
        expect(Puppet).not_to receive(:warning)
        expect(Puppet).to receive(:debug).exactly(number_of_debug_logs).times

        expect(provider.query).to eq(gold_hash)
      end

      it "parses properly even if optional ensure field is missing" do
        no_ensure = 'desired ok status name '
        parser_test(no_ensure, package_hash.merge(:ensure => ''))
      end

      it "provides debug logging of unparsable lines" do
        parser_test('an unexpected dpkg msg with an exit code of 0', package_not_found_hash.merge(:ensure => :absent), 1)
      end

      it "does not log if execution returns with non-zero exit code" do
        expect(Puppet::Util::Execution).to receive(:execute).with(query_args, execute_options).and_raise(Puppet::ExecutionFailure.new("failed"))
        expect(Puppet).not_to receive(:debug)

        expect(provider.query).to eq(package_not_found_hash)
      end
    end
  end

  context "when installing" do
    before do
      allow(resource).to receive(:[]).with(:source).and_return("mypkg")
    end

    it "fails to install if no source is specified in the resource" do
      expect(resource).to receive(:[]).with(:source).and_return(nil)

      expect { provider.install }.to raise_error(ArgumentError)
    end

    it "uses 'dpkg -i' to install the package" do
      expect(resource).to receive(:[]).with(:source).and_return("mypackagefile")
      expect(provider).to receive(:unhold)
      expect(provider).to receive(:dpkg).with(any_args, "-i", "mypackagefile")

      provider.install
    end

    it "keeps old config files if told to do so" do
      expect(resource).to receive(:[]).with(:configfiles).and_return(:keep)
      expect(provider).to receive(:unhold)
      expect(provider).to receive(:dpkg).with("--force-confold", any_args)

      provider.install
    end

    it "replaces old config files if told to do so" do
      expect(resource).to receive(:[]).with(:configfiles).and_return(:replace)
      expect(provider).to receive(:unhold)
      expect(provider).to receive(:dpkg).with("--force-confnew", any_args)

      provider.install
    end

    it "ensures any hold is removed" do
      expect(provider).to receive(:unhold).once
      expect(provider).to receive(:dpkg)
      provider.install
    end
  end

  context "when holding or unholding" do
    let(:tempfile) { double('tempfile', :print => nil, :close => nil, :flush => nil, :path => "/other/file") }

    before do
      allow(tempfile).to receive(:write)
      allow(Tempfile).to receive(:open).and_yield(tempfile)
    end

    it "installs first if package is not present and ensure holding" do

      allow(provider).to receive(:execute)
      allow(provider).to receive(:package_not_installed?).and_return(false)
      expect(provider).to receive(:install).once
      provider.hold
    end

    it "skips install new package if package is allready installed" do
      allow(provider).to receive(:execute)
      allow(provider).to receive(:package_not_installed?).and_return(true)
      expect(provider).not_to receive(:install)
      provider.hold
    end

    it "executes dpkg --set-selections when holding" do
      allow(provider).to receive(:package_not_installed?).and_return(false)
      allow(provider).to receive(:install)
      expect(provider).to receive(:execute).with([:dpkg, '--set-selections'], {:failonfail => false, :combine => false, :stdinfile => tempfile.path}).once
      provider.hold
    end

    it "executes dpkg --set-selections when unholding" do
      allow(provider).to receive(:package_not_installed?).and_return(false)
      allow(provider).to receive(:install)
      expect(provider).to receive(:execute).with([:dpkg, '--set-selections'], {:failonfail => false, :combine => false, :stdinfile => tempfile.path}).once
      provider.hold
    end
  end

  it "uses :install to update" do
    expect(provider).to receive(:install)
    provider.update
  end

  context "when determining latest available version" do
    it "returns the version found by dpkg-deb" do
      expect(resource).to receive(:[]).with(:source).and_return("myfile")
      expect(provider).to receive(:dpkg_deb).with(any_args, "myfile").and_return("package\t1.0")
      expect(provider.latest).to eq("1.0")
    end

    it "warns if the package file contains a different package" do
      expect(provider).to receive(:dpkg_deb).and_return("foo\tversion")
      expect(provider).to receive(:warning)
      provider.latest
    end

    it "copes with names containing ++" do
      resource = double('resource', :[] => "package++")
      provider = described_class.new(resource)
      expect(provider).to receive(:dpkg_deb).and_return("package++\t1.0")
      expect(provider.latest).to eq("1.0")
    end
  end

  it "uses 'dpkg -r' to uninstall" do
    expect(provider).to receive(:dpkg).with("-r", resource_name)
    provider.uninstall
  end

  it "uses 'dpkg --purge' to purge" do
    expect(provider).to receive(:dpkg).with("--purge", resource_name)
    provider.purge
  end

  it "raises error if package name is nil" do
    expect {provider.package_not_installed?(nil)}.to raise_error(ArgumentError,"Package name is nil or empty")
    expect {provider.package_not_installed?("")}.to raise_error(ArgumentError,"Package name is nil or empty")
  end
end

