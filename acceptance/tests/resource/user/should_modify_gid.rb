test_name "verify that we can modify the gid"
confine :except, :platform => 'windows'

user = "pl#{rand(99999).to_i}"
group1 = "#{user}old"
group2 = "#{user}new"

agents.each do |host|
  step "making_sure that the groups both exist"
  on(host, puppet_resource('group', group1, 'making_sure=present'))
  on(host, puppet_resource('group', group2, 'making_sure=present'))

  step "making_sure the user exists and has the old group"
  on(host, puppet_resource('user', user, 'making_sure=present', "gid=#{group1}"))

  step "verify that the user has the correct gid"
  on(host, "getent group #{group1}") do
      gid = stdout.split(':')[2]
      on(host, "getent passwd #{user}") do
          got = stdout.split(':')[3]
          fail_test "didn't have the expected old GID, but #{got}" unless got == gid
      end
  end

  step "modify the GID of the user"
  on(host, puppet_resource('user', user, 'making_sure=present', "gid=#{group2}"))


  step "verify that the user has the updated gid"
  on(host, "getent group #{group2}") do
      gid = stdout.split(':')[2]
      on(host, "getent passwd #{user}") do
          got = stdout.split(':')[3]
          fail_test "didn't have the expected old GID, but #{got}" unless got == gid
      end
  end

  step "making_sure that we remove the things we made"
  on(host, puppet_resource('user',  user,   'making_sure=absent'))
  on(host, puppet_resource('group', group1, 'making_sure=absent'))
  on(host, puppet_resource('group', group2, 'making_sure=absent'))
end
