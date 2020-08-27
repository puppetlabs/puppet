require 'spec_helper'
require 'stringio'

describe Puppet::Type.type(:package).provider(:dpkg), unless: Puppet::Util::Platform.jruby? do
  let(:bash_version) { '4.2-5ubuntu3' }
  let(:bash_installed_output) { "install ok installed bash #{bash_version}\n" }
  let(:bash_installed_io) { StringIO.new(bash_installed_output) }
  let(:vim_installed_output) { "install ok installed vim 2:7.3.547-6ubuntu5\n" }
  let(:all_installed_io) { StringIO.new([bash_installed_output, vim_installed_output].join) }
  let(:args) { ['-W', '--showformat', %Q{'${Status} ${Package} ${Version}\\n'}] }
  let(:args_with_provides) { ['/bin/dpkg-query','-W', '--showformat', %Q{'${Status} ${Package} ${Version} [${Provides}]\\n'}]}
  let(:execute_options) do
    {:failonfail => true, :combine => true, :custom_environment => {}}
  end
  let(:resource_name) { 'python' }
  let(:resource) { double('resource', :[] => resource_name) }
  let(:dpkg_query_result) { 'install ok installed python 2.7.13' }
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
      expect(described_class).to receive(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :mark => :none, :status => "installed", :provider => :dpkg).and_return(installed)

      expect(described_class.instances).to eq([installed])
    end

    it "parses multiple dpkg-query multi-line entries in the output" do
      expect(Puppet::Util::Execution).to receive(:execpipe).with(execpipe_args).and_yield(all_installed_io)

      bash = double('bash')
      expect(described_class).to receive(:new).with(:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :mark => :none, :status => "installed", :provider => :dpkg).and_return(bash)
      vim = double('vim')
      expect(described_class).to receive(:new).with(:ensure => "2:7.3.547-6ubuntu5", :error => "ok", :desired => "install", :name => "vim", :mark => :none, :status => "installed", :provider => :dpkg).and_return(vim)

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

    def dpkg_query_execution_with_multiple_args_returns(output, *args)
      args.each do |arg|
        allow(Puppet::Util::Execution).to receive(:execute).with(arg, execute_options).and_return(Puppet::Util::Execution::ProcessOutput.new(output, 0))
      end
    end

    before do
      allow(Puppet::Util).to receive(:which).with('/usr/bin/dpkg-query').and_return(dpkgquery_path)
    end

    it "considers the package purged if dpkg-query fails" do
      allow(resource).to receive(:allow_virtual?).and_return(false)
      allow(Puppet::Util::Execution).to receive(:execute).with(query_args, execute_options).and_raise(Puppet::ExecutionFailure.new("eh"))

      expect(provider.query[:ensure]).to eq(:purged)
    end

    context "allow_virtual true" do
      before do
        allow(resource).to receive(:allow_virtual?).and_return(true)
      end

      context "virtual_packages" do
        let(:query_output) { 'install ok installed python 2.7.13 [python-ctypes, python-email, python-importlib, python-profiler, python-wsgiref, python-gold]' }
        let(:virtual_packages_query_args) do
          result = args_with_provides.dup
          result.push(resource_name)
        end

        it "considers the package purged if dpkg-query fails" do
          allow(Puppet::Util::Execution).to receive(:execute).with(args_with_provides, execute_options).and_raise(Puppet::ExecutionFailure.new("eh"))
          expect(provider.query[:ensure]).to eq(:purged)
        end

        it "returns a hash of the found package status for an installed package" do
          dpkg_query_execution_with_multiple_args_returns(query_output, args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result, args, query_args)
          expect(provider.query).to eq(:ensure => "2.7.13", :error => "ok", :desired => "install", :name => "python", :mark => :none, :status => "installed", :provider => :dpkg)
        end

        it "considers the package absent if the dpkg-query result cannot be interpreted" do
          dpkg_query_execution_with_multiple_args_returns('some-bad-data',args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns('some-bad-data', args, query_args)
          expect(provider.query[:ensure]).to eq(:absent)
        end

        it "fails if an error is discovered" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("ok","error"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("ok","error"), args, query_args)
          expect { provider.query }.to raise_error(Puppet::Error,  /Package python, version 2.7.13 is in error state: error/)
        end

        it "considers the package purged if it is marked 'not-installed" do
          not_installed_query = query_output.gsub("installed", "not-installed").delete!('2.7.13')
          dpkg_query_execution_with_multiple_args_returns(not_installed_query, args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("installed", "not-installed").delete!('2.7.13'), args, query_args)
          expect(provider.query[:ensure]).to eq(:purged)
        end

        it "considers the package absent if it is marked 'config-files'" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("installed","config-files"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("installed","config-files"), args, query_args)
          expect(provider.query[:ensure]).to eq(:absent)
        end

        it "considers the package absent if it is marked 'half-installed'" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("installed","half-installed"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("installed","half-installed"), args, query_args)
          expect(provider.query[:ensure]).to eq(:absent)
        end

        it "considers the package absent if it is marked 'unpacked'" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("installed","unpacked"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("installed","unpacked"), args, query_args)
          expect(provider.query[:ensure]).to eq(:absent)
        end

        it "considers the package absent if it is marked 'half-configured'" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("installed","half-configured"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("installed","half-configured"), args, query_args)
          expect(provider.query[:ensure]).to eq(:absent)
        end

        it "considers the package held if its state is 'hold'" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("install","hold"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("install","hold"), args, query_args)
          expect(provider.query[:ensure]).to eq("2.7.13")
          expect(provider.query[:mark]).to eq(:hold)
        end

        it "considers the package held if its state is 'hold'" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("install","hold"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("install","hold"), args, query_args)
          expect(provider.query[:ensure]).to eq("2.7.13")
          expect(provider.query[:mark]).to eq(:hold)
        end

        it "considers mark status to be none if package is not held" do
          dpkg_query_execution_with_multiple_args_returns(query_output.gsub("install","ok"),args_with_provides,virtual_packages_query_args)
          dpkg_query_execution_with_multiple_args_returns(dpkg_query_result.gsub("install","ok"), args, query_args)
          expect(provider.query[:ensure]).to eq("2.7.13")
          expect(provider.query[:mark]).to eq(:none)
        end

        context "regex check for query search" do
          let(:resource_name) { 'python-email' }
          let(:resource) { instance_double('Puppet::Type::Package') }
          before do
            allow(resource).to receive(:[]).with(:name).and_return(resource_name)
            allow(resource).to receive(:[]=)
          end

          it "checks if virtual package regex for query is correct and physical package is installed" do
            dpkg_query_execution_with_multiple_args_returns(query_output,args_with_provides,virtual_packages_query_args)
            dpkg_query_execution_with_multiple_args_returns(dpkg_query_result, args, query_args)
            expect(provider.query).to match({:desired => "install", :ensure => "2.7.13", :error => "ok", :name => "python", :mark => :none, :provider => :dpkg, :status => "installed"})
          end

          context "regex check with no partial matching" do
            let(:resource_name) { 'python-em' }

            it "checks if virtual package regex for query is correct and regext dosen't make partial matching" do
              expect(provider).to receive(:dpkgquery).with('-W', '--showformat', %Q{'${Status} ${Package} ${Version} [${Provides}]\\n'}).and_return(query_output)
              expect(provider).to receive(:dpkgquery).with('-W', '--showformat', %Q{'${Status} ${Package} ${Version}\\n'}, resource_name).and_return("#{dpkg_query_result} #{resource_name}")

              provider.query
            end

            context "regex check with special characters" do
              let(:resource_name) { 'g++' }

              it "checks if virtual package regex for query is correct and regext dosen't make partial matching" do
                expect(Puppet).to_not receive(:info).with(/is virtual/)
                expect(provider).to receive(:dpkgquery).with('-W', '--showformat', %Q{'${Status} ${Package} ${Version} [${Provides}]\\n'}).and_return(query_output)
                expect(provider).to receive(:dpkgquery).with('-W', '--showformat', %Q{'${Status} ${Package} ${Version}\\n'}, resource_name).and_return("#{dpkg_query_result} #{resource_name}")

                provider.query
              end
            end
          end
        end
      end
    end

    context "allow_virtual false" do
      before do
        allow(resource).to receive(:allow_virtual?).and_return(false)
      end

      it "returns a hash of the found package status for an installed package" do
        dpkg_query_execution_returns(bash_installed_output)

        expect(provider.query).to eq({:ensure => "4.2-5ubuntu3", :error => "ok", :desired => "install", :name => "bash", :mark => :none, :status => "installed", :provider => :dpkg})
      end

      it "considers the package absent if the dpkg-query result cannot be interpreted" do
        allow(resource).to receive(:allow_virtual?).and_return(false)
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

      it "considers the package held if its state is 'hold'" do
        dpkg_query_execution_returns(bash_installed_output.gsub("install","hold"))
        query=provider.query
        expect(query[:ensure]).to eq("4.2-5ubuntu3")
        expect(query[:mark]).to eq(:hold)
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
        query=provider.query
        expect(query[:ensure]).to eq("4.2-5ubuntu3")
        expect(query[:mark]).to eq(:hold)
      end

      context "parsing tests" do
        let(:resource_name) { 'name' }
        let(:package_hash) do
          {
            :desired => 'desired',
            :error => 'ok',
            :status => 'status',
            :name => resource_name,
            :mark => :none,
            :ensure => 'ensure',
            :provider => :dpkg,
          }
        end

        let(:package_not_found_hash) do
          {:ensure => :purged, :status => 'missing', :name => resource_name, :error => 'ok'}
        end

        let(:output) {'an unexpected dpkg msg with an exit code of 0'}

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

        it "provides debug logging of unparsable lines with allow_virtual enabled" do
          allow(resource).to receive(:allow_virtual?).and_return(true)
          dpkg_query_execution_with_multiple_args_returns(output, args_with_provides, query_args)
          expect(Puppet).not_to receive(:warning)
          expect(Puppet).to receive(:debug).exactly(1).times
          expect(provider.query).to eq(package_not_found_hash.merge(:ensure => :absent))
        end

        it "provides debug logging of unparsable lines" do
          parser_test('an unexpected dpkg msg with an exit code of 0', package_not_found_hash.merge(:ensure => :absent), 1)
        end

        it "does not log if execution returns with non-zero exit code with allow_virtual enabled" do
          allow(resource).to receive(:allow_virtual?).and_return(true)
          expect(Puppet::Util::Execution).to receive(:execute).with(args_with_provides, execute_options).and_raise(Puppet::ExecutionFailure.new("failed"))
          expect(Puppet).not_to receive(:debug)
          expect(provider.query).to eq(package_not_found_hash)
        end

        it "does not log if execution returns with non-zero exit code" do
          expect(Puppet::Util::Execution).to receive(:execute).with(query_args, execute_options).and_raise(Puppet::ExecutionFailure.new("failed"))
          expect(Puppet).not_to receive(:debug)

          expect(provider.query).to eq(package_not_found_hash)
        end
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
      expect(provider).to receive(:properties).and_return({:mark => :hold})
      expect(provider).to receive(:unhold)
      expect(provider).to receive(:dpkg).with(any_args, "-i", "mypackagefile")
      provider.install
    end

    it "keeps old config files if told to do so" do
      expect(resource).to receive(:[]).with(:configfiles).and_return(:keep)
      expect(provider).to receive(:properties).and_return({:mark => :hold})
      expect(provider).to receive(:unhold)
      expect(provider).to receive(:dpkg).with("--force-confold", any_args)

      provider.install
    end

    it "replaces old config files if told to do so" do
      expect(resource).to receive(:[]).with(:configfiles).and_return(:replace)
      expect(provider).to receive(:properties).and_return({:mark => :hold})
      expect(provider).to receive(:unhold)
      expect(provider).to receive(:dpkg).with("--force-confnew", any_args)

      provider.install
    end

    it "ensures any hold is removed" do
      expect(provider).to receive(:properties).and_return({:mark => :hold})
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

    it "executes dpkg --set-selections when holding" do
      allow(provider).to receive(:install)
      expect(provider).to receive(:execute).with([:dpkg, '--set-selections'], {:failonfail => false, :combine => false, :stdinfile => tempfile.path}).once
      provider.hold
    end

    it "executes dpkg --set-selections when unholding" do
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
      expect(resource).to receive(:[]).with(:source).and_return("python")
      expect(provider).to receive(:dpkg_deb).with('--show', "python").and_return("package\t1.0")
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

end
