test_name "should purge a user" do
  # Until purging works on AIX, Solaris, and OSX. See PUP-9188
  confine :except, :platform => /^aix/
  confine :except, :platform => /^solaris/
  confine :except, :platform => /^osx/
  tag 'audit:high',
      'audit:acceptance'

  agents.each do |agent|
    unmanaged = "unmanaged-#{rand(999999).to_i}"
    managed = "managed-#{rand(999999).to_i}"
    step "ensure that the unmanaged and managed users do not exist" do
      agent.user_absent(unmanaged)
      agent.user_absent(managed)
    end

    step "create the unmanaged user" do
      on agent, puppet_resource('user', unmanaged, 'ensure=present')
    end

    step "verify the user exists" do
      assert(agent.user_list.include?(unmanaged), "Unmanaged user was not created")
    end

    step "create the managed user and purge unmanaged users" do
      manifest = %Q|
      user {'#{managed}':
        ensure => present
      }
      resources { 'user':
        purge => true,
        unless_system_user => true
      }|
      apply_manifest_on(agent, manifest)
    end

    step "verify the unmanaged user is purged" do
      assert(!agent.user_list.include?(unmanaged), "Unmanaged user was not purged")
    end

    step "verify managed user is not purged" do
      assert(agent.user_list.include?(managed), "Managed user was purged")
    end

    step "verify system user is not purged" do
      if agent['platform'] =~ /windows/
        win_admin_user = agent['locale'] == 'fr' ? "Administrateur" : "Administrator"
        assert(agent.user_list.include?(win_admin_user), "System user (Administrator) was purged")
      else
        assert(agent.user_list.include?("root"), "System user (root) was purged")
      end
    end

    teardown do
      agent.user_absent(unmanaged)
      agent.user_absent(managed)
    end
  end
end
