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
  let(:args) { ['myquery', '-W', '--showformat', %Q{'${Status} ${Package} ${Version}\\n'}] }
  let(:resource_name) { 'package' }
  let(:resource) { stub 'resource', :[] => resource_name }
  let(:provider) { provider_class.new(resource) }

  before do
    provider_class.stubs(:command).with(:dpkgquery).returns 'myquery'
  end

  it "should have documentation" do
    expect(provider_class.doc).to be_instance_of(String)
  end

  describe "when listing all instances" do

    it "should use dpkg-query" do
      Puppet::Util::Execution.expects(:execpipe).with(args).yields bash_installed_io

      provider_class.instances
    end

    it "should create and return an instance for a single dpkg-query entry" do
      Puppet::Util::Execution.expects(:execpipe).with(args).yields bash_installed_io

      installed = mock 'bash'
      provider_class.expects(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg).returns installed

      expect(provider_class.instances).to eq([installed])
    end

    it "should parse multiple dpkg-query multi-line entries in the output" do
      Puppet::Util::Execution.expects(:execpipe).with(args).yields all_installed_io

      bash = mock 'bash'
      provider_class.expects(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg).returns bash
      vim = mock 'vim'
      provider_class.expects(:new).with(:ensure => "2:7.3.547-6ubuntu5", :error => "ok", :desired => "install", :name => "vim", :status => "installed", :provider => :dpkg).returns vim

      expect(provider_class.instances).to eq([bash, vim])
    end

    it "should continue if encounters bad lines between good entries without failing" do
      Puppet::Util::Execution.expects(:execpipe).with(args).yields StringIO.new([bash_installed_output, "foobar\n", vim_installed_output].join)

      bash = mock 'bash'
      vim = mock 'vim'
      provider_class.expects(:new).twice.returns(bash, vim)

      expect(provider_class.instances).to eq([bash, vim])
    end
  end

  describe "when querying the current state" do
    let(:query_args) { args.push(resource_name) }

    before do
      provider.expects(:execute).never # forbid "manual" executions
    end

    # @return [StringIO] of bash dpkg-query output with :search string replaced
    # by :replace string.
    def replace_in_bash_output(search, replace)
      StringIO.new(bash_installed_output.gsub(search, replace))
    end

    it "should use exec-pipe" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields bash_installed_io

      provider.query
    end

    it "should consider the package purged if dpkg-query fails" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).raises Puppet::ExecutionFailure.new("eh")

      expect(provider.query[:ensure]).to eq(:purged)
    end

    it "should return a hash of the found package status for an installed package" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields bash_installed_io

      expect(provider.query).to eq({:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :status => "installed", :provider => :dpkg})
    end

    it "should consider the package absent if the dpkg-query result cannot be interpreted" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields StringIO.new("somebaddata")

      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "should fail if an error is discovered" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields replace_in_bash_output("ok", "error")

      expect { provider.query }.to raise_error(Puppet::Error)
    end

    it "should consider the package purged if it is marked 'not-installed'" do
      not_installed_bash = bash_installed_output.gsub("installed", "not-installed")
      not_installed_bash.gsub!(bash_version, "")
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields StringIO.new(not_installed_bash)

      expect(provider.query[:ensure]).to eq(:purged)
    end

    it "should consider the package absent if it is marked 'config-files'" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields replace_in_bash_output("installed", "config-files")
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "should consider the package absent if it is marked 'half-installed'" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields replace_in_bash_output("installed", "half-installed")
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "should consider the package absent if it is marked 'unpacked'" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields replace_in_bash_output("installed", "unpacked")
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "should consider the package absent if it is marked 'half-configured'" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields replace_in_bash_output("installed", "half-configured")
      expect(provider.query[:ensure]).to eq(:absent)
    end

    it "should consider the package held if its state is 'hold'" do
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields replace_in_bash_output("install", "hold")
      expect(provider.query[:ensure]).to eq(:held)
    end
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
    let(:query_args) { args.push(resource_name) }

    def parser_test(dpkg_output_string, gold_hash)
      pipe = StringIO.new(dpkg_output_string)
      Puppet::Util::Execution.expects(:execpipe).with(query_args).yields pipe
      Puppet.expects(:warning).never

      expect(provider.query).to eq(gold_hash)
    end

    it "should parse properly even if optional ensure field is missing" do
      no_ensure = 'desired ok status name '
      parser_test(no_ensure, package_hash.merge(:ensure => ''))
    end

    context "dpkg-query versions < 1.16" do
      it "parses dpkg-query 1.15 reporting that package does not exist without warning about a failed match (#22529)" do
        Puppet.expects(:warning).never
        pipe = StringIO.new("No packages found matching non-existent-package")
        Puppet::Util::Execution.expects(:execpipe).with(query_args).yields(pipe).raises(Puppet::ExecutionFailure.new('no package found'))

        expect(provider.query).to eq({:ensure=>:purged, :status=>"missing", :name=>"name", :error=>"ok"})
      end
    end

    context "dpkg-query versions >= 1.16" do
      it "parses dpkg-query 1.16 reporting that package does not exist without warning about a failed match (#22529)" do
        Puppet.expects(:warning).never
        pipe = StringIO.new("dpkg-query: no packages found matching non-existent-package")
        Puppet::Util::Execution.expects(:execpipe).with(query_args).yields(pipe).raises(Puppet::ExecutionFailure.new('no package found'))

        expect(provider.query).to eq({:ensure=>:purged, :status=>"missing", :name=>"name", :error=>"ok"})
      end
    end
  end

  it "should be able to install" do
    expect(provider).to respond_to(:install)
  end

  describe "when installing" do
    before do
      resource.stubs(:[]).with(:source).returns "mypkg"
    end

    it "should fail to install if no source is specified in the resource" do
      resource.expects(:[]).with(:source).returns nil

      expect { provider.install }.to raise_error(ArgumentError)
    end

    it "should use 'dpkg -i' to install the package" do
      resource.expects(:[]).with(:source).returns "mypackagefile"
      provider.expects(:unhold)
      provider.expects(:dpkg).with { |*command| command[-1] == "mypackagefile"  and command[-2] == "-i" }

      provider.install
    end

    it "should keep old config files if told to do so" do
      resource.expects(:[]).with(:configfiles).returns :keep
      provider.expects(:unhold)
      provider.expects(:dpkg).with { |*command| command[0] == "--force-confold" }

      provider.install
    end

    it "should replace old config files if told to do so" do
      resource.expects(:[]).with(:configfiles).returns :replace
      provider.expects(:unhold)
      provider.expects(:dpkg).with { |*command| command[0] == "--force-confnew" }

      provider.install
    end

    it "should ensure any hold is removed" do
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

    it "should install first if holding" do
      provider.stubs(:execute)
      provider.expects(:install).once
      provider.hold
    end

    it "should execute dpkg --set-selections when holding" do
      provider.stubs(:install)
      provider.expects(:execute).with([:dpkg, '--set-selections'], {:failonfail => false, :combine => false, :stdinfile => tempfile.path}).once
      provider.hold
    end

    it "should execute dpkg --set-selections when unholding" do
      provider.stubs(:install)
      provider.expects(:execute).with([:dpkg, '--set-selections'], {:failonfail => false, :combine => false, :stdinfile => tempfile.path}).once
      provider.hold
    end
  end

  it "should use :install to update" do
    provider.expects(:install)
    provider.update
  end

  describe "when determining latest available version" do
    it "should return the version found by dpkg-deb" do
      resource.expects(:[]).with(:source).returns "myfile"
      provider.expects(:dpkg_deb).with { |*command| command[-1] == "myfile" }.returns "package\t1.0"
      expect(provider.latest).to eq("1.0")
    end

    it "should warn if the package file contains a different package" do
      provider.expects(:dpkg_deb).returns("foo\tversion")
      provider.expects(:warning)
      provider.latest
    end

    it "should cope with names containing ++" do
      resource = stub 'resource', :[] => "package++"
      provider = provider_class.new(resource)
      provider.expects(:dpkg_deb).returns "package++\t1.0"
      expect(provider.latest).to eq("1.0")
    end
  end

  it "should use 'dpkg -r' to uninstall" do
    provider.expects(:dpkg).with("-r", resource_name)
    provider.uninstall
  end

  it "should use 'dpkg --purge' to purge" do
    provider.expects(:dpkg).with("--purge", resource_name)
    provider.purge
  end
end
