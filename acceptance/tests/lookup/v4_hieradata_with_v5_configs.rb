test_name "C99572: v4 hieradata with v5 configs" do
  require "puppet/acceptance/puppet_type_test_tools.rb"
  extend Puppet::Acceptance::PuppetTypeTestTools

  tag 'audit:medium',
      'audit:acceptance'

  app_type = File.basename(__FILE__, ".*")

  agents.each do |agent|
    hiera_conf_backup = agent.tmpdir("C99572-hiera-yaml")
    tmp_env = mk_tmp_environment_with_teardown(agent, app_type)
    fq_tmp_env_path = "#{agent.puppet['environmentpath']}/#{tmp_env}"
    confdir = agent.puppet["confdir"]

    teardown do
      step "restore hiera.yaml and environment" do
        on(agent, "mv #{hiera_conf_backup}/hiera.yaml #{confdir}/hiera.yaml",
           acceptable_exit_codes: [0, 1])
      end
    end

    step "backup global hiera.yaml" do
      on(agent, "cp -a #{confdir}/hiera.yaml #{hiera_conf_backup}",
         acceptable_exit_codes: [0, 1])
    end

    step "create global hiera.yaml and data" do
      agent.mkdir_p("#{confdir}/hiera.yaml")
      create_remote_file(agent, "#{confdir}/hiera.yaml", <<~HIERA)
        ---
        version: 5
        hierarchy:
          - name: "%{environment}"
            data_hash: yaml_data
            path: "%{environment}.yaml"
          - name: common
            data_hash: yaml_data
            path: "common.yaml"
      HIERA
      on(agent, "chmod 755 #{confdir}/hiera.yaml")
      create_remote_file(agent, "#{confdir}/#{tmp_env}.yaml", <<~YAML)
        ---
        environment_key: environment_key-global_env_file
        global_key: global_key-global_env_file
      YAML
      create_remote_file(agent, "#{confdir}/common.yaml", <<~YAML)
        ---
        environment_key: environment_key-global_common_file
        global_key: global_key-global_common_file
      YAML
    end

    step "create environment hiera.yaml and data" do
      agent.mkdir_p("#{fq_tmp_env_path}/data")
      create_remote_file(agent, "#{fq_tmp_env_path}/hiera.yaml", <<~HIERA)
        ---
        version: 5
        hierarchy:
          - name: "%{environment}"
            data_hash: yaml_data
            path: "%{environment}.yaml"
          - name: common
            data_hash: yaml_data
            path: "common.yaml"
          - name: hocon
            data_hash: hocon_data
            path: "common.conf"
      HIERA
      create_remote_file(agent, "#{fq_tmp_env_path}/data/#{tmp_env}.yaml", <<~YAML)
        ---
        environment_key: "environment_key-env_file"
      YAML
      create_remote_file(agent, "#{fq_tmp_env_path}/data/common.yaml", <<~YAML)
        ---
        environment_key: "environment_key-common_file"
        global_key: "global_key-common_file"
      YAML
      step "C99628: add hocon backend and data" do
        create_remote_file(agent, "#{fq_tmp_env_path}/data/common.conf", <<~HOCON)
          environment_key2 = "hocon value",
        HOCON
      end

      create_sitepp(agent, tmp_env, <<~SITE)
        notify { "${lookup('environment_key')}": }
        notify { "${lookup('global_key')}": }
        notify { "${lookup('environment_key2')}": }
      SITE
      on(agent, "chmod -R 755 #{fq_tmp_env_path}")
    end

    step "assert lookups using lookup subcommand" do
      on(agent, puppet("lookup", "--environment #{tmp_env}", "environment_key"),
         accept_all_exit_codes: true) do |result|
        assert(result.exit_code.zero?,
               "1: lookup subcommand didn't exit properly: (#{result.exit_code})")
        assert_match(/environment_key-env_file/, result.stdout,
                     "lookup environment_key subcommand didn't find correct key")
      end
      on(agent, puppet("lookup", "--environment #{tmp_env}", "global_key"),
         accept_all_exit_codes: true) do |result|
        assert(result.exit_code.zero?,
               "2: lookup subcommand didn't exit properly: (#{result.exit_code})")
        assert_match(/global_key-common_file/, result.stdout,
                     "lookup global_key subcommand didn't find correct key")
      end
      on(agent, puppet("lookup", "--environment #{tmp_env}", "environment_key2"),
         accept_all_exit_codes: true) do |result|
        assert(result.exit_code.zero?,
               "3: lookup subcommand didn't exit properly: (#{result.exit_code})")
        assert_match(/hocon value/, result.stdout,
                     "lookup environment_key2 subcommand didn't find correct key")
      end
    end

    step "agent lookup" do
      on(agent, puppet("apply", "#{fq_tmp_env_path}/manifests/site.pp",
                       environment: tmp_env)) do |result|
        assert_match(/global_key-common_file/m, result.stdout,
                     "agent lookup didn't find global key")
        assert_match(/environment_key-env_file/m, result.stdout,
                     "agent lookup didn't find environment_key")
        assert_match(/hocon value/m, result.stdout,
                     "agent lookup didn't find environment_key2")
      end
    end
  end
end
