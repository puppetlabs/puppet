test_name 'utf-8 characters in module doc string, puppet describe'

utf8chars = "€‰ㄘ万竹ÜÖ"

agents.each do |agent|
  mod_dir = agent.tmpdir("describe")
  manifest =<<PP
File {
  ensure => directory,
  mode => "0755",
}

file {
  '#{mod_dir}/environments':;
  '#{mod_dir}/environments/production':;
  '#{mod_dir}/environments/production/modules':;
  '#{mod_dir}/environments/production/modules/describe_module':;
  '#{mod_dir}/environments/production/modules/describe_module/lib':;
  '#{mod_dir}/environments/production/modules/describe_module/lib/puppet':;
  '#{mod_dir}/environments/production/modules/describe_module/lib/puppet/type':;
}

file { '#{mod_dir}/environments/production/modules/describe_module/lib/puppet/type/describe.rb' :
  ensure => file,
  mode => '0640',
  content => '
Puppet::Type.newtype(:describe) do
  @doc = "Testing to see if puppet handle describe blocks correctly
when they contain utf8 characters, such as #{utf8chars}
"
end
',
}
PP

  step "Apply manifest"
  result = apply_manifest_on(
    agent,
    manifest,
    {:acceptable_exit_codes => [0, 2], :catch_failures => true, }
  )

  step "puppet describe"
  result = on(
    agent,
    puppet("describe", "describe", "--environmentpath #{mod_dir}/environments")
  )
  assert_equal(result.exit_code, 0, "puppet describe failed.")
  assert_match(
    /#{utf8chars}/,
    result.stdout,
   "describe did not match utf8 chars"
  )
end


