test_name 'utf-8 characters in resource title and param values' do

  confine :except, :platform => [
    'windows',    # PUP-6983
    'eos-4',      # PUP-7146
    'cumulus',    # PUP-7147
    'cisco_ios',  # PUP-7150
  ]   

  # utf8chars = "€‰ㄘ万竹ÜÖ"
  utf8chars = "\u20ac\u2030\u3118\u4e07\u7af9\u00dc\u00d6"
  agents.each do |agent|
    agent_file = agent.tmpfile("file" + utf8chars) 
    # remove this file, so puppet can create it and not merely correct
    # its drift.
    on(agent, "rm -rf #{agent_file}", :enviornment => {:LANG => "en_US.UTF-8"})

    manifest =
<<PP

file { "#{agent_file}" :
  ensure => file,
  mode => "0644",
  content => "This is the file content. file #{utf8chars} 
",
}

PP

    step "Apply manifest" do
      result = apply_manifest_on(
        agent,
        manifest,
        {
          :acceptable_exit_codes => (0..2),
          :catch_failures => true, 
          :environment => {:LANG => "en_US.UTF-8"}
        }
      )
      result = on(
        agent, "cat #{agent_file}", :enviornment => {:LANG => "en_US.UTF-8"}
      )
      assert_equal(result.exit_code, 0)
      assert_match(
        /#{utf8chars}/,
        result.stdout,
        "result stdout did not contain"
      )
    end

    step "Drift correction" do
      on(
        agent,
        "echo '' > #{agent_file}",
        :enviornment => {:LANG => "en_US.UTF-8"}
      )
      result = on(
        agent,
        "cat #{agent_file}",
        :enviornment => {:LANG => "en_US.UTF-8"}
      )
      assert_equal(result.stdout.chomp, "", "expected empty file")
      result = apply_manifest_on(
        agent,
        manifest,
        {
          :acceptable_exit_codes => (0..255),
          :catch_failures => true, 
          :environment => {:LANG => "en_US.UTF-8"}
        }
      )
      result = on(
        agent,
        "cat #{agent_file}",
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(
        /#{utf8chars}/,
        result.stdout,
        "result stdout did not contain"
      )
    end
  end
end

