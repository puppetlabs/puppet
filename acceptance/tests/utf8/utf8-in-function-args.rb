test_name 'utf-8 characters in function parameters' do

  tag 'audit:high',        # utf-8 is high impact in general
      'audit:integration', # not package dependent but may want to vary platform by LOCALE/encoding
      'audit:refactor'     # if keeping, use mk_temp_environment_with_teardown

  confine :except, :platform => [
    'windows',      # PUP-6983
    'eos-4',        # PUP-7146
    'cumulus',      # PUP-7147
    'cisco',        # PUP-7150
    'aix',          # PUP-7194
    'huawei',       # PUP-7195
  ]

  # utf8chars = "€‰ㄘ万竹ÜÖ"
  utf8chars = "\u20ac\u2030\u3118\u4e07\u7af9\u00dc\u00d6"
  agents.each do |agent|
    step 'alert' do
      result = on(
        agent,
        puppet("apply", "-e" "'alert(\"alert #{utf8chars}\")'"),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(
        /#{utf8chars}/,
        result.stderr,
        "Did not find the utf8 chars."
      )
    end

    step 'assert_type' do
      on(
        agent,
        puppet(
          "apply", "-e", "'notice(assert_type(String, \"#{utf8chars}\"))'"
        ),
        {
          :environment => {:LANG => "en_US.UTF-8"},
          :acceptable_exit_codes => [0],
        }
      )
      on(
        agent,
        puppet("apply", "-e 'notice(assert_type(Float, \"#{utf8chars}\"))'"),
        {
          :environment => {:LANG => "en_US.UTF-8"},
          :acceptable_exit_codes => [1],
        }
      )
    end

    step 'filter' do
      puppet_cmd = "'
        [$a] = [[\"abc\", \"#{utf8chars}\", \"100\"]];
        [$f] = [filter($a) |$p| {$p =~ /#{utf8chars}/}];
        notice(\"f = $f\")
      '"
      result = on(
        agent,
        puppet("apply", "-e", puppet_cmd),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(/#{utf8chars}/, result.stdout, "filter() failed.")
    end

    agent_lookup_test_dir = agent.tmpdir("lookup_test_dir")

    mod_name = "lookup_module"
    mod_key = "#{mod_name}::mod_key_#{utf8chars}"
    mod_val = "mod_val_#{utf8chars}"
    env_key = "env_key_#{utf8chars}"
    env_val = "env_val_#{utf8chars}"
    array_key = "array_key_with_utf8_#{utf8chars}"
    array_val_2 = "array value 2 with utf8 #{utf8chars}"
    scalar_key = "scalar_key_with_utf8_#{utf8chars}"
    scalar_val = "scalar value with utf8 #{utf8chars}"
    non_key = "non_key_#{utf8chars}"

    step 'apply hiera/lookup manifest' do
      # I want the banner in the output but
      # some results: orig_hiera_config,
      # orig_environmentpath from operations
      # here are used later, so I don't want
      # them local to a step block.
    end
    lookup_manifest =

<<LOOKUP_MANIFEST

File {
  ensure => directory,
  mode => "0755",
}

file {
  "#{agent_lookup_test_dir}" :;
  "#{agent_lookup_test_dir}/hiera_data" :;
  "#{agent_lookup_test_dir}/environments" :;
  "#{agent_lookup_test_dir}/environments/production" :;
  "#{agent_lookup_test_dir}/environments/production/data" :;
  "#{agent_lookup_test_dir}/environments/production/manifests" :;
  "#{agent_lookup_test_dir}/environments/production/modules" :;
  "#{agent_lookup_test_dir}/environments/production/modules/#{mod_name}" :;
  "#{agent_lookup_test_dir}/environments/production/modules/#{mod_name}/manifests" :;
  "#{agent_lookup_test_dir}/environments/production/modules/#{mod_name}/data" :;
}

file { "#{agent_lookup_test_dir}/environments/production/modules/#{mod_name}/hiera.yaml" :
  ensure => file,
  mode => "0644",
  content => '---
  version: 5
',
}

file { "#{agent_lookup_test_dir}/environments/production/modules/#{mod_name}/data/common.yaml" :
  ensure => "file",
  mode => "0644",
  content => '---
  #{mod_key}: #{mod_val}
',
}

file { "#{agent_lookup_test_dir}/environments/production/environment.conf" :
  ensure => file,
  mode => "0644",
  content => '
# environment_data_provider = "hiera"
'
}

file { "#{agent_lookup_test_dir}/environments/production/hiera.yaml" :
  ensure => file,
  mode => "0644",
  content => '
---
  version: 5
'
}

file { "#{agent_lookup_test_dir}/environments/production/data/common.yaml" :
  ensure => file,
  mode => "0644",
  content => '
---
  #{env_key} : #{env_val}
',
}

file { "#{agent_lookup_test_dir}/hiera.yaml" :
  ensure => file,
  mode => "0644",
  content => '---
:backends:
  - yaml
:hierarchy:
  - common
:yaml:
  :datadir: #{agent_lookup_test_dir}/hiera_data
',
}

file { "#{agent_lookup_test_dir}/hiera_data/common.yaml" :
  ensure => file,
  mode => "0644",
  content => '
#{array_key} :
    - "array value 1"
    - "#{array_val_2}"
#{scalar_key} : "#{scalar_val}"
',
}

LOOKUP_MANIFEST
    apply_manifest_on(
      agent, lookup_manifest, :environment => {:LANG => "en_US.UTF-8"}
    )
    result = on(
      agent,
      puppet("config", "print hiera_config"),
      :environment => {:LANG => "en_US.UTF-8"}
    )
    orig_hiera_config = result.stdout.chomp

    result = on(
      agent,
      puppet("config", "print environmentpath"),
      :environment => {:LANG => "en_US.UTF-8"}
    )
    orig_environmentpath = result.stdout.chomp

    on(
      agent,
      puppet(
        "config",
        "set hiera_config #{agent_lookup_test_dir}/hiera.yaml"
      ),
      :environment => {:LANG => "en_US.UTF-8"}
    )
    on(
      agent,
      puppet(
        "config", "set environmentpath #{agent_lookup_test_dir}/environments"
      ),
      :environment => {:LANG => "en_US.UTF-8"}
    )

    step 'hiera' do
      result = on(
        agent,
        puppet("apply", "-e", "'notice(hiera(\"#{array_key}\"))'"),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(/#{array_val_2}/, result.stdout, "hiera array lookup")

      result = on(
        agent,
        puppet("apply", "-e", "'notice(hiera(\"#{scalar_key}\"))'"),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(/#{scalar_val}/, result.stdout, "hiera scalar lookup")

      result = on(
        agent,
        puppet("apply", "-e", "'notice(hiera(\"#{non_key}\"))'"),
        {
          :acceptable_exit_codes => (0..255),
          :environment => {:LANG => "en_US.UTF-8"}
        }
      )
      assert_match(
        /did not find a value for the name '#{non_key}'/,
        result.stderr,
        "hiera non_key lookup"
      )
    end

    step 'lookup' do
      result = on(
        agent,
        puppet("apply", "-e", "'notice(lookup(\"#{env_key}\"))'"),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(
        /#{env_val}/,
        result.stdout,
        "env lookup failed for '#{env_key}'"
      )

      result = on(
        agent,
        puppet("apply", "-e", "'notice(lookup(\"#{mod_key}\"))'"),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(
        /#{mod_val}/,
        result.stdout,
        "module lookup failed for '#{mod_key}'"
      )

      on(
        agent,
        puppet("config", "set hiera_config #{orig_hiera_config}"),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      on(
        agent,
        puppet("config", "set environmentpath #{orig_environmentpath}"),
        :environment => {:LANG => "en_US.UTF-8"}
      )
    end

    step 'dig' do
      hash_string = "{
        a => {
          b => [
            {
              x => 10,
              y => 20,
            },
            {
              x => 100,
              y => \"dig_result = #{utf8chars}\"
            },
          ]
        }
      }"
      puppet_cmd = "'
        [$v] = [#{hash_string}];
        [$dig_result] = [dig($v, a, b, 1, y)];
        notice($dig_result)
      '"
      result = on(
        agent,
        puppet("apply", "-e", puppet_cmd),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(
        /dig_result = #{utf8chars}/,
        result.stdout,
        "dig() test failed."
      )
    end

    step 'match' do
      strings = [
        "string1_#{utf8chars}",
        "string2_#{utf8chars}",
        "string3_no-utf8",
        "string4_no-utf8"
      ]
      puppet_cmd = "'
        [$vec] = [#{strings}];
        [$found] = [match($vec, /#{utf8chars}/)];
        notice($found)
      '"
      result = on(
        agent,
        puppet("apply", "-e", puppet_cmd),
        :environment => {:LANG => "en_US.UTF-8"}
      )
      assert_match(
        /[[#{utf8chars}], [#{utf8chars}], , ]/,
        result.stdout,
        "match() result unexpected"
      )
    end
  end
end
