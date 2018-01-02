test_name "PUP-5872: catalog_uuid correlates catalogs with reports" do

  tag 'audit:medium',
      'audit:acceptance',
      'audit:refactor'    # remove dependence on server by adding a
                          # catalog and report fixture to validate against.

  master_reportdir = create_tmpdir_for_user(master, 'reportdir')

  def remove_reports_on_master(master_reportdir, agent_node_name)
    on(master, "rm -rf #{master_reportdir}/#{agent_node_name}/*")
  end

  def get_catalog_uuid_from_cached_catalog(host, agent_vardir, agent_node_name)
    cache_catalog_uuid = nil
    on(host, "cat #{agent_vardir}/client_data/catalog/#{agent_node_name}.json") do
      cache_catalog_uuid = stdout.match(/"catalog_uuid":"([a-z0-9\-]*)",/)[1]
    end
    cache_catalog_uuid
  end

  def get_catalog_uuid_from_report(master_reportdir, agent_node_name)
    report_catalog_uuid = nil
    on(master, "cat #{master_reportdir}/#{agent_node_name}/*") do
      report_catalog_uuid = stdout.match(/catalog_uuid: '?([a-z0-9\-]*)'?/)[1]
    end
    report_catalog_uuid
  end

  with_puppet_running_on(master, :master => { :reportdir => master_reportdir, :reports => 'store' }) do
    agents.each do |agent|
      agent_vardir = agent.tmpdir(File.basename(__FILE__, '.*'))

      step "agent: #{agent}: Initial run to retrieve a catalog and generate the first report" do
        on(agent, puppet("agent", "-t", "--vardir #{agent_vardir}", "--server #{master}"), :acceptable_exit_codes => [0,2])
      end

      cache_catalog_uuid = get_catalog_uuid_from_cached_catalog(agent, agent_vardir, agent.node_name)

      step "agent: #{agent}: Ensure the catalog and report share the same catalog_uuid" do
        report_catalog_uuid = get_catalog_uuid_from_report(master_reportdir, agent.node_name)
        assert_equal(cache_catalog_uuid, report_catalog_uuid, "catalog_uuid found in cached catalog, #{cache_catalog_uuid} did not match report #{report_catalog_uuid}")
      end

      step "cleanup reports on master" do
        remove_reports_on_master(master_reportdir, agent.node_name)
      end

      step "Run with --use_cached_catalog and ensure catalog_uuid in the new report matches the cached catalog" do
        on(agent, puppet("agent", "--onetime", "--no-daemonize", "--use_cached_catalog", "--vardir #{agent_vardir}", "--server #{master}"), :acceptance_exit_codes => [0,2])
        report_catalog_uuid = get_catalog_uuid_from_report(master_reportdir, agent.node_name)
        assert_equal(cache_catalog_uuid, report_catalog_uuid, "catalog_uuid found in cached catalog, #{cache_catalog_uuid} did not match report #{report_catalog_uuid}")
      end
    end
  end
end
