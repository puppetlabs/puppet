test_name 'utf-8 characters in cached catalog' do

  tag 'audit:high', # utf-8 is high impact in general
      'audit:integration', # not package dependent but may want to vary platform by LOCALE/encoding
      'audit:refactor' # use mk_temp_environment_with_teardown

  utf8chars_lit = "€‰ㄘ万竹ÜÖ"
  utf8chars     = "\u20ac\u2030\u3118\u4e07\u7af9\u00dc\u00d6"
  file_content  = "This is the file content. file #{utf8chars}"
  codedir       = master.tmpdir("code")
  on(master, "rm -rf '#{codedir}'")
  env_dir = "#{codedir}/environments"
  agents.each do |agent|

    step "agent name: #{agent.hostname}, platform: #{agent.platform}"
    agent_vardir = agent.tmpdir("agent_vardir")
    agent_file   = agent.tmpfile("file" + utf8chars)
    teardown do
      on(agent, "rm -rf '#{agent_vardir}' '#{agent_file}'")
    end

    step "Apply manifest" do
      on(agent, "rm -rf '#{agent_file}'", :environment => { :LANG => "en_US.UTF-8" })

      master_manifest = <<PP
File {
  ensure => directory,
  mode => "0755",
}

file {
  '#{codedir}/':;
  '#{codedir}/environments':;
  '#{codedir}/environments/production':;
  '#{codedir}/environments/production/manifests':;
}

file { '#{env_dir}/production/manifests/site.pp' :
  ensure => file,
  mode => '0644',
  content => '
    file { "#{agent_file}" :
      ensure => file,
      mode => "0644",
      content => "#{file_content}
    ",
    }
  ',
}
PP

      apply_manifest_on(master, master_manifest, {:acceptable_exit_codes => [0, 2],
                                                  :catch_failures => true, :environment => { :LANG => "en_US.UTF-8" }})
    end

    master_opts = {
        'main'  => {
            'environmentpath' => "#{env_dir}",
        },
        'agent' => {
            'use_cached_catalog' => 'true'
        }
    }

    with_puppet_running_on(master, master_opts, codedir) do
      step "apply utf-8 catalog" do
        on(agent, puppet("agent -t --vardir '#{agent_vardir}' --server #{master.hostname}"),
           { :acceptable_exit_codes => [2], :environment => { :LANG => "en_US.UTF-8" } })
      end

      step "verify cached catalog" do
        catalog_file_name = "#{agent_vardir}/client_data/catalog/#{agent.node_name}.json"

        on(agent, "cat '#{catalog_file_name}'", :environment => { :LANG => "en_US.UTF-8" }) do |result|
          assert_match(/#{agent_file}/, result.stdout, "cached catalog does not contain expected agent file name")
          assert_match(/#{file_content}/, result.stdout, "cached catalog does not contain expected file content")
        end
      end

      step "apply cached catalog" do
        on(agent, puppet("resource file '#{agent_file}' ensure=absent"), :environment => { :LANG => "en_US.UTF-8" })
        on(agent, puppet("catalog apply --vardir '#{agent_vardir}' --terminus json"), :environment => { :LANG => "en_US.UTF-8" })
        on(agent, "cat '#{agent_file}'", :environment => { :LANG => "en_US.UTF-8" }) do |result|
          assert_match(/#{utf8chars}/, result.stdout, "result stdout did not contain \"#{utf8chars}\"")
        end
      end
    end
  end
end 
 
