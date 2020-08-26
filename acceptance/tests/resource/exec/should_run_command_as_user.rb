test_name "The exec resource should be able to run commands as a different user" do
  confine :except, :platform => 'windows'

  tag 'audit:high',
      'audit:acceptance'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::BeakerUtils

  def random_username
    "pl#{rand(999999).to_i}"
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
    agent.user_absent(username)
    agent.user_present(username)
    teardown { agent.user_absent(username) }

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
