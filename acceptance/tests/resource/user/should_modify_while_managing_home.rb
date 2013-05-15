test_name "should modify a user without changing home directory (pending #19542)"

name = "pl#{rand(999999).to_i}"

def get_home_dir(host, user_name)
  home_dir = nil
  on host, puppet_resource('user', user_name) do |result|
    home_dir = result.stdout.match(/home\s*=>\s*'([^']+)'/m)[1]
  end
  home_dir
end

agents.each do |agent|
  teardown do
    step "delete the user"
    agent.user_absent(name)
    agent.group_absent(name)
  end

  step "ensure the user is present with managehome"
  on agent, puppet_resource('user', name, ["ensure=present", "managehome=true"])

  step "find the current home dir"
  home_dir = get_home_dir(agent, name)

  step "modify the user"
  on agent, puppet_resource('user', name, ["ensure=present", "managehome=true", "home=#{home_dir}_foo"]) do |result|
    # SHOULD: user resource output should contain the new home directory
    pending_test "when #19542 is reimplemented correctly"
  end
  # SHOULD: old home directory should not exist in the filesystem
  # SHOULD: new home directory should exist in the filesystem
end
