test_name "trusted external fact test" do
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  ### HELPERS ###

  SEPARATOR="<TRUSTED_JSON>"
  def parse_trusted_json(puppet_output)
    trusted_json = puppet_output.split(SEPARATOR)[1]
    if trusted_json.nil?
      raise "Puppet output does not contain the expected '#{SEPARATOR}<trusted_json>#{SEPARATOR}' output"
    end
    JSON.parse(trusted_json)
  rescue => e
    raise "Failed to parse the trusted JSON: #{e}"
  end

  ### END HELPERS ###

  tag 'audit:high',        # external facts
    'server'

  skip_test 'requires a master for serving module content' if master.nil?

  testdir = master.tmpdir('trusted_external_facts')
  on(master, "chmod 755 #{testdir}")
  tmp_environment = mk_tmp_environment_with_teardown(master, File.basename(__FILE__, '.*'))

  teardown do
    on(master, "rm -r '#{testdir}'", :accept_all_exit_codes => true)
  end

  step "create 'external' module referencing trusted hash" do
    on(master, "mkdir -p #{environmentpath}/#{tmp_environment}/modules/external/manifests")
    master_module_manifest = "#{environmentpath}/#{tmp_environment}/modules/external/manifests/init.pp"
    manifest = <<MANIFEST
class external {
  $trusted_json = inline_template('<%= @trusted.to_json %>')
  notify { 'trusted facts':
    message => "#{SEPARATOR}${trusted_json}#{SEPARATOR}"
  }
}
MANIFEST
    create_remote_file(master, master_module_manifest, manifest)
    on(master, "chmod 644 '#{master_module_manifest}'")
  end

  step "create site.pp to classify nodes to include module" do
    site_pp_file = "#{environmentpath}/#{tmp_environment}/manifests/site.pp"
    site_pp      = <<-SITE_PP
node default {
  include external
}
    SITE_PP
    create_remote_file(master, site_pp_file, site_pp)
    on(master, "chmod 644 '#{site_pp_file}'")
  end

  step "when trusted_external_command is a file" do
    external_trusted_fact_script_path = "#{testdir}/external_facts.sh"

    step "create the file" do
      external_trusted_fact_script = <<EOF
#!/bin/bash
CERTNAME=$1
printf '{"doot":"%s"}\n' "$CERTNAME"
EOF
      create_remote_file(master, external_trusted_fact_script_path, external_trusted_fact_script)
      on(master, "chmod 777 #{external_trusted_fact_script_path}")
    end

    step "start the master and perform the test" do
      master_opts = {
        'main' => {
          'trusted_external_command' => external_trusted_fact_script_path
        }
      }

      with_puppet_running_on(master, master_opts) do
        agents.each do |agent|
          on(agent, puppet("agent", "-t", "--environment", tmp_environment), :acceptable_exit_codes => [0,2]) do |res|
            trusted_hash = parse_trusted_json(res.stdout)
            assert_includes(trusted_hash, 'external', "Trusted fact hash contains external key")
            assert_equal(agent.to_s, trusted_hash['external']['doot'], "trusted facts contains certname")
          end
        end
      end
    end
  end

  step "when trusted_external_command is a directory" do
    dir_path = "#{testdir}/commands"
    executable_files = {
      'no_extension' => <<EOF,
#!/bin/bash
CERTNAME=$1
printf '{"no_extension_key":"%s"}\n' "$CERTNAME"
EOF

      'shell.sh' => <<EOF,
#!/bin/bash
CERTNAME=$1
printf '{"shell_key":"%s"}\n' "$CERTNAME"
EOF

      'ruby.rb' => <<EOF,
#!#{master[:privatebindir]}/ruby
require 'json'
CERTNAME=ARGV[0]
data = { "ruby_key" => CERTNAME }
print data.to_json
EOF
    }

    step "create the directory" do
      on(master, "mkdir #{dir_path}")
      on(master, "chmod 755 #{dir_path}")

      executable_files.each do |filename, content|
        filepath = "#{dir_path}/#{filename}"
        create_remote_file(master, filepath, content)
        on(master, "chmod 777 #{filepath}")
      end

      # Create a non-executable file and an executable child-directory
      # to ensure that these cases are skipped during external data
      # retrieval

      create_remote_file(master, "#{dir_path}/non_executable_file", "foo")

      executable_child_dir = "#{dir_path}/child_dir"
      on(master, "mkdir #{executable_child_dir}")
      on(master, "chmod 777 #{executable_child_dir}")
    end

    master_opts = {
      'main' => {
        'trusted_external_command' => dir_path
      }
    }

    step "start the master and perform the test" do
      with_puppet_running_on(master, master_opts) do
        agents.each do |agent|
          on(agent, puppet("agent", "-t", "--environment", tmp_environment), :acceptable_exit_codes => [0,2]) do |res|
            trusted_hash = parse_trusted_json(res.stdout)
            assert_includes(trusted_hash, 'external', "Trusted fact hash contains external key")


            external_keys = [
              'no_extension',
              'shell',
              'ruby'
            ]
            assert_equal(external_keys.sort, trusted_hash['external'].keys.sort, "trusted['external'] does not contain <basename> keys of all executable files")

            external_keys.each do |key|
              expected_data = { "#{key}_key" => agent.to_s }
              data = trusted_hash['external'][key]
              assert_equal(expected_data, data, "trusted['external'][#{key}] does not contain #{key}'s data")
            end
          end
        end
      end
    end

    step "when there's more than executable <basename> script" do
      step "create the conflicting file" do
        filepath = "#{dir_path}/shell.rb"
        create_remote_file(master, filepath, executable_files['shell.sh'])
        on(master, "chmod 777 #{filepath}")
      end

      step "start the master and perform the test" do
        with_puppet_running_on(master, master_opts) do
          agents.each do |agent|
            on(agent, puppet("agent", "-t", "--environment", tmp_environment), :acceptable_exit_codes => [1]) do |res|
              assert_match(/.*shell.*#{Regexp.escape(dir_path)}/, res.stderr)
            end
          end
        end
      end
    end
  end
end
