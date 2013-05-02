test_name "#6928: puppet parser validate"

# Create good and bad formatted manifests
step "Master: create valid, invalid formatted manifests"
create_remote_file(master, '/tmp/good.pp', %w{notify{good:}} )
create_remote_file(master, '/tmp/bad.pp', 'notify{bad:')

step "Master: setup files"
good = master.tmpfile('good-6928')
bad = master.tmpfile('bad-6928')
create_remote_file(master, good, %w{notify{good:}} )
create_remote_file(master, bad, 'notify{bad:')

step "Test Face for 'parser validate' with good manifest -- should pass"
on(master, puppet('parser', 'validate', good), :acceptable_exit_codes => [ 0 ])

step "Test Faces for 'parser validate' with bad manifest -- should fail"
on(master, puppet('parser', 'validate', bad), :acceptable_exit_codes => [ 1 ]) do
  assert_match(/Error: Could not parse for environment production/, stderr, "Bad manifest detection failed on #{master}" )
end
