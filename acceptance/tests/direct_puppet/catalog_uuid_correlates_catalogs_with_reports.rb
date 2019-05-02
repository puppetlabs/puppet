require "erb"
test_name "PUP-5872: catalog_uuid correlates catalogs with reports" do
  tag 'audit:medium',
      'audit:acceptance'

  def remove_reports(host, reportdir, node_name)
    on(host, "rm -rf #{reportdir}/#{node_name}/*")
  end

  def get_catalog_uuid_from_cached_catalog(host, agent_vardir, agent_node_name)
    cache_catalog_uuid = nil
    on(host, "cat #{agent_vardir}/client_data/catalog/#{agent_node_name}.json") do
      cache_catalog_uuid = stdout.match(/"catalog_uuid":"([a-z0-9\-]*)",/)[1]
    end
    cache_catalog_uuid
  end

  def get_catalog_uuid_from_report(host, reportdir, agent_node_name)
    report_catalog_uuid = nil
    on(host, "cat #{reportdir}/#{agent_node_name}/*") do
      report_catalog_uuid = stdout.match(/catalog_uuid: '?([a-z0-9\-]*)'?/)[1]
    end
    report_catalog_uuid
  end

  fixture_dir = File.expand_path(File.join(File.dirname(__FILE__),
                                           "../../fixtures"))

  agents.each do |agent|
    testdir = agent.tmpdir(File.basename(__FILE__, ".*"))
    confdir = "#{testdir}/puppet"
    vardir = "#{confdir}/cache"
    reportdir = "#{vardir}/reports"
    main_manifest = "#{testdir}/code/environments/production/manifests/site.pp"

    cache_catalog_uuid = nil

    step "setup test puppet environment" do
      template = File.read("#{fixture_dir}/puppet_dir.pp.erb")
      renderer = ERB.new(template)
      manifest = renderer.result(binding)
      # run manifest
      apply_manifest_on(agent, manifest)
      # add reportdir to puppetfile
      agent.mkdir_p(reportdir)
      on(agent, "echo 'vardir = #{vardir}' >> #{confdir}/puppet.conf")
      on(agent, "echo 'reportdir = #{reportdir}' >> #{confdir}/puppet.conf")
    end

    step "cleanup reports" do
      remove_reports(agent, reportdir, agent.node_name)
    end

    step "agent: #{agent}: Initial run to retrieve a catalog and generate the first report" do
      on(agent, puppet("apply", main_manifest,
                       confdir: confdir, catalog_cache_terminus: "json"),
         acceptable_exit_codes: [0, 2])
    end

    cache_catalog_uuid = get_catalog_uuid_from_cached_catalog(agent, vardir, agent.node_name)

    step "agent: #{agent}: Ensure the catalog and report share the same catalog_uuid" do
      report_catalog_uuid = get_catalog_uuid_from_report(agent, reportdir, agent.node_name)
      assert_equal(cache_catalog_uuid, report_catalog_uuid,
                   "catalog_uuid found in cached catalog, #{cache_catalog_uuid} did not match report #{report_catalog_uuid}")
    end

    step "cleanup reports" do
      remove_reports(agent, reportdir, agent.node_name)
    end

    step "Run with --use_cached_catalog and ensure catalog_uuid in the new report matches the cached catalog" do
      on(agent, puppet("apply", "--use_cached_catalog", main_manifest,
                       confdir: confdir, catalog_cache_terminus: "json"),
         acceptable_exit_codes: [0, 2])
      report_catalog_uuid = get_catalog_uuid_from_report(agent, reportdir, agent.node_name)
      assert_equal(cache_catalog_uuid, report_catalog_uuid,
                   "catalog_uuid found in cached catalog, #{cache_catalog_uuid} did not match report #{report_catalog_uuid}")
    end
  end
end
