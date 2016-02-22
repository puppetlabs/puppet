test_name "PUP-5122: Puppet remediates local drift using code_id and content_uri" do

  skip_test 'requires puppetserver installation' if @options[:type] != 'aio'

  basedir = master.tmpdir(File.basename(__FILE__, '.*'))
  module_dir = "#{basedir}/environments/production/modules"
  modulepath = "#{module_dir}"
  agent_test_file_path = agent.tmpfile('foo_file')

  master_opts = {
   'master' => {
      'static_catalogs' => true
    },
   'main' => {
      'environmentpath' => "#{basedir}/environments"
    }
  }

  step "Add versioned-code parameters to puppetserver.conf and ensure the server is running" do
    puppetserver_config = "#{master['puppetserver-confdir']}/puppetserver.conf"
    versioned_code_settings = {"code-id-command" => "#{basedir}/code_id.sh", "code-content-command" => "#{basedir}/code_content.sh"}

    modify_tk_config(master, puppetserver_config, versioned_code_settings)
    on(master, puppet_resource('service', 'puppetserver', 'ensure=running'))
  end

  step "Create a module and a file with content representing the first code_id version, and Setup code-id-command and code-content-command scripts" do
    code_id_command = <<EOF
    #! /bin/sh

    echo 'code_version_1'
EOF

    code_content_command = <<EOF
    #! /bin/sh

    if [ \\\$2 == 'code_version_1' ] ; then
      echo 'code_version_1'
    else
      echo 'newer_code_version'
    fi
EOF

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

    file { "site.pp":
      ensure => file,
      path => "#{basedir}/environments/production/manifests/site.pp",
      content => "node default { file { 'foo_file': ensure => file, path => '#{agent_test_file_path}', source => 'puppet:///modules/foo/foo.txt' } }",
      mode => "0640",
    }

    file { "foo_file":
      ensure => file,
      path => "#{module_dir}/foo/files/foo.txt",
      content => "code_version_1",
      mode => "0640",
    }

    file { '#{basedir}/code_id.sh':
      ensure => file,
      content => "#{code_id_command}",
      mode => "0755",
    }

    file { '#{basedir}/code_content.sh':
      ensure => file,
      content => "#{code_content_command}",
      mode => "0755",
    }
MANIFEST
  end

  with_puppet_running_on master, master_opts, basedir do
    agents.each do |agent|
      step "agent: #{agent}: Initial run: create the file with code version 1 and cache the catalog"
      on(agent, puppet("agent", "-t", "--server #{master}"), :acceptable_exit_codes => [0,2])

      step "agent: #{agent}: Remove the test file to simulate drift"
      on(agent, "rm -rf #{agent_test_file_path}")

      step "Alter the source file on the master to simulate a code update"
      apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
        file { "foo_file":
          ensure => file,
          path => "#{module_dir}/foo/files/foo.txt",
          content => "code_version_2",
          mode => "0640",
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
