test_name "trusted external fact test" do
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  tag 'audit:high',        # external facts
      'server'

  skip_test 'requires a master for serving module content' if master.nil?

  testdir = master.tmpdir('trusted_external_facts')
  on(master, "chmod 755 #{testdir}")
  external_trusted_fact_script_path = "#{testdir}/external_facts.sh"
  tmp_environment = mk_tmp_environment_with_teardown(master, File.basename(__FILE__, '.*'))

  teardown do
    on(master, "rm -r '#{testdir}'", :accept_all_exit_codes => true)
  end

  step "Step 1: check we can run the trusted external fact" do
    external_trusted_fact_script = <<EOF
#!/bin/bash
CERTNAME=$1
printf '{"doot":"%s"}\n' "$CERTNAME"
EOF
    create_remote_file(master, external_trusted_fact_script_path, external_trusted_fact_script)
    on(master, "chmod 777 #{external_trusted_fact_script_path}")
  end

  step "Step 2: create external module referencing trusted hash" do
    on(master, "mkdir -p #{environmentpath}/#{tmp_environment}/modules/external/manifests")
    master_module_manifest = "#{environmentpath}/#{tmp_environment}/modules/external/manifests/init.pp"
    manifest = <<MANIFEST
class external {
  notify { 'trusted facts':
    message => $::trusted
  }
}
MANIFEST
    create_remote_file(master, master_module_manifest, manifest)
    on(master, "chmod 644 '#{master_module_manifest}'")
  end

  step "Step 3: Create site.pp to classify nodes to include module" do
    site_pp_file = "#{environmentpath}/#{tmp_environment}/manifests/site.pp"
    site_pp      = <<-SITE_PP
node default {
  include external
}
SITE_PP
    create_remote_file(master, site_pp_file, site_pp)
    on(master, "chmod 644 '#{site_pp_file}'")
  end

  step "Step 4: start the master" do
    master_opts = {
      'main' => {
        'trusted_external_command' => external_trusted_fact_script_path
      }
    }

    with_puppet_running_on(master, master_opts) do
      agents.each do |agent|
        on(agent, puppet("agent", "-t", "--environment", tmp_environment), :acceptable_exit_codes => [0,2]) do |res|
          assert_match(/external/, res.stdout, "Trusted fact hash contains external key")
          assert_match(/doot.*#{agent}/, res.stdout, "trusted facts contains certname")
        end
      end
    end
  end
end
