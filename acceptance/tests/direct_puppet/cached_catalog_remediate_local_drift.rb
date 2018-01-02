require 'puppet/acceptance/static_catalog_utils'
extend Puppet::Acceptance::StaticCatalogUtils

test_name "PUP-5122: Puppet remediates local drift using code_id and content_uri" do

  tag 'audit:medium',
      'audit:acceptance',
      'audit:refactor',  # use mk_tmp_environment_with_teardown helper for environment construction
      'server'


  skip_test 'requires puppetserver installation' if @options[:type] != 'aio'

  basedir = master.tmpdir(File.basename(__FILE__, '.*'))
  module_dir = "#{basedir}/environments/production/modules"
  modulepath = "#{module_dir}"

  master_opts = {
   'main' => {
      'environmentpath' => "#{basedir}/environments"
    }
  }

  step "Add versioned-code parameters to puppetserver.conf and ensure the server is running" do
    setup_puppetserver_code_id_scripts(master, basedir)
  end

  teardown do
    cleanup_puppetserver_code_id_scripts(master, basedir)
    on master, "rm -rf #{basedir}"
  end

  step "Create a module and a file with content representing the first code_id version" do
    apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  mode => "0750",
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
}

file {
  '#{basedir}':;
  '#{basedir}/environments':;
  '#{basedir}/environments/production':;
  '#{basedir}/environments/production/manifests':;
  '#{module_dir}':;
  '#{module_dir}/foo':;
  '#{module_dir}/foo/files':;
}
MANIFEST
  end

  with_puppet_running_on master, master_opts, basedir do
    agents.each do |agent|
      agent_test_file_path = agent.tmpfile('foo_file')

      step "Add test file resource to site.pp on master with agent-specific file path" do
        apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
File {
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
}

file { "#{basedir}/environments/production/manifests/site.pp" :
  ensure => file,
  mode => "0640",
  content => "node default {
  file { '#{agent_test_file_path}' :
    ensure => file,
    source => 'puppet:///modules/foo/foo.txt'
  }
}",
}

file { "#{module_dir}/foo/files/foo.txt" :
  ensure => file,
  content => "code_version_1",
  mode => "0640",
}
MANIFEST
      end

      step "agent: #{agent}: Initial run: create the file with code version 1 and cache the catalog"
      on(agent, puppet("agent", "-t", "--server #{master}"), :acceptable_exit_codes => [0,2])

      # When there is no drift, there should be no request made to the server
      # for file metadata or file content.  A puppet run depending on
      # a non-server will fail if such a request is made.  Verify the agent
      # sends a report.

      step "Remove existing reports from server reports directory"
      on(master, "rm -rf /opt/puppetlabs/server/data/puppetserver/reports/#{agent.node_name}/*")
      r = on(master, "ls /opt/puppetlabs/server/data/puppetserver/reports/#{agent.node_name} | wc -l").stdout.chomp
      assert_equal(r, '0', "reports directory should be empty!")

      step "Verify puppet run without drift does not make file request from server"
      r = on(agent, puppet("agent",
        "--use_cached_catalog",
        "--server", "no_such_host",
        "--report_server", master.hostname,
        "--onetime",
        "--no-daemonize",
        "--detailed-exitcodes",
        "--verbose"
      )).stderr
      assert_equal(r, "", "Fail: Did agent try to contact server?")

      step "Verify report was delivered to server"
      r = on(master, "ls /opt/puppetlabs/server/data/puppetserver/reports/#{agent.node_name} | wc -l").stdout.chomp
      assert_equal(r, '1', "Reports directory should have one file")

      step "agent: #{agent}: Remove the test file to simulate drift"
      on(agent, "rm -rf #{agent_test_file_path}")

      step "Alter the source file on the master to simulate a code update"
      apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
file { "#{module_dir}/foo/files/foo.txt" :
  ensure => file,
  mode => "0640",
  content => "code_version_2",
}
MANIFEST

      step "Run agent again using --use_cached_catalog and ensure content from the first code_id is used"
      on(agent, puppet("agent", "-t", "--use_cached_catalog", "--server #{master}"), :acceptable_exit_codes => [0,2])
      on(agent, "cat #{agent_test_file_path}") do
        assert_equal('code_version_1', stdout)
      end
    end
  end
end
