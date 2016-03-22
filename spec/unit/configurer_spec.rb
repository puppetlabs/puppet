#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/configurer'

describe Puppet::Configurer do
  before do
    Puppet.settings.stubs(:use).returns(true)
    @agent = Puppet::Configurer.new
    @agent.stubs(:init_storage)
    Puppet::Util::Storage.stubs(:store)
    Puppet[:server] = "puppetmaster"
    Puppet[:report] = true
  end

  it "should include the Fact Handler module" do
    Puppet::Configurer.ancestors.should be_include(Puppet::Configurer::FactHandler)
  end

  describe "when executing a pre-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Puppet.settings[:prerun_command] = ""
      Puppet::Util.expects(:exec).never

      @agent.execute_prerun_command
    end

    it "should execute any pre-run command provided via the 'prerun_command' setting" do
      Puppet.settings[:prerun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      @agent.execute_prerun_command
    end

    it "should fail if the command fails" do
      Puppet.settings[:prerun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      @agent.execute_prerun_command.should be_false
    end
  end

  describe "when executing a post-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Puppet.settings[:postrun_command] = ""
      Puppet::Util.expects(:exec).never

      @agent.execute_postrun_command
    end

    it "should execute any post-run command provided via the 'postrun_command' setting" do
      Puppet.settings[:postrun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      @agent.execute_postrun_command
    end

    it "should fail if the command fails" do
      Puppet.settings[:postrun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      @agent.execute_postrun_command.should be_false
    end
  end

  describe "when executing a catalog run" do
    before do
      Puppet.settings.stubs(:use).returns(true)
      @agent.stubs(:download_plugins)
      Puppet::Node::Facts.indirection.terminus_class = :memory
      @facts = Puppet::Node::Facts.new(Puppet[:node_name_value])
      Puppet::Node::Facts.indirection.save(@facts)

      @catalog = Puppet::Resource::Catalog.new("tester", Puppet::Node::Environment.remote(Puppet[:environment].to_sym))
      @catalog.stubs(:to_ral).returns(@catalog)
      Puppet::Resource::Catalog.indirection.terminus_class = :rest
      Puppet::Resource::Catalog.indirection.stubs(:find).returns(@catalog)
      @agent.stubs(:send_report)
      @agent.stubs(:save_last_run_summary)

      Puppet::Util::Log.stubs(:close_all)
    end

    after :all do
      Puppet::Node::Facts.indirection.reset_terminus_class
      Puppet::Resource::Catalog.indirection.reset_terminus_class
    end

    it "should initialize storage" do
      Puppet::Util::Storage.expects(:load)
      @agent.run
    end

    it "downloads plugins when told" do
      @agent.expects(:download_plugins)
      @agent.run(:pluginsync => true)
    end

    it "does not download plugins when told" do
      @agent.expects(:download_plugins).never
      @agent.run(:pluginsync => false)
    end

    it "should carry on when it can't fetch its node definition" do
      error = Net::HTTPError.new(400, 'dummy server communication error')
      Puppet::Node.indirection.expects(:find).raises(error)
      @agent.run.should == 0
    end

    it "applies a cached catalog when it can't connect to the master" do
      error = Errno::ECONNREFUSED.new('Connection refused - connect(2)')

      Puppet::Node.indirection.expects(:find).raises(error)
      Puppet::Resource::Catalog.indirection.expects(:find).with(anything, has_entry(:ignore_cache => true)).raises(error)
      Puppet::Resource::Catalog.indirection.expects(:find).with(anything, has_entry(:ignore_terminus => true)).returns(@catalog)

      @agent.run.should == 0
    end

    it "should initialize a transaction report if one is not provided" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns report

      @agent.run
    end

    it "should respect node_name_fact when setting the host on a report" do
      Puppet[:node_name_fact] = 'my_name_fact'
      @facts.values = {'my_name_fact' => 'node_name_from_fact'}

      report = Puppet::Transaction::Report.new("apply")

      @agent.run(:report => report)
      report.host.should == 'node_name_from_fact'
    end

    it "should pass the new report to the catalog" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.stubs(:new).returns report
      @catalog.expects(:apply).with{|options| options[:report] == report}

      @agent.run
    end

    it "should use the provided report if it was passed one" do
      report = Puppet::Transaction::Report.new("apply")
      @catalog.expects(:apply).with {|options| options[:report] == report}

      @agent.run(:report => report)
    end

    it "should set the report as a log destination" do
      report = Puppet::Transaction::Report.new("apply")

      report.expects(:<<).with(instance_of(Puppet::Util::Log)).at_least_once

      @agent.run(:report => report)
    end

    it "should retrieve the catalog" do
      @agent.expects(:retrieve_catalog)

      @agent.run
    end

    it "should log a failure and do nothing if no catalog can be retrieved" do
      @agent.expects(:retrieve_catalog).returns nil

      Puppet.expects(:err).with "Could not retrieve catalog; skipping run"

      @agent.run
    end

    it "should apply the catalog with all options to :run" do
      @agent.expects(:retrieve_catalog).returns @catalog

      @catalog.expects(:apply).with { |args| args[:one] == true }
      @agent.run :one => true
    end

    it "should accept a catalog and use it instead of retrieving a different one" do
      @agent.expects(:retrieve_catalog).never

      @catalog.expects(:apply)
      @agent.run :one => true, :catalog => @catalog
    end

    it "should benchmark how long it takes to apply the catalog" do
      @agent.expects(:benchmark).with(:notice, "Finished catalog run")

      @agent.expects(:retrieve_catalog).returns @catalog

      @catalog.expects(:apply).never # because we're not yielding
      @agent.run
    end

    it "should execute post-run hooks after the run" do
      @agent.expects(:execute_postrun_command)

      @agent.run
    end

    it "should send the report" do
      report = Puppet::Transaction::Report.new("apply", nil, "test", "aaaa")
      Puppet::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      report.environment.should == "test"
      report.transaction_uuid.should == "aaaa"

      @agent.run
    end

    it "should send the transaction report even if the catalog could not be retrieved" do
      @agent.expects(:retrieve_catalog).returns nil

      report = Puppet::Transaction::Report.new("apply", nil, "test", "aaaa")
      Puppet::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      report.environment.should == "test"
      report.transaction_uuid.should == "aaaa"

      @agent.run
    end

    it "should send the transaction report even if there is a failure" do
      @agent.expects(:retrieve_catalog).raises "whatever"

      report = Puppet::Transaction::Report.new("apply", nil, "test", "aaaa")
      Puppet::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      report.environment.should == "test"
      report.transaction_uuid.should == "aaaa"

      @agent.run.should be_nil
    end

    it "should remove the report as a log destination when the run is finished" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      @agent.run

      Puppet::Util::Log.destinations.should_not include(report)
    end

    it "should return the report exit_status as the result of the run" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)
      report.expects(:exit_status).returns(1234)

      @agent.run.should == 1234
    end

    it "should send the transaction report even if the pre-run command fails" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      Puppet.settings[:prerun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")
      @agent.expects(:send_report).with(report)

      @agent.run.should be_nil
    end

    it "should include the pre-run command failure in the report" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      Puppet.settings[:prerun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      @agent.run.should be_nil
      report.logs.find { |x| x.message =~ /Could not run command from prerun_command/ }.should be
    end

    it "should send the transaction report even if the post-run command fails" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      Puppet.settings[:postrun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")
      @agent.expects(:send_report).with(report)

      @agent.run.should be_nil
    end

    it "should include the post-run command failure in the report" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      Puppet.settings[:postrun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      report.expects(:<<).with { |log| log.message.include?("Could not run command from postrun_command") }

      @agent.run.should be_nil
    end

    it "should execute post-run command even if the pre-run command fails" do
      Puppet.settings[:prerun_command] = "/my/precommand"
      Puppet.settings[:postrun_command] = "/my/postcommand"
      Puppet::Util::Execution.expects(:execute).with(["/my/precommand"]).raises(Puppet::ExecutionFailure, "Failed")
      Puppet::Util::Execution.expects(:execute).with(["/my/postcommand"])

      @agent.run.should be_nil
    end

    it "should finalize the report" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      report.expects(:finalize_report)
      @agent.run
    end

    it "should not apply the catalog if the pre-run command fails" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      Puppet.settings[:prerun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      @catalog.expects(:apply).never()
      @agent.expects(:send_report)

      @agent.run.should be_nil
    end

    it "should apply the catalog, send the report, and return nil if the post-run command fails" do
      report = Puppet::Transaction::Report.new("apply")
      Puppet::Transaction::Report.expects(:new).returns(report)

      Puppet.settings[:postrun_command] = "/my/command"
      Puppet::Util::Execution.expects(:execute).with(["/my/command"]).raises(Puppet::ExecutionFailure, "Failed")

      @catalog.expects(:apply)
      @agent.expects(:send_report)

      @agent.run.should be_nil
    end

    it "should refetch the catalog if the server specifies a new environment in the catalog" do
      @catalog.stubs(:environment).returns("second_env")
      @agent.expects(:retrieve_catalog).returns(@catalog).twice

      @agent.run
    end

    it "should change the environment setting if the server specifies a new environment in the catalog" do
      @catalog.stubs(:environment).returns("second_env")

      @agent.run

      @agent.environment.should == "second_env"
    end

    it "should fix the report if the server specifies a new environment in the catalog" do
      report = Puppet::Transaction::Report.new("apply", nil, "test", "aaaa")
      Puppet::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      @catalog.stubs(:environment).returns("second_env")
      @agent.stubs(:retrieve_catalog).returns(@catalog)

      @agent.run

      report.environment.should == "second_env"
    end

    it "should clear the global caches" do
      $env_module_directories = false

      @agent.run

      $env_module_directories.should == nil
    end

    describe "when not using a REST terminus for catalogs" do
      it "should not pass any facts when retrieving the catalog" do
        Puppet::Resource::Catalog.indirection.terminus_class = :compiler
        @agent.expects(:facts_for_uploading).never
        Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options|
          options[:facts].nil?
        }.returns @catalog

        @agent.run
      end
    end

    describe "when using a REST terminus for catalogs" do
      it "should pass the prepared facts and the facts format as arguments when retrieving the catalog" do
        Puppet::Resource::Catalog.indirection.terminus_class = :rest
        @agent.expects(:facts_for_uploading).returns(:facts => "myfacts", :facts_format => :foo)
        Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options|
          options[:facts] == "myfacts" and options[:facts_format] == :foo
        }.returns @catalog

        @agent.run
      end
    end
  end

  describe "when sending a report" do
    include PuppetSpec::Files

    before do
      Puppet.settings.stubs(:use).returns(true)
      @configurer = Puppet::Configurer.new
      Puppet[:lastrunfile] = tmpfile('last_run_file')

      @report = Puppet::Transaction::Report.new("apply")
      Puppet[:reports] = "none"
    end

    it "should print a report summary if configured to do so" do
      Puppet.settings[:summarize] = true

      @report.expects(:summary).returns "stuff"

      @configurer.expects(:puts).with("stuff")
      @configurer.send_report(@report)
    end

    it "should not print a report summary if not configured to do so" do
      Puppet.settings[:summarize] = false

      @configurer.expects(:puts).never
      @configurer.send_report(@report)
    end

    it "should save the report if reporting is enabled" do
      Puppet.settings[:report] = true

      Puppet::Transaction::Report.indirection.expects(:save).with(@report, nil, instance_of(Hash))
      @configurer.send_report(@report)
    end

    it "should not save the report if reporting is disabled" do
      Puppet.settings[:report] = false

      Puppet::Transaction::Report.indirection.expects(:save).with(@report, nil, instance_of(Hash)).never
      @configurer.send_report(@report)
    end

    it "should save the last run summary if reporting is enabled" do
      Puppet.settings[:report] = true

      @configurer.expects(:save_last_run_summary).with(@report)
      @configurer.send_report(@report)
    end

    it "should save the last run summary if reporting is disabled" do
      Puppet.settings[:report] = false

      @configurer.expects(:save_last_run_summary).with(@report)
      @configurer.send_report(@report)
    end

    it "should log but not fail if saving the report fails" do
      Puppet.settings[:report] = true

      Puppet::Transaction::Report.indirection.expects(:save).raises("whatever")

      Puppet.expects(:err)
      lambda { @configurer.send_report(@report) }.should_not raise_error
    end
  end

  describe "when saving the summary report file" do
    include PuppetSpec::Files

    before do
      Puppet.settings.stubs(:use).returns(true)
      @configurer = Puppet::Configurer.new

      @report = stub 'report', :raw_summary => {}

      Puppet[:lastrunfile] = tmpfile('last_run_file')
    end

    it "should write the last run file" do
      @configurer.save_last_run_summary(@report)
      Puppet::FileSystem.exist?(Puppet[:lastrunfile]).should be_true
    end

    it "should write the raw summary as yaml" do
      @report.expects(:raw_summary).returns("summary")
      @configurer.save_last_run_summary(@report)
      File.read(Puppet[:lastrunfile]).should == YAML.dump("summary")
    end

    it "should log but not fail if saving the last run summary fails" do
      # The mock will raise an exception on any method used.  This should
      # simulate a nice hard failure from the underlying OS for us.
      fh = Class.new(Object) do
        def method_missing(*args)
          raise "failed to do #{args[0]}"
        end
      end.new

      Puppet::Util.expects(:replace_file).yields(fh)

      Puppet.expects(:err)
      expect { @configurer.save_last_run_summary(@report) }.to_not raise_error
    end

    it "should create the last run file with the correct mode" do
      Puppet.settings.setting(:lastrunfile).expects(:mode).returns('664')
      @configurer.save_last_run_summary(@report)

      if Puppet::Util::Platform.windows?
        require 'puppet/util/windows/security'
        mode = Puppet::Util::Windows::Security.get_mode(Puppet[:lastrunfile])
      else
        mode = Puppet::FileSystem.stat(Puppet[:lastrunfile]).mode
      end
      (mode & 0777).should == 0664
    end

    it "should report invalid last run file permissions" do
      Puppet.settings.setting(:lastrunfile).expects(:mode).returns('892')
      Puppet.expects(:err).with(regexp_matches(/Could not save last run local report.*892 is invalid/))
      @configurer.save_last_run_summary(@report)
    end
  end

  describe "when requesting a node" do
    it "uses the transaction uuid in the request" do
      Puppet::Node.indirection.expects(:find).with(anything, has_entries(:transaction_uuid => anything)).twice
      @agent.run
    end
  end

  describe "when retrieving a catalog" do
    before do
      Puppet.settings.stubs(:use).returns(true)
      @agent.stubs(:facts_for_uploading).returns({})

      @catalog = Puppet::Resource::Catalog.new

      # this is the default when using a Configurer instance
      Puppet::Resource::Catalog.indirection.stubs(:terminus_class).returns :rest

      @agent.stubs(:convert_catalog).returns @catalog
    end

    describe "and configured to only retrieve a catalog from the cache" do
      before do
        Puppet.settings[:use_cached_catalog] = true
      end

      it "should first look in the cache for a catalog" do
        Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns @catalog
        Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.never

        @agent.retrieve_catalog({}).should == @catalog
      end

      it "should compile a new catalog if none is found in the cache" do
        Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns nil
        Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns @catalog

        @agent.retrieve_catalog({}).should == @catalog
      end
    end

    it "should use the Catalog class to get its catalog" do
      Puppet::Resource::Catalog.indirection.expects(:find).returns @catalog

      @agent.retrieve_catalog({})
    end

    it "should use its node_name_value to retrieve the catalog" do
      Facter.stubs(:value).returns "eh"
      Puppet.settings[:node_name_value] = "myhost.domain.com"
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| name == "myhost.domain.com" }.returns @catalog

      @agent.retrieve_catalog({})
    end

    it "should default to returning a catalog retrieved directly from the server, skipping the cache" do
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns @catalog

      @agent.retrieve_catalog({}).should == @catalog
    end

    it "should log and return the cached catalog when no catalog can be retrieved from the server" do
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns @catalog

      Puppet.expects(:notice)

      @agent.retrieve_catalog({}).should == @catalog
    end

    it "should not look in the cache for a catalog if one is returned from the server" do
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns @catalog
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.never

      @agent.retrieve_catalog({}).should == @catalog
    end

    it "should return the cached catalog when retrieving the remote catalog throws an exception" do
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.raises "eh"
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns @catalog

      @agent.retrieve_catalog({}).should == @catalog
    end

    it "should log and return nil if no catalog can be retrieved from the server and :usecacheonfailure is disabled" do
      Puppet[:usecacheonfailure] = false
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil

      Puppet.expects(:warning)

      @agent.retrieve_catalog({}).should be_nil
    end

    it "should return nil if no cached catalog is available and no catalog can be retrieved from the server" do
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil
      Puppet::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns nil

      @agent.retrieve_catalog({}).should be_nil
    end

    it "should convert the catalog before returning" do
      Puppet::Resource::Catalog.indirection.stubs(:find).returns @catalog

      @agent.expects(:convert_catalog).with { |cat, dur| cat == @catalog }.returns "converted catalog"
      @agent.retrieve_catalog({}).should == "converted catalog"
    end

    it "should return nil if there is an error while retrieving the catalog" do
      Puppet::Resource::Catalog.indirection.expects(:find).at_least_once.raises "eh"

      @agent.retrieve_catalog({}).should be_nil
    end
  end

  describe "when converting the catalog" do
    before do
      Puppet.settings.stubs(:use).returns(true)

      @catalog = Puppet::Resource::Catalog.new
      @oldcatalog = stub 'old_catalog', :to_ral => @catalog
    end

    it "should convert the catalog to a RAL-formed catalog" do
      @oldcatalog.expects(:to_ral).returns @catalog

      @agent.convert_catalog(@oldcatalog, 10).should equal(@catalog)
    end

    it "should finalize the catalog" do
      @catalog.expects(:finalize)

      @agent.convert_catalog(@oldcatalog, 10)
    end

    it "should record the passed retrieval time with the RAL catalog" do
      @catalog.expects(:retrieval_duration=).with 10

      @agent.convert_catalog(@oldcatalog, 10)
    end

    it "should write the RAL catalog's class file" do
      @catalog.expects(:write_class_file)

      @agent.convert_catalog(@oldcatalog, 10)
    end

    it "should write the RAL catalog's resource file" do
      @catalog.expects(:write_resource_file)

      @agent.convert_catalog(@oldcatalog, 10)
    end
  end
end
