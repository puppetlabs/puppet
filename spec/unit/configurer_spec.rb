require 'spec_helper'
require 'puppet/configurer'
require 'webmock/rspec'

describe Puppet::Configurer do
  before do
    Puppet[:server] = "puppetmaster"
    Puppet[:report] = true

    catalog.add_resource(resource)

    allow(Puppet::SSL::Host).to receive(:localhost).and_return(double('host'))
  end

  let(:configurer) { Puppet::Configurer.new }
  let(:report) { Puppet::Transaction::Report.new }
  let(:catalog) { Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment].to_sym)) }
  let(:resource) { Puppet::Resource.new(:notice, 'a') }
  let(:facts) { Puppet::Node::Facts.new(Puppet[:node_name_value]) }

  describe "when executing a pre-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Puppet.settings[:prerun_command] = ""
      expect(Puppet::Util::Execution).not_to receive(:execute)

      configurer.execute_prerun_command
    end

    it "should execute any pre-run command provided via the 'prerun_command' setting" do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      configurer.execute_prerun_command
    end

    it "should fail if the command fails" do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(configurer.execute_prerun_command).to be_falsey
    end
  end

  describe "when executing a post-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Puppet.settings[:postrun_command] = ""
      expect(Puppet::Util::Execution).not_to receive(:execute)

      configurer.execute_postrun_command
    end

    it "should execute any post-run command provided via the 'postrun_command' setting" do
      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      configurer.execute_postrun_command
    end

    it "should fail if the command fails" do
      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(configurer.execute_postrun_command).to be_falsey
    end
  end

  describe "when executing a catalog run" do
    before do
      Puppet::Resource::Catalog.indirection.terminus_class = :rest
      allow(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(catalog)
    end

    it "downloads plugins when told" do
      expect(configurer).to receive(:download_plugins)
      configurer.run(:pluginsync => true)
    end

    it "does not download plugins when told" do
      expect(configurer).not_to receive(:download_plugins)
      configurer.run(:pluginsync => false)
    end

    it "should carry on when it can't fetch its node definition" do
      error = Net::HTTPError.new(400, 'dummy server communication error')
      expect(Puppet::Node.indirection).to receive(:find).and_raise(error)
      expect(configurer.run).to eq(0)
    end

    it "fails the run if pluginsync fails when usecacheonfailure is false" do
      Puppet[:ignore_plugin_errors] = false

      # --test implies these, set them so we don't fall back to a cached catalog
      Puppet[:use_cached_catalog] = false
      Puppet[:usecacheonfailure] = false

      body = "{\"message\":\"Not Found: Could not find environment 'fasdfad'\",\"issue_kind\":\"RUNTIME_ERROR\"}"
      stub_request(:get, %r{/puppet/v3/file_metadatas/pluginfacts}).to_return(
        status: 404, body: body, headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, %r{/puppet/v3/file_metadata/pluginfacts}).to_return(
        status: 404, body: body, headers: {'Content-Type' => 'application/json'}
      )

      configurer.run(pluginsync: true)

      expect(@logs).to include(an_object_having_attributes(level: :err, message: %r{Failed to apply catalog: Failed to retrieve pluginfacts: Could not retrieve information from environment production source\(s\) puppet:///pluginfacts}))
    end

    it "applies a cached catalog when it can't connect to the master" do
      error = Errno::ECONNREFUSED.new('Connection refused - connect(2)')

      expect(Puppet::Node.indirection).to receive(:find).and_raise(error)
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(:ignore_cache => true)).and_raise(error)
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(:ignore_terminus => true)).and_return(catalog)

      expect(configurer.run).to eq(0)
    end

    it "should initialize a transaction report if one is not provided" do
      # host and settings catalogs each create a report...
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report).twice

      configurer.run
    end

    it "should respect node_name_fact when setting the host on a report" do
      Puppet[:node_name_fact] = 'my_name_fact'
      facts.values = {'my_name_fact' => 'node_name_from_fact'}
      Puppet::Node::Facts.indirection.save(facts)

      configurer.run(:report => report)
      expect(report.host).to eq('node_name_from_fact')
    end

    it "creates a new report when applying the catalog" do
      options = {}
      configurer.run(options)

      expect(options[:report].metrics['time']['catalog_application']).to be_an_instance_of(Float)
    end

    it "uses the provided report when applying the catalog" do
      configurer.run(:report => report)

      expect(report.metrics['time']['catalog_application']).to be_an_instance_of(Float)
    end

    it "should log a failure and do nothing if no catalog can be retrieved" do
      expect(configurer).to receive(:retrieve_catalog).and_return(nil)

      expect(Puppet).to receive(:err).with("Could not retrieve catalog; skipping run")

      configurer.run
    end

    it "passes arbitrary options when applying the catalog" do
      expect(catalog).to receive(:apply).with(hash_including(one: true))

      configurer.run(catalog: catalog, one: true)
    end

    it "should benchmark how long it takes to apply the catalog" do
      configurer.run(report: report)

      expect(report.logs).to include(an_object_having_attributes(level: :notice, message: /Applied catalog in .* seconds/))
    end

    it "should create report with passed transaction_uuid and job_id" do
      configurer = Puppet::Configurer.new("test_tuuid", "test_jid")

      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).with(anything, anything, 'test_tuuid', 'test_jid').and_return(report)
      expect(configurer).to receive(:send_report).with(report)

      configurer.run
    end

    it "should send the report" do
      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(configurer).to receive(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      configurer.run
    end

    it "should send the transaction report even if the catalog could not be retrieved" do
      expect(configurer).to receive(:retrieve_catalog).and_return(nil)

      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(configurer).to receive(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      configurer.run
    end

    it "should send the transaction report even if there is a failure" do
      expect(configurer).to receive(:retrieve_catalog).and_raise("whatever")

      report = Puppet::Transaction::Report.new(nil, "test", "aaaa")
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)
      expect(configurer).to receive(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      expect(configurer.run).to be_nil
    end

    it "should remove the report as a log destination when the run is finished" do
      configurer.run(report: report)

      expect(Puppet::Util::Log.destinations).not_to include(report)
    end

    it "should return an exit status of 2 due to the notify resource 'changing'" do
      cat = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment].to_sym))
      cat.add_resource(Puppet::Type.type(:notify).new(:name => 'something changed'))

      expect(configurer.run(catalog: cat, report: report)).to eq(2)
    end

    it "should return nil if catalog application fails" do
      expect(catalog).to receive(:apply).and_raise(Puppet::Error, 'One or more resource dependency cycles detected in graph')

      expect(configurer.run(catalog: catalog, report: report)).to be_nil
    end

    it "should send the transaction report even if the pre-run command fails" do
      expect(Puppet::Transaction::Report).to receive(:new).and_return(report)

      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")
      expect(configurer).to receive(:send_report).with(report)

      expect(configurer.run).to be_nil
    end

    it "should include the pre-run command failure in the report" do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(configurer.run(report: report)).to be_nil
      expect(report.logs.find { |x| x.message =~ /Could not run command from prerun_command/ }).to be
    end

    it "should send the transaction report even if the post-run command fails" do
      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")
      expect(configurer).to receive(:send_report).with(report)

      expect(configurer.run(report: report)).to be_nil
    end

    it "should include the post-run command failure in the report" do
      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect(report).to receive(:<<) { |log, _| expect(log.message).to match(/Could not run command from postrun_command/) }.at_least(:once)

      expect(configurer.run(report: report)).to be_nil
    end

    it "should execute post-run command even if the pre-run command fails" do
      Puppet.settings[:prerun_command] = "/my/precommand"
      Puppet.settings[:postrun_command] = "/my/postcommand"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/precommand"]).and_raise(Puppet::ExecutionFailure, "Failed")
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/postcommand"])

      expect(configurer.run).to be_nil
    end

    it "should finalize the report" do
      expect(report).to receive(:finalize_report)
      configurer.run(report: report)
    end

    it "should not apply the catalog if the pre-run command fails" do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect_any_instance_of(Puppet::Resource::Catalog).not_to receive(:apply)
      expect(configurer).to receive(:send_report)

      expect(configurer.run(report: report)).to be_nil
    end

    it "should apply the catalog, send the report, and return nil if the post-run command fails" do
      Puppet.settings[:postrun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      expect_any_instance_of(Puppet::Resource::Catalog).to receive(:apply)
      expect(configurer).to receive(:send_report)

      expect(configurer.run(report: report)).to be_nil
    end

    it 'includes total time metrics in the report after successfully applying the catalog' do
      configurer.run(report: report)

      expect(report.metrics['time']).to be
      expect(report.metrics['time']['total']).to be_a_kind_of(Numeric)
    end

    it 'includes total time metrics in the report even if prerun fails' do
      Puppet.settings[:prerun_command] = "/my/command"
      expect(Puppet::Util::Execution).to receive(:execute).with(["/my/command"]).and_raise(Puppet::ExecutionFailure, "Failed")

      configurer.run(report: report)

      expect(report.metrics['time']).to be
      expect(report.metrics['time']['total']).to be_a_kind_of(Numeric)
    end

    it 'includes total time metrics in the report even if catalog retrieval fails' do
      allow(configurer).to receive(:prepare_and_retrieve_catalog_from_cache).and_raise
      configurer.run(:report => report)

      expect(report.metrics['time']).to be
      expect(report.metrics['time']['total']).to be_a_kind_of(Numeric)
    end

    it "should refetch the catalog if the server specifies a new environment in the catalog" do
      catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
      expect(configurer).to receive(:retrieve_catalog).and_return(catalog).twice

      configurer.run
    end

    it "changes the configurer's environment if the server specifies a new environment in the catalog" do
      allow_any_instance_of(Puppet::Resource::Catalog).to receive(:environment).and_return("second_env")

      configurer.run

      expect(configurer.environment).to eq("second_env")
    end

    it "changes the report's environment if the server specifies a new environment in the catalog" do
      allow_any_instance_of(Puppet::Resource::Catalog).to receive(:environment).and_return("second_env")

      configurer.run(report: report)

      expect(report.environment).to eq("second_env")
    end

    it "sends the transaction uuid in a catalog request" do
      configurer = Puppet::Configurer.new('aaa')
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(transaction_uuid: 'aaa'))
      configurer.run
    end

    it "sends the transaction uuid in a catalog request" do
      configurer = Puppet::Configurer.new('b', 'aaa')
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(job_id: 'aaa'))
      configurer.run
    end

    it "sets the static_catalog query param to true in a catalog request" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(static_catalog: true))
      configurer.run
    end

    it "sets the checksum_type query param to the default supported_checksum_types in a catalog request" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything,
        hash_including(checksum_type: 'md5.sha256.sha384.sha512.sha224'))
      configurer.run
    end

    it "sets the checksum_type query param to the supported_checksum_types setting in a catalog request" do
      Puppet[:supported_checksum_types] = ['sha256']
      # Regenerate the agent to pick up the new setting
      configurer = Puppet::Configurer.new

      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(checksum_type: 'sha256'))
      configurer.run
    end

    describe "when not using a REST terminus for catalogs" do
      it "should not pass any facts when retrieving the catalog" do
        # This is weird, we collect facts when constructing the node,
        # but we don't send them in the indirector request. Then the compiler
        # looks up the node, and collects its facts, which we could have sent
        # in the first place. This seems like a bug.
        Puppet::Resource::Catalog.indirection.terminus_class = :compiler

        expect(Puppet::Resource::Catalog.indirection).to receive(:find) do |name, options|
          expect(options[:facts]).to be_nil
        end.and_return(catalog)

        configurer.run
      end
    end

    describe "when using a REST terminus for catalogs" do
      it "should pass the url encoded facts and facts format as arguments when retrieving the catalog" do
        Puppet::Resource::Catalog.indirection.terminus_class = :rest

        facts.values = { 'foo' => 'bar' }
        Puppet::Node::Facts.indirection.save(facts)

        expect(
          Puppet::Resource::Catalog.indirection
        ).to receive(:find) do |_, options|
          expect(options[:facts_format]).to eq("application/json")

          unescaped = JSON.parse(CGI.unescape(options[:facts]))
          expect(unescaped).to include("values" => {"foo" => "bar"})
        end.and_return(catalog)

        configurer.run
      end
    end
  end

  describe "when sending a report" do
    include PuppetSpec::Files

    before do
      Puppet[:lastrunfile] = tmpfile('last_run_file')
      Puppet[:reports] = "none"
    end

    it "should print a report summary if configured to do so" do
      Puppet.settings[:summarize] = true

      expect(report).to receive(:summary).and_return("stuff")

      expect(configurer).to receive(:puts).with("stuff")
      configurer.send_report(report)
    end

    it "should not print a report summary if not configured to do so" do
      Puppet.settings[:summarize] = false

      expect(configurer).not_to receive(:puts)
      configurer.send_report(report)
    end

    it "should save the report if reporting is enabled" do
      Puppet.settings[:report] = true

      expect(Puppet::Transaction::Report.indirection).to receive(:save).with(report, nil, instance_of(Hash))
      configurer.send_report(report)
    end

    it "should not save the report if reporting is disabled" do
      Puppet.settings[:report] = false

      expect(Puppet::Transaction::Report.indirection).not_to receive(:save).with(report, nil, instance_of(Hash))
      configurer.send_report(report)
    end

    it "should save the last run summary if reporting is enabled" do
      Puppet.settings[:report] = true

      expect(configurer).to receive(:save_last_run_summary).with(report)
      configurer.send_report(report)
    end

    it "should save the last run summary if reporting is disabled" do
      Puppet.settings[:report] = false

      expect(configurer).to receive(:save_last_run_summary).with(report)
      configurer.send_report(report)
    end

    it "should log but not fail if saving the report fails" do
      Puppet.settings[:report] = true

      expect(Puppet::Transaction::Report.indirection).to receive(:save).and_raise("whatever")

      expect(Puppet).to receive(:err)
      expect { configurer.send_report(report) }.not_to raise_error
    end
  end

  describe "when saving the summary report file" do
    include PuppetSpec::Files

    before do
      Puppet[:lastrunfile] = tmpfile('last_run_file')
    end

    it "should write the last run file" do
      configurer.save_last_run_summary(report)
      expect(Puppet::FileSystem.exist?(Puppet[:lastrunfile])).to be_truthy
    end

    it "should write the raw summary as yaml" do
      expect(report).to receive(:raw_summary).and_return("summary")
      configurer.save_last_run_summary(report)
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
      expect { configurer.save_last_run_summary(report) }.to_not raise_error
    end

    it "should create the last run file with the correct mode" do
      expect(Puppet.settings.setting(:lastrunfile)).to receive(:mode).and_return('664')
      configurer.save_last_run_summary(report)

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
      configurer.save_last_run_summary(report)
    end
  end

  describe "when requesting a node" do
    it "uses the transaction uuid in the request" do
      expect(Puppet::Node.indirection).to receive(:find).with(anything, hash_including(transaction_uuid: anything)).twice
      configurer.run
    end

    it "sends an explicitly configured environment request" do
      expect(Puppet.settings).to receive(:set_by_config?).with(:environment).and_return(true)
      expect(Puppet::Node.indirection).to receive(:find).with(anything, hash_including(configured_environment: Puppet[:environment])).twice
      configurer.run
    end

    it "does not send a configured_environment when using the default" do
      expect(Puppet::Node.indirection).to receive(:find).with(anything, hash_including(configured_environment: nil)).twice
      configurer.run
    end
  end

  def expects_pluginsync
    metadata = "[{\"path\":\"/etc/puppetlabs/code\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":0,\"group\":0,\"mode\":420,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-07-10 14:00:00 -0700\"},\"type\":\"directory\",\"destination\":null}]"
    stub_request(:get, %r{/puppet/v3/file_metadatas/(plugins|locales)}).to_return(status: 200, body: metadata, headers: {'Content-Type' => 'application/json'})

    # response retains owner/group/mode due to source_permissions => use
    facts_metadata = "[{\"path\":\"/etc/puppetlabs/code\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":500,\"group\":500,\"mode\":493,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-07-10 14:00:00 -0700\"},\"type\":\"directory\",\"destination\":null}]"
    stub_request(:get, %r{/puppet/v3/file_metadatas/pluginfacts}).to_return(status: 200, body: facts_metadata, headers: {'Content-Type' => 'application/json'})
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
    expects_pluginsync
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(nil)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(catalog)
  end

  def expects_neither_new_or_cached_catalog
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(nil)
    expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(nil)
  end

  describe "when retrieving a catalog" do
    before do
      allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class).and_return(:rest)
    end

    describe "and configured to only retrieve a catalog from the cache" do
      before do
        Puppet.settings[:use_cached_catalog] = true
      end

      it "should first look in the cache for a catalog" do
        expects_cached_catalog_only(catalog)

        configurer.run
      end

      it "should not make a node request or pluginsync when a cached catalog is successfully retrieved" do
        expect(Puppet::Node.indirection).not_to receive(:find)
        expects_cached_catalog_only(catalog)
        expect(configurer).not_to receive(:download_plugins)

        configurer.run
      end

      it "should make a node request and pluginsync when a cached catalog cannot be retrieved" do
        expect(Puppet::Node.indirection).to receive(:find).and_return(nil)
        expects_fallback_to_new_catalog(catalog)

        configurer.run
      end

      it "should set its cached_catalog_status to 'explicitly_requested'" do
        expects_cached_catalog_only(catalog)

        options = {}
        configurer.run(options)

        expect(options[:report].cached_catalog_status).to eq('explicitly_requested')
      end

      it "should set its cached_catalog_status to 'explicitly requested' if the cached catalog is from a different environment" do
        cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
        expects_cached_catalog_only(cached_catalog)

        options = {}
        configurer.run(options)

        expect(options[:report].cached_catalog_status).to eq('explicitly_requested')
      end

      it "should compile a new catalog if none is found in the cache" do
        expects_fallback_to_new_catalog(catalog)

        options = {}
        configurer.run(options)

        expect(options[:report].cached_catalog_status).to eq('not_used')
      end

      it "should not attempt to retrieve a cached catalog again if the first attempt failed" do
        expect(Puppet::Node.indirection).to receive(:find).and_return(nil)
        expects_neither_new_or_cached_catalog
        expects_pluginsync

        configurer.run
      end

      it "should return the cached catalog when the environment doesn't match" do
        cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))
        expects_cached_catalog_only(cached_catalog)

        allow(Puppet).to receive(:info)
        expect(Puppet).to receive(:info).with("Using cached catalog from environment 'second_env'")

        configurer.run
      end

      it "applies the catalog passed as options when the catalog cache terminus is not set" do
        expects_pluginsync

        catalog.add_resource(Puppet::Resource.new('notify', 'from apply'))
        configurer.run(catalog: catalog.to_ral)

        # make sure cache class is not set to avoid surprises later
        expect(Puppet::Resource::Catalog.indirection).to_not be_cache
        expect(@logs).to include(an_object_having_attributes(level: :notice, message: /defined 'message' as 'from apply'/))
      end

      it "applies the cached catalog when the catalog cache terminus is set, ignoring the catalog passed as options" do
        Puppet::Resource::Catalog.indirection.cache_class = :json

        cached_catalog = Puppet::Resource::Catalog.new(Puppet[:node_name_value], Puppet[:environment])
        cached_catalog.add_resource(Puppet::Resource.new('notify', 'from cache'))

        # update cached catalog
        Puppet.settings.use(:main, :agent)
        path = Puppet::Resource::Catalog.indirection.cache.path(cached_catalog.name)
        FileUtils.mkdir(File.dirname(path))
        File.write(path, cached_catalog.render(:json))

        configurer.run(catalog: catalog.to_ral)

        expect(@logs).to include(an_object_having_attributes(level: :notice, message: /defined 'message' as 'from cache'/))
      end
    end

    describe "and strict environment mode is set" do
      before do
        Puppet.settings[:strict_environment_mode] = true
      end

      it "should not make a node request" do
        expect(Puppet::Node.indirection).not_to receive(:find)

        configurer.run
      end

      it "should return nil when the catalog's environment doesn't match the agent specified environment" do
        Puppet[:environment] = 'second_env'
        configurer = Puppet::Configurer.new

        catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote("production"))
        expects_new_catalog_only(catalog)

        expect(Puppet).to receive(:err).with("Not using catalog because its environment 'production' does not match agent specified environment 'second_env' and strict_environment_mode is set")
        expect(configurer.run).to be_nil
      end

      it "should return 0 when the catalog's environment matches the agent specified environment" do
        expects_new_catalog_only(catalog)

        expect(configurer.run).to eq(0)
      end

      describe "and a cached catalog is explicitly requested" do
        before do
          Puppet.settings[:use_cached_catalog] = true
        end

        it "should return nil when the cached catalog's environment doesn't match the agent specified environment" do
          Puppet[:environment] = 'second_env'
          configurer = Puppet::Configurer.new

          catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote("production"))
          expects_cached_catalog_only(catalog)

          expect(Puppet).to receive(:err).with("Not using catalog because its environment 'production' does not match agent specified environment 'second_env' and strict_environment_mode is set")
          expect(configurer.run).to be_nil
        end

        it "should proceed with the cached catalog if its environment matchs the local environment" do
          expects_cached_catalog_only(catalog)

          expect(configurer.run).to eq(0)
        end
      end
    end

    it "should set its cached_catalog_status to 'not_used' when downloading a new catalog" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(catalog)

      options = {}
      configurer.run(options)

      expect(options[:report].cached_catalog_status).to eq('not_used')
    end

    it "should use its node_name_value to retrieve the catalog" do
      myhost_facts = Puppet::Node::Facts.new("myhost.domain.com")
      Puppet::Node::Facts.indirection.save(myhost_facts)

      Puppet.settings[:node_name_value] = "myhost.domain.com"
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with("myhost.domain.com", anything).and_return(catalog)

      configurer.run
    end

    it "should log when no catalog can be retrieved from the server" do
      expects_fallback_to_cached_catalog(catalog)

      allow(Puppet).to receive(:info)
      expect(Puppet).to receive(:info).with("Using cached catalog from environment 'production'")
      configurer.run
    end

    it "should set its cached_catalog_status to 'on_failure' when no catalog can be retrieved from the server" do
      expects_fallback_to_cached_catalog(catalog)

      options = {}
      configurer.run(options)

      expect(options[:report].cached_catalog_status).to eq('on_failure')
    end

    it "should not look in the cache for a catalog if one is returned from the server" do
      expects_new_catalog_only(catalog)

      configurer.run
    end

    it "should return the cached catalog when retrieving the remote catalog throws an exception" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_raise("eh")
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(catalog)

      configurer.run
    end

    it "should set its cached_catalog_status to 'on_failure' when retrieving the remote catalog throws an exception" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_raise("eh")
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_terminus: true)).and_return(catalog)

      options = {}
      configurer.run(options)

      expect(options[:report].cached_catalog_status).to eq('on_failure')
    end

    it "should log and return nil if no catalog can be retrieved from the server and :usecacheonfailure is disabled" do
      Puppet[:usecacheonfailure] = false
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(nil)

      expect(Puppet).to receive(:warning).with('Not using cache on failed catalog')

      expect(configurer.run).to be_nil
    end

    it "should set its cached_catalog_status to 'not_used' if no catalog can be retrieved from the server and :usecacheonfailure is disabled or fails to retrieve a catalog" do
      Puppet[:usecacheonfailure] = false
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).with(anything, hash_including(ignore_cache: true)).and_return(nil)

      options = {}
      configurer.run(options)

      expect(options[:report].cached_catalog_status).to eq('not_used')
    end

    it "should return nil if no cached catalog is available and no catalog can be retrieved from the server" do
      expects_neither_new_or_cached_catalog

      expect(configurer.run).to be_nil
    end

    it "should return nil if its cached catalog environment doesn't match server-specified environment" do
      cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))

      expects_fallback_to_cached_catalog(cached_catalog)

      allow(Puppet).to receive(:err)
      expect(Puppet).to receive(:err).with("Not using cached catalog because its environment 'second_env' does not match 'production'")
      expect(configurer.run).to be_nil
    end

    it "should set its cached_catalog_status to 'not_used' if the cached catalog environment doesn't match server-specified environment" do
      cached_catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote('second_env'))

      expects_fallback_to_cached_catalog(cached_catalog)

      options = {}
      configurer.run(options)
      expect(options[:report].cached_catalog_status).to eq('not_used')
    end

    it "should set its cached_catalog_status to 'on_failure' if the cached catalog environment matches server-specified environment" do
      expects_fallback_to_cached_catalog(catalog)

      options = {}
      configurer.run(options)
      expect(options[:report].cached_catalog_status).to eq('on_failure')
    end

    it "should not update the cached catalog in noop mode" do
      Puppet[:noop] = true

      stub_request(:get, %r{/puppet/v3/catalog}).to_return(:status => 200, :body => catalog.render(:json), :headers => {'Content-Type' => 'application/json'})

      Puppet::Resource::Catalog.indirection.cache_class = :json
      path = Puppet::Resource::Catalog.indirection.cache.path(catalog.name)

      expect(File).to_not be_exist(path)
      configurer.run
      expect(File).to_not be_exist(path)
    end

    it "should update the cached catalog when not in noop mode" do
      Puppet[:noop] = false
      Puppet[:log_level] = 'info'

      stub_request(:get, %r{/puppet/v3/catalog}).to_return(:status => 200, :body => catalog.render(:json), :headers => {'Content-Type' => 'application/json'})

      Puppet::Resource::Catalog.indirection.cache_class = :json
      cache_path = Puppet::Resource::Catalog.indirection.cache.path(Puppet[:node_name_value])

      expect(File).to_not be_exist(cache_path)
      configurer.run
      expect(File).to be_exist(cache_path)

      expect(@logs).to include(an_object_having_attributes(level: :info, message: "Caching catalog for #{Puppet[:node_name_value]}"))
    end

    it "successfully applies the catalog without a cache" do
      stub_request(:get, %r{/puppet/v3/catalog}).to_return(:status => 200, :body => catalog.render(:json), :headers => {'Content-Type' => 'application/json'})

      Puppet::Resource::Catalog.indirection.cache_class = nil

      expect(configurer.run).to eq(0)
    end

    it "should not update the cached catalog when running puppet apply" do
      Puppet::Resource::Catalog.indirection.cache_class = :json
      path = Puppet::Resource::Catalog.indirection.cache.path(catalog.name)

      expect(File).to_not be_exist(path)
      configurer.run(catalog: catalog)
      expect(File).to_not be_exist(path)
    end
  end

  describe "when converging the environment" do
    let(:apple) { Puppet::Resource::Catalog.new(Puppet[:node_name_value], Puppet::Node::Environment.remote('apple')) }
    let(:banana) { Puppet::Resource::Catalog.new(Puppet[:node_name_value], Puppet::Node::Environment.remote('banana')) }

    before :each do
      apple.add_resource(resource)
      banana.add_resource(resource)
    end

    it "converges after multiple attempts" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(apple, banana, banana)

      allow(Puppet).to receive(:notice)
      expect(Puppet).to receive(:notice).with("Local environment: 'production' doesn't match server specified environment 'apple', restarting agent run with environment 'apple'")
      expect(Puppet).to receive(:notice).with("Local environment: 'apple' doesn't match server specified environment 'banana', restarting agent run with environment 'banana'")

      configurer.run
    end

    it "raises if it can't converge after 4 tries after the initial catalog request" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(apple, banana, apple, banana, apple)

      expect(Puppet).to receive(:err).with("Failed to apply catalog: Catalog environment didn't stabilize after 4 fetches, aborting run")

      configurer.run
    end
  end

  describe "when converting the catalog" do
    it "converts Puppet::Resource into Puppet::Type::Notify" do
      expect(configurer).to receive(:apply_catalog) do |ral, _|
        expect(ral.resources).to contain(an_instance_of(Puppet::Type::Notify))
      end

      configurer.run(catalog: catalog)
    end

    it "adds default schedules" do
      expect(configurer).to receive(:apply_catalog) do |ral, _|
        expect(ral.resources.map(&:to_ref)).to contain(%w{Schedule[puppet] Schedule[hourly] Schedule[daily] Schedule[weekly] Schedule[monthly] Schedule[never]})
      end

      configurer.run
    end

    it "records the retrieval duration to the catalog" do
      expect(configurer).to receive(:apply_catalog) do |ral, _|
        expect(ral.retrieval_duration).to be_an_instance_of(Float)
      end

      configurer.run
    end

    it "writes the class file containing applied settings classes" do
      expect(File).to_not be_exist(Puppet[:classfile])

      configurer.run

      expect(File.read(Puppet[:classfile]).chomp).to eq('settings')
    end

    it "writes an empty resource file since no resources are 'managed'" do
      expect(File).to_not be_exist(Puppet[:resourcefile])

      configurer.run

      expect(File.read(Puppet[:resourcefile]).chomp).to eq("")
    end

    it "adds the conversion time to the report" do
      configurer.run(report: report)

      expect(report.metrics['time']['convert_catalog']).to be_an_instance_of(Float)
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
      configurer.run
    end

    it "should not failover during an apply run" do
      Puppet.settings[:server_list] = ["myserver:123"]
      catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment].to_sym))
      configurer.run(catalog: catalog)
    end

    it "should select a server when it receives 200 OK response" do
      Puppet.settings[:server_list] = ["myserver:123"]

      stub_request(:get, 'https://myserver:123/status/v1/simple/master').to_return(status: 200)

      options = {}
      configurer.run(options)
      expect(options[:report].master_used).to eq('myserver:123')
    end

    it "should select a server when it receives 403 Forbidden" do
      Puppet.settings[:server_list] = ["myserver:123"]

      stub_request(:get, 'https://myserver:123/status/v1/simple/master').to_return(status: 403)

      options = {}
      configurer.run(options)
      expect(options[:report].master_used).to eq('myserver:123')
    end

    it "should report when a server is unavailable" do
      Puppet.settings[:server_list] = ["myserver:123"]

      stub_request(:get, 'https://myserver:123/status/v1/simple/master').to_return(status: [500, "Internal Server Error"])

      allow(Puppet).to receive(:debug)
      expect(Puppet).to receive(:debug).with("Puppet server myserver:123 is unavailable: 500 Internal Server Error")
      expect {
        configurer.run
      }.to raise_error(Puppet::Error, /Could not select a functional puppet master from server_list:/)
    end

    it "should error when no servers in 'server_list' are reachable" do
      Puppet.settings[:server_list] = "myserver:123,someotherservername"

      stub_request(:get, 'https://myserver/status/v1/simple/master').to_return(status: 400)
      stub_request(:get, 'https://someotherservername/status/v1/simple/master').to_return(status: 400)

      expect{
        configurer.run
      }.to raise_error(Puppet::Error, /Could not select a functional puppet master from server_list: 'myserver:123,someotherservername'/)
    end

    it "should not make multiple node requests when the server is found" do
      Puppet.settings[:server_list] = ["myserver:123"]
      Puppet::Node.indirection.terminus_class = :rest
      Puppet::Resource::Catalog.indirection.terminus_class = :rest

      stub_request(:get, 'https://myserver:123/status/v1/simple/master').to_return(status: 200)
      stub_request(:get, %r{https://myserver:123/puppet/v3/catalog}).to_return(status: 200)
      node_request = stub_request(:get, %r{https://myserver:123/puppet/v3/node/}).to_return(status: 200)

      configurer.run

      expect(node_request).to have_been_requested.once
    end
  end
end
