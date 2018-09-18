test_name "The exec resource should be able to run commands as a different user" do
  confine :except, :platform => 'windows'

  tag 'audit:high',
      'audit:acceptance'

  def random_username
    "pl#{rand(999999).to_i}"
  end

  # TODO: Remove the wrappers to user_present
  # and user_absent if Beaker::Host's user_present
  # and user_absent functions are fixed to work with
  # Arista (EOS).

  def user_present(host, username)
    case host['platform']
    when /eos/
      on(host, "useradd #{username}")
    else
      host.user_present(username)
    end
  end

  def user_absent(host, username)
    case host['platform']
    when /eos/
      on(host, "userdel #{username}", acceptable_exit_codes: [0, 1])
    else
      host.user_absent(username)
    end
  end

  def exec_resource_manifest(params = {})
    default_params = {
      :logoutput => true,
      :path      => '/usr/bin:/usr/sbin:/bin:/sbin',
      :command   => 'echo Hello'
    }
    params = default_params.merge(params)

    params_str = params.map do |param, value|
      value_str = value.to_s
      value_str = "'#{value_str}'" if value.is_a?(String)
      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
exec { 'run_test_command':
  #{params_str}
}
MANIFEST
  end

  agents.each do |agent|
    username = random_username

    # Create our user. Ensure that we start with a clean slate.
    user_absent(agent, username)
    user_present(agent, username)
    teardown { user_absent(agent, username) }

    tmpdir = agent.tmpdir("forbidden")
    on(agent, "chmod 700 #{tmpdir}")

    step "Runs the command even when the user doesn't have permissions to access the pwd" do
      # Can't use apply_manifest_on here because that does not take the :cwd
      # as an option.
      tmpfile = agent.tmpfile("exec_user_perms_manifest")
      create_remote_file(agent, tmpfile, exec_resource_manifest(user: username))
      on(agent, "cd #{tmpdir} && puppet apply #{tmpfile} --detailed-exitcodes", acceptable_exit_codes: [0, 2])
    end

    step "Runs the command even when the user doesn't have permission to access the specified cwd" do
      apply_manifest_on(agent, exec_resource_manifest(user: username, cwd: tmpdir), catch_failures: true)
    end
  end
end
