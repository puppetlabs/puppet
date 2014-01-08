#! /usr/bin/env ruby
require 'spec_helper'
require 'stringio'

provider_class = Puppet::Type.type(:package).provider(:dpkg)

describe provider_class do
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
  let(:resource) { stub 'resource', :[] => resource_name }
  let(:provider) { provider_class.new(resource) }

  it "has documentation" do
    expect(provider_class.doc).to be_instance_of(String)
  end

  describe "when listing all instances" do
    let(:execpipe_args) { args.unshift('myquery') }

    before do
      provider_class.stubs(:command).with(:dpkgquery).returns 'myquery'
    end

    it "creates and return an instance for a single dpkg-query entry" do
      Puppet::Util::Execution.expects(:execpipe).with(execpipe_args).yields bash_installed_io

      installed = mock 'bash'
      provider_class.expects(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg).returns installed

      expect(provider_class.instances).to eq([installed])
    end

    it "parses multiple dpkg-query multi-line entries in the output" do
      Puppet::Util::Execution.expects(:execpipe).with(execpipe_args).yields all_installed_io

      bash = mock 'bash'
      provider_class.expects(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg).returns bash
      vim = mock 'vim'
      provider_class.expects(:new).with(:ensure => "2:7.3.547-6ubuntu5", :error => "ok", :desired => "install", :name => "vim", :status => "installed", :provider => :dpkg).returns vim

      expect(provider_class.instances).to eq([bash, vim])
    end

    it "continues without failing if it encounters bad lines between good entries" do
      Puppet::Util::Execution.expects(:execpipe).with(execpipe_args).yields StringIO.new([bash_installed_output, "foobar\n", vim_installed_output].join)

      bash = mock 'bash'
      vim = mock 'vim'
      provider_class.expects(:new).twice.returns(bash, vim)

      expect(provider_class.instances).to eq([bash, vim])
    end
  end

  describe "when querying the current state" do
    let(:dpkgquery_path) { '/bin/dpkg-query' }
    let(:query_args) do
      args.unshift(dpkgquery_path)
      args.push(resource_name)
    end

    def dpkg_query_execution_returns(output)
      Puppet::Util::Execution.expects(:execute).with(query_args, execute_options).returns(output)
    end

    before do
      Puppet::Util.stubs(:which).with('/usr/bin/dpkg-query').returns(dpkgquery_path)
    end

    it "considers the package purged if dpkg-query fails" do
      Puppet::Util::Execution.expects(:execute).with(query_args, execute_options).raises Puppet::ExecutionFailure.new("eh")

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

    describe "parsing tests" do
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
        Puppet.expects(:warning).never
        Puppet.expects(:debug).times(number_of_debug_logs)

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
        Puppet::Util::Execution.expects(:execute).with(query_args, execute_options).raises Puppet::ExecutionFailure.new("failed")
        Puppet::expects(:debug).never

        expect(provider.query).to eq(package_not_found_hash)
      end
    end
  end

  describe "when installing" do
    before do
      resource.stubs(:[]).with(:source).returns "mypkg"
    end

    it "fails to install if no source is specified in the resource" do
      resource.expects(:[]).with(:source).returns nil

      expect { provider.install }.to raise_error(ArgumentError)
    end

    it "uses 'dpkg -i' to install the package" do
      resource.expects(:[]).with(:source).returns "mypackagefile"
      provider.expects(:unhold)
      provider.expects(:dpkg).with { |*command| command[-1] == "mypackagefile"  and command[-2] == "-i" }

      provider.install
    end

    it "keeps old config files if told to do so" do
      resource.expects(:[]).with(:configfiles).returns :keep
      provider.expects(:unhold)
      provider.expects(:dpkg).with { |*command| command[0] == "--force-confold" }

      provider.install
    end

    it "replaces old config files if told to do so" do
      resource.expects(:[]).with(:configfiles).returns :replace
      provider.expects(:unhold)
      provider.expects(:dpkg).with { |*command| command[0] == "--force-confnew" }

      provider.install
    end

    it "ensures any hold is removed" do
      provider.expects(:unhold).once
      provider.expects(:dpkg)
      provider.install
    end
  end

  describe "when holding or unholding" do
    let(:tempfile) { stub 'tempfile', :print => nil, :close => nil, :flush => nil, :path => "/other/file" }

    before do
      tempfile.stubs(:write)
      Tempfile.stubs(:new).returns tempfile
    end

    it "installs first if holding" do
      provider.stubs(:execute)
      provider.expects(:install).once
      provider.hold
    end

    it "executes dpkg --set-selections when holding" do
      provider.stubs(:install)
      provider.expects(:execute).with([:dpkg, '--set-selections'], {:failonfail => false, :combine => false, :stdinfile => tempfile.path}).once
      provider.hold
    end

    it "executes dpkg --set-selections when unholding" do
      provider.stubs(:install)
      provider.expects(:execute).with([:dpkg, '--set-selections'], {:failonfail => false, :combine => false, :stdinfile => tempfile.path}).once
      provider.hold
    end
  end

  it "uses :install to update" do
    provider.expects(:install)
    provider.update
  end

  describe "when determining latest available version" do
    it "returns the version found by dpkg-deb" do
      resource.expects(:[]).with(:source).returns "myfile"
      provider.expects(:dpkg_deb).with { |*command| command[-1] == "myfile" }.returns "package\t1.0"
      expect(provider.latest).to eq("1.0")
    end

    it "warns if the package file contains a different package" do
      provider.expects(:dpkg_deb).returns("foo\tversion")
      provider.expects(:warning)
      provider.latest
    end

    it "copes with names containing ++" do
      resource = stub 'resource', :[] => "package++"
      provider = provider_class.new(resource)
      provider.expects(:dpkg_deb).returns "package++\t1.0"
      expect(provider.latest).to eq("1.0")
    end
  end

  it "uses 'dpkg -r' to uninstall" do
    provider.expects(:dpkg).with("-r", resource_name)
    provider.uninstall
  end

  it "uses 'dpkg --purge' to purge" do
    provider.expects(:dpkg).with("--purge", resource_name)
    provider.purge
  end
end
