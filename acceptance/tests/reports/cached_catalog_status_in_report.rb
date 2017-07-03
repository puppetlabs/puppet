test_name "PUP-5867: The report specifies whether a cached catalog was used, and if so, why" do
  tag 'audit:medium',
      'audit:integration',
      'server'

  master_reportdir = create_tmpdir_for_user(master, 'report_dir')

  teardown do
    on(master, "rm -rf #{master_reportdir}")
  end

  def remove_reports_on_master(master_reportdir, agent_node_name)
    on(master, "rm -rf #{master_reportdir}/#{agent_node_name}/*")
  end

  with_puppet_running_on(master, :master => { :reportdir => master_reportdir, :reports => 'store' }) do
    agents.each do |agent|
      step "cached_catalog_status should be 'not used' when a new catalog is retrieved" do
        step "Initial run: cache a newly retrieved catalog" do
          on(agent, puppet("agent", "-t", "--server #{master}"), :acceptable_exit_codes => [0,2])
        end

        step "Run again and ensure report indicates that the cached catalog was not used" do
          on(agent, puppet("agent", "--onetime", "--no-daemonize", "--server #{master}"), :acceptable_exit_codes => [0, 2])
          on(master, "cat #{master_reportdir}/#{agent.node_name}/*") do
            assert_match(/cached_catalog_status: not_used/, stdout, "expected to find 'cached_catalog_status: not_used' in the report")
          end
          remove_reports_on_master(master_reportdir, agent.node_name)
        end
      end

      step "Run with --use_cached_catalog and ensure report indicates cached catalog was explicitly requested" do
        on(agent, puppet("agent", "--onetime", "--no-daemonize", "--use_cached_catalog", "--server #{master}"), :acceptable_exit_codes => [0, 2])
        on(master, "cat #{master_reportdir}/#{agent.node_name}/*") do
          assert_match(/cached_catalog_status: explicitly_requested/, stdout, "expected to find 'cached_catalog_status: explicitly_requested' in the report")
        end
        remove_reports_on_master(master_reportdir, agent.node_name)
      end

      step "On a run which fails to retrieve a new catalog, ensure report indicates cached catalog was used on failure" do
        on(agent, puppet("agent", "--onetime", "--no-daemonize", "--report_server #{master}", "--server nonexist"), :acceptable_exit_codes => [0, 2])
        on(master, "cat #{master_reportdir}/#{agent.node_name}/*") do
          assert_match(/cached_catalog_status: on_failure/, stdout, "expected to find 'cached_catalog_status: on_failure' in the report")
        end
      end
    end
  end
end
