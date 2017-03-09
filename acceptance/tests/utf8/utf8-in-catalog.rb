test_name 'utf-8 characters in cached catalog' do
  utf8chars = "€‰ㄘ万竹ÜÖ"
  file_content = "This is the file content. file #{utf8chars}"
  tmpdir = master.tmpdir("code")
  on(master, "rm -rf #{tmpdir}")
  env_dir = "#{tmpdir}/environments"
  agents.each do |agent|
    agent_file = agent.tmpfile("file" + utf8chars) 

    step "Apply manifest" do
      on(agent, "rm -rf #{agent_file}")
    
      master_manifest =
<<PP
    
File {
  ensure => directory,
  mode => "0755",
}

file {
  '#{tmpdir}/':;
  '#{tmpdir}/environments':;
  '#{tmpdir}/environments/production':;
  '#{tmpdir}/environments/production/manifests':;
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
        
      apply_manifest_on(
        master,
        master_manifest,
        {:acceptable_exit_codes => [0, 2], :catch_failures => true, }
      )
    end

    master_opts = {
      'main' => {
        'environmentpath' => "#{env_dir}",
      },
      'agent' => {
        'use_cached_catalog' => 'true'
      }
    }
    
    with_puppet_running_on(master, master_opts, tmpdir) do 
      step "puppet agent -t" do
        on(
          agent,
          puppet("agent -t", "--server #{master.hostname}"),
          {:acceptable_exit_codes => [0, 2]}
        )
      end
    
      step "verify cached catalog" do
        result = on(agent, puppet("config print vardir"))
        catalog_file_name =
          "#{result.stdout.strip}/client_data/catalog/#{agent.hostname}.json"
  
        result = on(agent, "cat #{catalog_file_name}")
        assert_match(
          /#{agent_file}/,
          result.stdout,
          "cached catalog does not contain expected agent file name"
        )
        assert_match(
          /#{file_content}/,
          result.stdout,
          "cached catalog does not contain expected file content"
        )
      end
  
      step "apply cached catalog" do
        on(agent, puppet("resource file #{agent_file} ensure=absent"))
        on(agent, puppet("catalog apply --terminus json"))
    
        result = on(agent, "cat #{agent_file}")
        assert_match(
          /#{utf8chars}/,
          result.stdout,
          "result stdout did not contain"
        )
      end
    end
  end
end 
 
