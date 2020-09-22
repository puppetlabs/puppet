require 'spec_helper'

require 'puppet/configurer'

describe Puppet::Configurer do
  include PuppetSpec::Files

  describe "when running" do
    before(:each) do
      @catalog = Puppet::Resource::Catalog.new("testing", Puppet.lookup(:environments).get(Puppet[:environment]))
      @catalog.add_resource(Puppet::Type.type(:notify).new(:title => "testing"))

      # Make sure we don't try to persist the local state after the transaction ran,
      # because it will fail during test (the state file is in a not-existing directory)
      # and we need the transaction to be successful to be able to produce a summary report
      @catalog.host_config = false

      @configurer = Puppet::Configurer.new
    end

    it "should send a transaction report with valid data" do
      allow(@configurer).to receive(:save_last_run_summary)
      expect(Puppet::Transaction::Report.indirection).to receive(:save) do |report, x|
        expect(report.time).to be_a(Time)
        expect(report.logs.length).to be > 0
      end

      Puppet[:report] = true

      @configurer.run :catalog => @catalog
    end

    it "should save a correct last run summary" do
      report = Puppet::Transaction::Report.new
      allow(Puppet::Transaction::Report.indirection).to receive(:save)

      Puppet[:lastrunfile] = tmpfile("lastrunfile")
      Puppet.settings.setting(:lastrunfile).mode = 0666
      Puppet[:report] = true

      # We only record integer seconds in the timestamp, and truncate
      # backwards, so don't use a more accurate timestamp in the test.
      # --daniel 2011-03-07
      t1 = Time.now.tv_sec
      @configurer.run :catalog => @catalog, :report => report
      t2 = Time.now.tv_sec

      # sticky bit only applies to directories in windows
      file_mode = Puppet::Util::Platform.windows? ? '666' : '100666'

      expect(Puppet::FileSystem.stat(Puppet[:lastrunfile]).mode.to_s(8)).to eq(file_mode)

      summary = Puppet::Util::Yaml.safe_load_file(Puppet[:lastrunfile])

      expect(summary).to be_a(Hash)
      %w{time changes events resources}.each do |key|
        expect(summary).to be_key(key)
      end
      expect(summary["time"]).to be_key("notify")
      expect(summary["time"]["last_run"]).to be_between(t1, t2)
    end

    it "applies a cached catalog if pluginsync fails when usecacheonfailure is true" do
      Puppet[:ignore_plugin_errors] = false

      Puppet[:use_cached_catalog] = false
      Puppet[:usecacheonfailure] = true

      report = Puppet::Transaction::Report.new
      expect_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate).and_raise(Puppet::Error, 'Failed to retrieve: some file')
      expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(@catalog)

      @configurer.run(pluginsync: true, report: report)
      expect(report.cached_catalog_status).to eq('on_pluginsync_failure')
    end

    describe 'resubmitting facts' do
      context 'when resubmit_facts is set to false' do
        it 'should not send data' do
          expect(@configurer).to receive(:resubmit_facts).never

          @configurer.run(catalog: @catalog)
        end
      end

      context 'when resubmit_facts is set to true' do
        let(:test_facts) { Puppet::Node::Facts.new('configurer.test', {test_fact: 'test value'}) }

        before(:each) do
          Puppet[:resubmit_facts] = true

          allow(@configurer).to receive(:find_facts).and_return(test_facts)
        end

        it 'uploads facts as application/json' do
          stub_request(:put, "https://puppet:8140/puppet/v3/facts/configurer.test?environment=production").
            with(
              body: hash_including(
                {
                  "name" => "configurer.test",
                  "values" => {"test_fact" => 'test value',},
                }),
              headers: {
                'Accept'=>'application/json, application/x-msgpack, text/pson',
                'Content-Type'=>'application/json',
              })

          @configurer.run(catalog: @catalog)
        end

        it 'logs errors that occur during fact generation' do
          allow(@configurer).to receive(:find_facts).and_raise('error generating facts')
          expect(Puppet).to receive(:log_exception).with(instance_of(RuntimeError),
                                                         /^Failed to submit facts/)

          @configurer.run(catalog: @catalog)
        end

        it 'logs errors that occur during fact submission' do
          stub_request(:put, "https://puppet:8140/puppet/v3/facts/configurer.test?environment=production").to_return(status: 502)
          expect(Puppet).to receive(:log_exception).with(Puppet::HTTP::ResponseError,
                                                         /^Failed to submit facts/)

          @configurer.run(catalog: @catalog)
        end

        it 'records time spent resubmitting facts' do
          report = Puppet::Transaction::Report.new

          stub_request(:put, "https://puppet:8140/puppet/v3/facts/configurer.test?environment=production").
            with(
              body: hash_including({
                "name" => "configurer.test",
                "values" => {"test_fact": "test value"},
              }),
              headers: {
                'Accept'=>'application/json, application/x-msgpack, text/pson',
                'Content-Type'=>'application/json',
              }).to_return(status: 200)

          @configurer.run(catalog: @catalog, report: report)

          expect(report.metrics['time'].values).to include(["resubmit_facts", anything, Numeric])
        end
      end
    end
  end
end
