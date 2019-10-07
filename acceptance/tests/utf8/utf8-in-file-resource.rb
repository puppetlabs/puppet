test_name 'utf-8 characters in resource title and param values' do

  tag 'audit:high',       # utf-8 is high impact in general
      'audit:integration' # not package dependent but may want to vary platform by LOCALE/encoding

  confine :except, :platform => [
    'windows',    # PUP-6983
    'eos-4',      # PUP-7146
    'cumulus',    # PUP-7147
    'cisco_ios',  # PUP-7150
    'aix',        # PUP-7194
    'huawei',     # PUP-7195
  ]   

  # utf8chars = "€‰ㄘ万竹ÜÖ"
  utf8chars = "\u20ac\u2030\u3118\u4e07\u7af9\u00dc\u00d6"
  agents.each do |agent|
    puts "agent name: #{agent.node_name}, platform: #{agent.platform}"
    agent_file = agent.tmpfile("file" + utf8chars) 
    teardown do
      on(agent, "rm -rf #{agent_file}")
    end
    # remove this file, so puppet can create it and not merely correct
    # its drift.
    on(agent, "rm -rf #{agent_file}", :environment => {:LANG => "en_US.UTF-8"})

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
      apply_manifest_on(
        agent,
        manifest,
        {
          :acceptable_exit_codes => [2],
          :catch_failures => true, 
          :environment => {:LANG => "en_US.UTF-8"}
        }
      )
      on(
        agent, "cat #{agent_file}", :environment => {:LANG => "en_US.UTF-8"}
      ) do
        assert_match(
          /#{utf8chars}/,
          stdout,
          "result stdout did not contain \"#{utf8chars}\"",
        )
      end
    end

    step "Drift correction" do
      on(
        agent,
        "echo '' > #{agent_file}",
        :environment => {:LANG => "en_US.UTF-8"}
      )
      apply_manifest_on(
        agent,
        manifest,
        {
          :acceptable_exit_codes => [2],
          :catch_failures => true, 
          :environment => {:LANG => "en_US.UTF-8"}
        }
      )
      on(
        agent,
        "cat #{agent_file}",
        :environment => {:LANG => "en_US.UTF-8"}
      ) do
        assert_match(
          /#{utf8chars}/,
          stdout,
          "result stdout did not contain \"#{utf8chars}\""
        )
      end
    end
  end
end

