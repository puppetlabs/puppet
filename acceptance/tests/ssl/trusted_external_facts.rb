test_name "trusted external fact test" do
  confine :except, :platform => /^cisco_/ # See PUP-5827

  tag 'audit:high',        # cert/ca core behavior
      'audit:integration'

  testdirs = {}

  step "Generate tmp dirs on all hosts" do
    hosts.each do |host|
      testdirs[host] = host.tmpdir('trusted_external_facts')
      on(host, "chmod 755 #{testdirs[host]}")
    end
  end

  step "Step 1: check we can run the trusted external fact" do
    external_trusted_fact_script = <<-EOF
#!/bin/bash
CERTNAME=$1
printf '{"doot":"%s"}\n' "$CERTNAME"
EOF
    agents.each do |agent|
      external_trusted_fact_script_path = "#{testdirs[agent]}/fact.sh"
      create_remote_file(agent, external_trusted_fact_script_path, external_trusted_fact_script)
      on(agent, "chmod 777 #{external_trusted_fact_script_path}")

      puppet_conf = {
        'main' => {
          'trusted_external_command' => external_trusted_fact_script_path
        }
      }
      backup_file = backup_the_file(agent, puppet_config(agent, 'confdir', section: 'master'), testdirs[agent], 'puppet.conf')
      lay_down_new_puppet_conf agent, puppet_conf, testdirs[agent]

      on(agent, puppet("apply", "-e", "\"notify {'trusted facts': message => $::trusted }\""), :acceptable_exit_codes => [0,2])
      assert_match(/external/, stdout, "Trusted fact hash contains external key")
      assert_match(/doot.*#{agent}/, stdout, "trusted facts contains certname")

      restore_puppet_conf_from_backup(agent, backup_file)
    end
  end
end
