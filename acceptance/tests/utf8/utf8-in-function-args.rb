test_name 'utf-8 characters in function parameters'

confine :except, :platform => [ 'windows', 'ubuntu-16']   # PUP-6983

utf8chars = "€‰ㄘ万竹ÜÖ"


master_lookup_test_dir = master.tmpdir("lookup_test_dir")
master_opts = {
  'main' => {
    'hiera_config' => "#{master_lookup_test_dir}/hiera.yaml",
    'environmentpath' => "#{master_lookup_test_dir}/environments",
  },
}
with_puppet_running_on(master, master_opts, master_lookup_test_dir) do
  agents.each do |agent|
 
    step 'alert'
 
    result = on(
      agent,
      puppet("apply", "-e 'alert(\"alert #{utf8chars}\")'"),

      :acceptable_exit_codes => (0..255)

    )
    assert_match(/#{utf8chars}/, result.stderr, "Did not find the utf8 chars.")
  
  
    step 'assert_type'
  
    result = on(
      agent,
      puppet("apply", "-e 'notice(assert_type(String, \"#{utf8chars}\"))'"),
      :acceptable_exit_codes => [0]
    )
    result = on(
      agent,
      puppet("apply", "-e 'notice(assert_type(Float, \"#{utf8chars}\"))'"),
      :acceptable_exit_codes => [1]
    )
  
  
    step 'filter'
  
    puppet_cmd = "'
      [$a] = [[\"abc\", \"#{utf8chars}\", \"100\"]];
      [$f] = [filter($a) |$p| {$p =~ /#{utf8chars}/}];
      notice(\"f = $f\")
  '"
  
    result = on(agent, puppet("apply", "-e", puppet_cmd))
    assert_match(/#{utf8chars}/, result.stdout, "filter() failed.")
   
   
    step 'apply hiera/lookup manifest'
    if (agent == master) then
      agent_lookup_test_dir = master_lookup_test_dir
    else
      agent_lookup_test_dir = agent.tmpdir("lookup_test_dir")
    end

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

    lookup_manifest = <<LOOKUP_MANIFEST

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

    apply_manifest_on(agent, lookup_manifest)

    result = on(
      agent,
      puppet("config", "print hiera_config")
    )
    orig_hiera_config = result.stdout.chomp

    result = on(
      agent,
      puppet("config", "print environmentpath")
    )
    orig_environmentpath = result.stdout.chomp

    result = on(
      agent,
      puppet("config", "set hiera_config #{agent_lookup_test_dir}/hiera.yaml")
    )
    result = on(
      agent,
      puppet("config", "set environmentpath #{agent_lookup_test_dir}/environments")
    )


    step 'hiera'

    result = on(
      agent,
      puppet("apply", "-e", "'notice(hiera(\"#{array_key}\"))'")
    )
    assert_match(/#{array_val_2}/, result.stdout, "hiera array lookup")

    result = on(
      agent,
      puppet("apply", "-e", "'notice(hiera(\"#{scalar_key}\"))'")
    )
    assert_match(/#{scalar_val}/, result.stdout, "hiera scalar lookup")

    result = on(
      agent,
      puppet("apply", "-e", "'notice(hiera(\"#{non_key}\"))'"),
      :acceptable_exit_codes => (0..255)
    )
    assert_match(
      /did not find a value for the name '#{non_key}'/,
      result.stderr,
      "hiera non_key lookup"
    )


    step 'lookup' 

    result = on(
      agent,
      puppet("apply", "-e", "'notice(lookup(\"#{env_key}\"))'")
    )
    assert_match(
      /#{env_val}/,
      result.stdout,
      "env lookup failed for '#{env_key}'"
    )

    result = on(
      agent,
      puppet("apply", "-e", "'notice(lookup(\"#{mod_key}\"))'")
    )
    assert_match(
      /#{mod_val}/,
      result.stdout,
      "module lookup failed for '#{mod_key}'"
    )

    result = on(
      agent,
      puppet("config", "set hiera_config #{orig_hiera_config}")
    )
    result = on(
      agent,
      puppet("config", "set environmentpath #{orig_environmentpath}")
    )
    
    
    step 'dig'
    
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
    
    result = on(agent, puppet("apply", "-e", puppet_cmd))
    assert_match(
      /dig_result = #{utf8chars}/,
      result.stdout,
      "dig() test failed."
    )
    
    
    step 'match'
    
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
    
    result = on(agent, puppet("apply", "-e", puppet_cmd))
    assert_match(
      /[[€‰ㄘ万竹ÜÖ], [€‰ㄘ万竹ÜÖ], , ]/,
      result.stdout,
      "match() result unexpected"
    )

  end
end

