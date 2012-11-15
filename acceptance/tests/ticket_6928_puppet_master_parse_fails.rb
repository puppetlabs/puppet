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
  good = host.tmpfile('good-6928')
  bad = host.tmpfile('bad-6928')

  create_remote_file(host, good, %w{notify{good:}} )
  create_remote_file(host, bad, 'notify{bad:')

  step "Agents: use --parseonly on an invalid manifest, should return 1 and issue deprecation warning"
  on(host, puppet('apply', '--parseonly', bad), :acceptable_exit_codes => [ 1 ]) do
    assert_match(/--parseonly has been removed. Please use \'puppet parser validate <manifest>\'/, stdout, "Deprecation warning not issued for --parseonly on #{host}" )
  end

  step "Test Face for 'parser validate' with good manifest -- should pass"
  on(host, puppet('parser', 'validate', good), :acceptable_exit_codes => [ 0 ])

  step "Test Faces for 'parser validate' with bad manifest -- should fail"
  on(host, puppet('parser', 'validate', bad), :acceptable_exit_codes => [ 1 ]) do
    assert_match(/Error: Could not parse for environment production/, stderr, "Bad manifest detection failed on #{host}" )
  end
end
