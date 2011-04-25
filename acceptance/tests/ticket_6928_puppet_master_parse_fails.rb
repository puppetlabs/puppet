test_name "#6928: Puppet --parseonly should return deprication message"

# Create good and bad formatted manifests
step "Master: create valid, invalid formatted manifests"
create_remote_file(master, '/tmp/good.pp', %w{notify{good:}} )
create_remote_file(master, '/tmp/bad.pp', 'notify{bad:')

step "Master: use --parseonly on an invalid manifest, should return 1 and issue deprecation warning"
on master, puppet_master( %w{--parseonly /tmp/bad.pp} ), :acceptable_exit_codes => [ 1 ]
  assert_match(/--parseonly has been removed. Please use \'puppet parser validate <manifest>\'/, stdout, "Deprecation warning not issued for --parseonly on #{master}" )

step "Agents: create valid, invalid formatted manifests"
agents.each do |host|
  create_remote_file(host, '/tmp/good.pp', %w{notify{good:}} )
  create_remote_file(host, '/tmp/bad.pp', 'notify{bad:')
end

step "Agents: use --parseonly on an invalid manifest, should return 1 and issue deprecation warning"
agents.each do |host|
  on(host, "puppet --parseonly /tmp/bad.pp}", :acceptable_exit_codes => [ 1 ]) do
    assert_match(/--parseonly has been removed. Please use \'puppet parser validate <manifest>\'/, stdout, "Deprecation warning not issued for --parseonly on #{host}" )
  end
end

step "Test Face for ‘parser validate’ with good manifest -- should pass"
agents.each do |host|
  on(host, "puppet parser validate /tmp/good.pp", :acceptable_exit_codes => [ 0 ])
end

step "Test Faces for ‘parser validate’ with bad manifest -- should fail"
agents.each do |host|
  on(host, "puppet parser validate /tmp/bad.pp", :acceptable_exit_codes => [ 1 ]) do
    assert_match(/err: Could not parse for environment production/, stdout, "Bad manifest detection failed on #{host}" )
  end
end
