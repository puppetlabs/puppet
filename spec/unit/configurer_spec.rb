require 'spec_helper'
require 'puppet/configurer'

describe Puppet::Configurer do
  before do
    allow(Puppet.settings).to receive(:use).and_return(true)
    @agent = Puppet::Configurer.new
    allow(@agent).to receive(:init_storage)
    allow(Puppet::Util::Storage).to receive(:store)
    Puppet[:server] = "puppetmaster"
    Puppet[:report] = true
  end

  it "should include the Fact Handler module" do
    expect(Puppet::Configurer.ancestors).to be_include(Puppet::Configurer::FactHandler)
  end

  describe "when executing a pre-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Puppet.settings[:prerun_command] = ""
      expect(Puppet::Util).not_to receive(:exec)

      @agent.execute_prerun_command
    end

    it "should execute any pre-run command provided via the 'prerun_command' setting" do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      @agent.execute_prerun_command
    end

    it "should fail if the command fails" do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(@agent.execute_prerun_command).to be_falsey
    end
  end

  describe "when executing a post-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Puppet.settings[:postrun_command] = ""
      expect(Puppet::Util).not_to receive(:exec)

      @agent.execute_postrun_command
    end

    it "should execute any post-run command provided via the 'postrun_command' setting" do
      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      @agent.execute_postrun_command
    end

    it "should fail if the command fails" do
      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(@agent.execute_postrun_command).to be_falsey
    end
  end

  describe "when executing a catalog run" do
    before do
      allow(Puppet.settings).to receive(:use).and_return(true)
      allow(@agent).to receive(:download_plugins)
      Puppet::Node::Facts.indirection.terminus_class = :memory
      @facts = Puppet::Node::Facts.new(Puppet[:node_name_value])
      Puppet::Node::Facts.indirection.save(@facts)

      @catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment].to_sym))
      allow(@catalog).to receive(:to_ral).and_return(@catalog)
      Puppet::Resource::Catalog.indirection.terminus_class = :rest
      allow(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(@catalog)
      allow(@agent).to receive(:send_report)
      allow(@agent).to receive(:save_last_run_summary)

      allow(Puppet::Util::Log).to receive(:close_all)
    end

    after :all do
      Puppet::Node::Facts.indirection.reset_terminus_class
      Puppet::Resource::Catalog.indirection.reset_terminus_class
    end

    it "should initialize storage" do
      expect(Puppet::Util::Storage).to receive(:load)
      @agent.run
    end

    it "downloads plugins when told" do
      expect(@agent).to receive(:download_plugins)
      @agent.run(:pluginsync => true)
    end

    it "does not download plugins when told" do
      expect(@agent).not_to receive(:download_plugins)
      @agent.run(:pluginsync => false)
    end

    it "should carry on when it can't fetch its node definition" do
      error = Net::HTTPError.new(400, 'dummy server communication error')
      expect(Puppet::Node.indirection).to receive(:find).and_raise(error)
      expect(@agent.run).to eq(0)
    end

    it "applies a cached catalog when it can't connect to the master" do
      error = Errno::ECONNREFUSED.new('Connection refused - connect(2)')

      expect(Puppet::Node.indirection).to receive(:find).and_raise(error)
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(:ignore_cache => true)).and_raise(error)
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(:ignore_terminus => true)).and_return(@catalog)

      expect(@agent.run).to eq(0)
    end

    it "should initialize a transaction report if one is not provided" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      @agent.run
    end

    it "should respect node_name_fact when setting the host on a report" do
      Puppet[:node_name_fact] = 'my_name_fact'
      @facts.values = {'my_name_fact' => 'node_name_from_fact'}

      report = Puppet::Transaction::Report.new

      @agent.run(:report => report)
      expect(report.host).to eq('node_name_from_fact')
    end

    it "should pass the new report to the catalog" do
      report = Puppet::Transaction::Report.new
      allow(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(@catalog).to receive(:apply).with(hash_including(report: report))

      @agent.run
    end

    it "should use the provided report if it was passed one" do
      report = Puppet::Transaction::Report.new
      expect(@catalog).to receive(:apply).with(hash_including(report: report))

      @agent.run(:report => report)
    end

    it "should set the report as a log destination" do
      report = Puppet::Transaction::Report.new

      expect(report).to receive(:<<).with(instance_of(Puppet::Util::Log)).at_least(:once)

      @agent.run(:report => report)
    end

    it "should retrieve the catalog" do
      expect(@agent).to receive(:retrieve_catalog)

      @agent.run
    end

    it "should log a failure and do nothing if no catalog can be retrieved" do
      expect(@agent).to receive(:retrieve_catalog).and_return(nil)

      expect(Puppet).to receive(:err).with("Could not retrieve catalog; skipping run")

      @agent.run
    end

    it "should apply the catalog with all options to :run" do
      expect(@agent).to receive(:retrieve_catalog).and_return(@catalog)

      expect(@catalog).to receive(:apply).with(hash_including(one: true))
      @agent.run :one => true
    end

    it "should accept a catalog and use it instead of retrieving a different one" do
      expect(@agent).not_to receive(:retrieve_catalog)

      expect(@catalog).to receive(:apply)
      @agent.run :one => true, :catalog => @catalog
    end

    it "should benchmark how long it takes to apply the catalog" do
      expect(@agent).to receive(:benchmark).with(:notice, instance_of(String))

      expect(@agent).to receive(:retrieve_catalog).and_return(@catalog)

      expect(@catalog).not_to receive(:apply) # because we're not yielding
      @agent.run
    end

    it "should execute post-run hooks after the run" do
      expect(@agent).to receive(:execute_postrun_command)

      @agent.run
    end

    it "should create report with passed transaction_uuid and job_id" do
      @agent = Puppet::Configurer.new("test_tuuid", "test_jid")
      allow(@agent).to receive(:init_storage)

      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).with(anything, anything, 'test_tuuid', 'test_jid').and_return(report)
      expect(@agent).to receive(:send_report).with(report)

      @agent.run
    end

    it "should send the report" do
      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(@agent).to receive(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      @agent.run
    end

    it "should send the transaction report even if the catalog could not be retrieved" do
      expect(@agent).to receive(:retrieve_catalog).and_return(nil)

      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(@agent).to receive(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      @agent.run
    end

    it "should send the transaction report even if there is a failure" do
      expect(@agent).to receive(:retrieve_catalog).and_raise("whatever")

      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(@agent).to receive(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      expect(@agent.run).to be_nil
    end

    it "should remove the report as a log destination when the run is finished" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      @agent.run

      expect(Puppet::Util::Log.destinations).not_to include(report)
    end

    it "should return the report exit_status as the result of the run" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(report).to receive(:exit_status).and_return(1234)

      expect(@agent.run).to eq(1234)
    end

    it "should return nil if catalog application fails" do
      expect(@catalog).to receive(:apply).and_raise(Puppet::Error, 'One or more resource dependency cycles detected in graph')
      report = Puppet::Transaction::Report.new
      expect(@agent.run(catalog: @catalog, report: report)).to be_nil
    end

    it "should send the transaction report even if the pre-run command fails" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")
      expect(@agent).to receive(:send_report).with(report)

      expect(@agent.run).to be_nil
    end

    it "should include the pre-run command failure in the report" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(@agent.run).to be_nil
      expect(report.logs.find { |x| x.message =~ /Could not run command from prerun_command/ }).to be
    end

    it "should send the transaction report even if the post-run command fails" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")
      expect(@agent).to receive(:send_report).with(report)

      expect(@agent.run).to be_nil
    end

    it "should include the post-run command failure in the report" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(report).to receive(:<<) { |log, _| expect(log.message).to match(/Could not run command from postrun_command/) }.at_least(:once)

      expect(@agent.run).to be_nil
    end

    it "should execute post-run command even if the pre-run command fails" do
      Puppet.settings[:prerun_command] = "/my/precommand"
      Puppet.settings[:postrun_command] = "/my/postcommand"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/precommand"]).and_raise(Puppet::ExecutionFailure, "Failed")
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/postcommand"])

      expect(@agent.run).to be_nil
    end

    it "should finalize the report" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      expect(report).to receive(:finalize_report)
      @agent.run
    end

    it "should not apply the catalog if the pre-run command fails" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(@catalog).not_to receive(:apply)
      expect(@agent).to receive(:send_report)

      expect(@agent.run).to be_nil
    end

    it "should apply the catalog, send the report, and return nil if the post-run command fails" do
      report = Puppet::Transaction::Report.new
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(@catalog).to receive(:apply)
      expect(@agent).to receive(:send_report)

      expect(@agent.run).to be_nil
    end

    it 'includes total time metrics in the report after successfully applying the catalog' do
      report = Puppet::Transaction::Report.new
      allow(@catalog).to receive(:apply).with(:report => report)
      @agent.run(report: report)

      expect(report.metrics['time']).to be
      expect(report.metrics['time']['total']).to be_a_kind_of(Numeric)
    end

    it 'includes total time metrics in the report even if prerun fails' do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      report = Puppet::Transaction::Report.new
      @agent.run(report: report)

      expect(report.metrics['time']).to be
      expect(report.metrics['time']['total']).to be_a_kind_of(Numeric)
    end

    it 'includes total time metrics in the report even if catalog retrieval fails' do
      report = Puppet::Transaction::Report.new
      allow(@agent).to receive(:prepare_and_retrieve_catalog_from_cache).and_raise
      @agent.run(:report => report)

      expect(report.metrics['time']).to be
      expect(report.metrics['time']['total']).to be_a_kind_of(Numeric)
    end

    it "should refetch the catalog if the server specifies a new environment in the catalog" do
      catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
      expect(@agent).to receive(:retrieve_catalog).and_return(catalog).twice

      @agent.run
    end

    it "should change the environment setting if the server specifies a new environment in the catalog" do
      allow(@catalog).to receive(:environment).and_return("second_env")

      @agent.run

      expect(@agent.environment).to eq("second_env")
    end

    it "should fix the report if the server specifies a new environment in the catalog" do
      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(@agent).to receive(:send_report).with(report)

      allow(@catalog).to receive(:environment).and_return("second_env")
      allow(@agent).to receive(:retrieve_catalog).and_return(@catalog)

      @agent.run

      expect(report.environment).to eq("second_env")
    end

    it "sends the transaction uuid in a catalog request" do
      @agent.instance_variable_set(:@transaction_uuid, 'aaa')
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(transaction_uuid: 'aaa'))
      @agent.run
    end

    it "sends the transaction uuid in a catalog request" do
      @agent.instance_variable_set(:@job_id, 'aaa')
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(job_id: 'aaa'))
      @agent.run
    end

    it "sets the static_catalog query param to true in a catalog request" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(static_catalog: true))
      @agent.run
    end

    it "sets the checksum_type query param to the default supported_checksum_types in a catalog request" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything,
        hash_including(checksum_type: 'md5.sha256.sha384.sha512.sha224'))
      @agent.run
    end

    it "sets the checksum_type query param to the supported_checksum_types setting in a catalog request" do
      # Regenerate the agent to pick up the new setting
      Puppet[:supported_checksum_types] = ['sha256']
      @agent = Puppet::Configurer.new
      allow(@agent).to receive(:init_storage)
      allow(@agent).to receive(:download_plugins)
      allow(@agent).to receive(:send_report)
      allow(@agent).to receive(:save_last_run_summary)

      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(checksum_type: 'sha256'))
      @agent.run
    end

    describe "when not using a REST terminus for catalogs" do
      it "should not pass any facts when retrieving the catalog" do
        Puppet::Resource::Catalog.indirection.terminus_class = :compiler
        expect(@agent).not_to receive(:facts_for_uploading)
        expect(Puppet::Resource::Catalog.indirection).to receive(:find) do |name, options|
          options[:facts].nil?
        end.and_return(@catalog)

        @agent.run
      end
    end

    describe "when using a REST terminus for catalogs" do
      it "should pass the prepared facts and the facts format as arguments when retrieving the catalog" do
        Puppet::Resource::Catalog.indirection.terminus_class = :rest
        expect(@agent).to receive(:facts_for_uploading).and_return(:facts => "myfacts", :facts_format => :foo)
        expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(facts: "myfacts", facts_format: :foo)).and_return(@catalog)

        @agent.run
      end
    end
  end

  describe "when initialized with a transaction_uuid" do
    it "stores it" do
      expect(SecureRandom).not_to receive(:uuid)
      configurer = Puppet::Configurer.new('foo')
      expect(configurer.instance_variable_get(:@transaction_uuid) == 'foo')
    end
  end

  describe "when sending a report" do
    include PuppetSpec::Files

    before do
      allow(Puppet.settings).to receive(:use).and_return(true)
      @configurer = Puppet::Configurer.new
      Puppet[:lastrunfile] = tmpfile('last_run_file')

      @report = Puppet::Transaction::Report.new
      Puppet[:reports] = "none"
    end

    it "should print a report summary if configured to do so" do
      Puppet.settings[:summarize] = true

      expect(@report).to receive(:summary).and_return("stuff")

      expect(@configurer).to receive(:puts).with("stuff")
      @configurer.send_report(@report)
    end

    it "should not print a report summary if not configured to do so" do
      Puppet.settings[:summarize] = false

      expect(@configurer).not_to receive(:puts)
      @configurer.send_report(@report)
    end

    it "should save the report if reporting is enabled" do
      Puppet.settings[:report] = true

      expect(Puppet::Transaction::Report.indirection).to receive(:save).with(@report, nil, instance_of(Hash))
      @configurer.send_report(@report)
    end

    it "should not save the report if reporting is disabled" do
      Puppet.settings[:report] = false

      expect(Puppet::Transaction::Report.indirection).not_to receive(:save).with(@report, nil, instance_of(Hash))
      @configurer.send_report(@report)
    end

    it "should save the last run summary if reporting is enabled" do
      Puppet.settings[:report] = true

      expect(@configurer).to receive(:save_last_run_summary).with(@report)
      @configurer.send_report(@report)
    end

    it "should save the last run summary if reporting is disabled" do
      Puppet.settings[:report] = false

      expect(@configurer).to receive(:save_last_run_summary).with(@report)
      @configurer.send_report(@report)
    end

    it "should log but not fail if saving the report fails" do
      Puppet.settings[:report] = true

      expect(Puppet::Transaction::Report.indirection).to receive(:save).and_raise("whatever")

      expect(Puppet).to receive(:err)
      expect { @configurer.send_report(@report) }.not_to raise_error
    end
  end

  describe "when saving the summary report file" do
    include PuppetSpec::Files

    before do
      allow(Puppet.settings).to receive(:use).and_return(true)
      @configurer = Puppet::Configurer.new

      @report = double('report', :raw_summary => {})

      Puppet[:lastrunfile] = tmpfile('last_run_file')
    end

    it "should write the last run file" do
      @configurer.save_last_run_summary(@report)
      expect(Puppet::FileSystem.exist?(Puppet[:lastrunfile])).to be_truthy
    end

    it "should write the raw summary as yaml" do
      expect(@report).to receive(:raw_summary).and_return("summary")
      @configurer.save_last_run_summary(@report)
      expect(File.read(Puppet[:lastrunfile])).to eq(YAML.dump("summary"))
    end

    it "should log but not fail if saving the last run summary fails" do
      # The mock will raise an exception on any method used.  This should
      # simulate a nice hard failure from the underlying OS for us.
      fh = Class.new(Object) do
        def method_missing(*args)
          raise "failed to do #{args[0]}"
        end
      end.new

      expect(Puppet::Util).to receive(:replace_file).and_yield(fh)

      expect(Puppet).to receive(:err)
      expect { @configurer.save_last_run_summary(@report) }.to_not raise_error
    end

    it "should create the last run file with the correct mode" do
      expect(Puppet.settings.setting(:lastrunfile)).to receive(:mode).and_return('664')
      @configurer.save_last_run_summary(@report)

      if Puppet::Util::Platform.windows?
        require 'puppet/util/windows/security'
        mode = Puppet::Util::Windows::Security.get_mode(Puppet[:lastrunfile])
      else
        mode = Puppet::FileSystem.stat(Puppet[:lastrunfile]).mode
      end
      expect(mode & 0777).to eq(0664)
    end

    it "should report invalid last run file permissions" do
      expect(Puppet.settings.setting(:lastrunfile)).to receive(:mode).and_return('892')
      expect(Puppet).to receive(:err).with(/Could not save last run local report.*892 is invalid/)
      @configurer.save_last_run_summary(@report)
    end
  end

  describe "when requesting a node" do
    it "uses the transaction uuid in the request" do
      expect(Puppet::Node.indirection).to receive(:find).with(anything, hash_including(transaction_uuid: anything)).twice
      @agent.run
    end

    it "sends an explicitly configured environment request" do
      expect(Puppet.settings).to receive(:set_by_config?).with(:environment).and_return(true)
      expect(Puppet::Node.indirection).to receive(:find).with(anything, hash_including(configured_environment: Puppet[:environment])).twice
      @agent.run
    end

    it "does not send a configured_environment when using the default" do
      expect(Puppet::Node.indirection).to receive(:find).with(anything, hash_including(configured_environment: nil)).twice
      @agent.run
    end
  end

  def expects_new_catalog_only(catalog)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(catalog)
    expect(Puppet::Resource::Catalog.indirection).not_to receive(:find).with(anything, hash_including(ignore_terminus: true))
  end

  def expects_cached_catalog_only(catalog)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(catalog)
    expect(Puppet::Resource::Catalog.indirection).not_to receive(:find).with(anything, hash_including(ignore_cache: true))
  end

  def expects_fallback_to_cached_catalog(catalog)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(nil)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(catalog)
  end

  def expects_fallback_to_new_catalog(catalog)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(nil)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(catalog)
  end

  def expects_neither_new_or_cached_catalog
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(nil)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(nil)
  end

  describe "when retrieving a catalog" do
    before do
      allow(Puppet.settings).to receive(:use).and_return(true)
      allow(@agent).to receive(:facts_for_uploading).and_return({})
      allow(@agent).to receive(:download_plugins)

      # retrieve a catalog in the current environment, so we don't try to converge unexpectedly
      @catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment].to_sym))

      # this is the default when using a Configurer instance
      allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class).and_return(:rest)
    end

    describe "and configured to only retrieve a catalog from the cache" do
      before do
        Puppet.settings[:use_cached_catalog] = true
      end

      it "should first look in the cache for a catalog" do
        expects_cached_catalog_only(@catalog)

        expect(@agent.retrieve_catalog({})).to eq(@catalog)
      end

      it "should not make a node request or pluginsync when a cached catalog is successfully retrieved" do
        expect(Puppet::Node.indirection).not_to receive(:find)
        expects_cached_catalog_only(@catalog)
        expect(@agent).not_to receive(:download_plugins)

        @agent.run
      end

      it "should make a node request and pluginsync when a cached catalog cannot be retrieved" do
        expect(Puppet::Node.indirection).to receive(:find).and_return(nil)
        expects_fallback_to_new_catalog(@catalog)
        expect(@agent).to receive(:download_plugins)

        @agent.run
      end

      it "should set its cached_catalog_status to 'explicitly_requested'" do
        expects_cached_catalog_only(@catalog)

        @agent.retrieve_catalog({})
        expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('explicitly_requested')
      end

      it "should set its cached_catalog_status to 'explicitly requested' if the cached catalog is from a different environment" do
        cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
        expects_cached_catalog_only(cached_catalog)

        @agent.retrieve_catalog({})
        expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('explicitly_requested')
      end

      it "should compile a new catalog if none is found in the cache" do
        expects_fallback_to_new_catalog(@catalog)

        expect(@agent.retrieve_catalog({})).to eq(@catalog)
      end

      it "should set its cached_catalog_status to 'not_used' if no catalog is found in the cache" do
        expects_fallback_to_new_catalog(@catalog)

        @agent.retrieve_catalog({})
        expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
      end

      it "should not attempt to retrieve a cached catalog again if the first attempt failed" do
        expect(Puppet::Node.indirection).to receive(:find).and_return(nil)
        expects_neither_new_or_cached_catalog

        @agent.run
      end

      it "should return the cached catalog when the environment doesn't match" do
        cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
        expects_cached_catalog_only(cached_catalog)

        expect(Puppet).to receive(:info).with("Using cached catalog from environment 'second_env'")
        expect(@agent.retrieve_catalog({})).to eq(cached_catalog)
      end
    end

    describe "and strict environment mode is set" do
      before do
        allow(@catalog).to receive(:to_ral).and_return(@catalog)
        allow(@catalog).to receive(:write_class_file)
        allow(@catalog).to receive(:write_resource_file)
        allow(@agent).to receive(:send_report)
        allow(@agent).to receive(:save_last_run_summary)
        Puppet.settings[:strict_environment_mode] = true
      end

      it "should not make a node request" do
        expect(Puppet::Node.indirection).not_to receive(:find)

        @agent.run
      end

      it "should return nil when the catalog's environment doesn't match the agent specified environment" do
        @agent.instance_variable_set(:@environment, 'second_env')
        expects_new_catalog_only(@catalog)

        expect(Puppet).to receive(:err).with("Not using catalog because its environment 'production' does not match agent specified environment 'second_env' and strict_environment_mode is set")
        expect(@agent.run).to be_nil
      end

      it "should not return nil when the catalog's environment matches the agent specified environment" do
        @agent.instance_variable_set(:@environment, 'production')
        expects_new_catalog_only(@catalog)

        expect(@agent.run).to eq(0)
      end

      describe "and a cached catalog is explicitly requested" do
        before do
          Puppet.settings[:use_cached_catalog] = true
        end

        it "should return nil when the cached catalog's environment doesn't match the agent specified environment" do
          @agent.instance_variable_set(:@environment, 'second_env')
          expects_cached_catalog_only(@catalog)

          expect(Puppet).to receive(:err).with("Not using catalog because its environment 'production' does not match agent specified environment 'second_env' and strict_environment_mode is set")
          expect(@agent.run).to be_nil
        end

        it "should proceed with the cached catalog if its environment matchs the local environment" do
          Puppet.settings[:use_cached_catalog] = true
          @agent.instance_variable_set(:@environment, 'production')
          expects_cached_catalog_only(@catalog)

          expect(@agent.run).to eq(0)
        end
      end
    end

    it "should use the Catalog class to get its catalog" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(@catalog)

      @agent.retrieve_catalog({})
    end

    it "should set its cached_catalog_status to 'not_used' when downloading a new catalog" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(@catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
    end

    it "should use its node_name_value to retrieve the catalog" do
      allow(Facter).to receive(:value).and_return("eh")
      Puppet.settings[:node_name_value] = "myhost.domain.com"
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with("myhost.domain.com", anything).and_return(@catalog)

      @agent.retrieve_catalog({})
    end

    it "should default to returning a catalog retrieved directly from the server, skipping the cache" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(@catalog)

      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should log and return the cached catalog when no catalog can be retrieved from the server" do
      expects_fallback_to_cached_catalog(@catalog)

      expect(Puppet).to receive(:info).with("Using cached catalog from environment 'production'")
      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should set its cached_catalog_status to 'on_failure' when no catalog can be retrieved from the server" do
      expects_fallback_to_cached_catalog(@catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('on_failure')
    end

    it "should not look in the cache for a catalog if one is returned from the server" do
      expects_new_catalog_only(@catalog)

      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should return the cached catalog when retrieving the remote catalog throws an exception" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_raise("eh")
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(@catalog)

      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should set its cached_catalog_status to 'on_failure' when retrieving the remote catalog throws an exception" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_raise("eh")
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(@catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('on_failure')
    end

    it "should log and return nil if no catalog can be retrieved from the server and :usecacheonfailure is disabled" do
      Puppet[:usecacheonfailure] = false
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(nil)

      expect(Puppet).to receive(:warning).with('Not using cache on failed catalog')

      expect(@agent.retrieve_catalog({})).to be_nil
    end

    it "should set its cached_catalog_status to 'not_used' if no catalog can be retrieved from the server and :usecacheonfailure is disabled or fails to retrieve a catalog" do
      Puppet[:usecacheonfailure] = false
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(nil)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
    end

    it "should return nil if no cached catalog is available and no catalog can be retrieved from the server" do
      expects_neither_new_or_cached_catalog

      expect(@agent.retrieve_catalog({})).to be_nil
    end

    it "should return nil if its cached catalog environment doesn't match server-specified environment" do
      cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
      @agent.instance_variable_set(:@node_environment, 'production')

      expects_fallback_to_cached_catalog(cached_catalog)

      expect(Puppet).to receive(:err).with("Not using cached catalog because its environment 'second_env' does not match 'production'")
      expect(@agent.retrieve_catalog({})).to be_nil
    end

    it "should set its cached_catalog_status to 'not_used' if the cached catalog environment doesn't match server-specified environment" do
      cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
      @agent.instance_variable_set(:@node_environment, 'production')

      expects_fallback_to_cached_catalog(cached_catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
    end

    it "should return its cached catalog if the environment matches the server-specified environment" do
      cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment]))
      @agent.instance_variable_set(:@node_environment, cached_catalog.environment)

      expects_fallback_to_cached_catalog(cached_catalog)

      expect(@agent.retrieve_catalog({})).to eq(cached_catalog)
    end

    it "should set its cached_catalog_status to 'on_failure' if the cached catalog environment matches server-specified environment" do
      cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment]))
      @agent.instance_variable_set(:@node_environment, cached_catalog.environment)

      expects_fallback_to_cached_catalog(cached_catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('on_failure')
    end

    it "should not update the cached catalog in noop mode" do
      Puppet[:noop] = true
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true, ignore_cache_save: true)).and_return(@catalog)

      @agent.retrieve_catalog({})
    end

    it "should update the cached catalog when not in noop mode" do
      Puppet[:noop] = false
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true, ignore_cache_save: false)).and_return(@catalog)

      @agent.retrieve_catalog({})
    end
  end

  describe "when converting the catalog" do
    before do
      allow(Puppet.settings).to receive(:use).and_return(true)

      allow(catalog).to receive(:to_ral).and_return(ral_catalog)
    end

    let (:catalog) { Puppet::Resource::Catalog.new('tester', Puppet::Node::Environment.remote(Puppet[:environment].to_sym)) }
    let (:ral_catalog) { Puppet::Resource::Catalog.new('tester', Puppet::Node::Environment.remote(Puppet[:environment].to_sym)) }

    it "should convert the catalog to a RAL-formed catalog" do
      expect(@agent.convert_catalog(catalog, 10)).to equal(ral_catalog)
    end

    it "should finalize the catalog" do
      expect(ral_catalog).to receive(:finalize)

      @agent.convert_catalog(catalog, 10)
    end

    it "should record the passed retrieval time with the RAL catalog" do
      expect(ral_catalog).to receive(:retrieval_duration=).with(10)

      @agent.convert_catalog(catalog, 10)
    end

    it "should write the RAL catalog's class file" do
      expect(ral_catalog).to receive(:write_class_file)

      @agent.convert_catalog(catalog, 10)
    end

    it "should write the RAL catalog's resource file" do
      expect(ral_catalog).to receive(:write_resource_file)

      @agent.convert_catalog(catalog, 10)
    end

    it "should set catalog conversion time on the report" do
      report = Puppet::Transaction::Report.new

      expect(report).to receive(:add_times).with(:convert_catalog, kind_of(Numeric))
      @agent.convert_catalog(catalog, 10, {:report => report})
    end
  end

  describe "when determining whether to pluginsync" do
    it "should default to Puppet[:pluginsync] when explicitly set by the commandline" do
      Puppet.settings[:pluginsync] = false
      expect(Puppet.settings).to receive(:set_by_cli?).and_return(true)

      expect(described_class).not_to be_should_pluginsync
    end

    it "should default to Puppet[:pluginsync] when explicitly set by config" do
      Puppet.settings[:pluginsync] = false
      expect(Puppet.settings).to receive(:set_by_config?).and_return(true)

      expect(described_class).not_to be_should_pluginsync
    end

    it "should be true if use_cached_catalog is false" do
      Puppet.settings[:use_cached_catalog] = false

      expect(described_class).to be_should_pluginsync
    end

    it "should be false if use_cached_catalog is true" do
      Puppet.settings[:use_cached_catalog] = true

      expect(described_class).not_to be_should_pluginsync
    end
  end

  describe "when attempting failover" do
    it "should not failover if server_list is not set" do
      Puppet.settings[:server_list] = []
      expect(@agent).not_to receive(:find_functional_server)
      @agent.run
    end

    it "should not failover during an apply run" do
      Puppet.settings[:server_list] = ["myserver:123"]
      expect(@agent).not_to receive(:find_functional_server)
      catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment].to_sym))
      @agent.run :catalog => catalog
    end

    it "should select a server when provided" do
      Puppet.settings[:server_list] = ["myserver:123"]
      pool = Puppet::Network::HTTP::Pool.new(Puppet[:http_keepalive_timeout])
      expect(Puppet::Network::HTTP::Pool).to receive(:new).and_return(pool)
      expect(Puppet).to receive(:override).with({:http_pool => pool}).and_yield
      expect(Puppet).to receive(:override).with({:server => "myserver", :serverport => '123'}).twice.and_yield
      expect(Puppet::Node.indirection).to receive(:find).and_return(nil)
      expect(@agent).to receive(:run_internal).and_return(nil)
      @agent.run
    end

    it "should error when no servers in 'server_list' are reachable" do
      Puppet.settings[:server_list] = "myserver:123,someotherservername"
      pool = Puppet::Network::HTTP::Pool.new(Puppet[:http_keepalive_timeout])
      allow(Puppet::Network::HTTP::Pool).to receive(:new).and_return(pool)
      allow(Puppet).to receive(:override).with({:http_pool => pool}).and_yield
      allow(Puppet).to receive(:override).with({:server => "myserver", :serverport => '123'}).and_yield
      allow(Puppet).to receive(:override).with({:server => "someotherservername", :serverport => 8140}).and_yield
      error = Net::HTTPError.new(400, 'dummy server communication error')
      allow(Puppet::Node.indirection).to receive(:find).and_raise(error)
      expect{ @agent.run }.to raise_error(Puppet::Error, /Could not select a functional puppet master from server_list: 'myserver:123,someotherservername'/)
    end

    it "should not make multiple node requets when the server is found" do
      Puppet.settings[:server_list] = ["myserver:123"]
      expect(Puppet::Node.indirection).to receive(:find).and_return("mynode").once
      expect(@agent).to receive(:prepare_and_retrieve_catalog).and_return(nil)
      @agent.run
    end
  end
end
