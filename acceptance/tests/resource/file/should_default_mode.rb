test_name "file resource: set default modes"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

def regexp_mode(mode)
  Regexp.new("mode\s*=>\s*'0?#{mode}'")
end

agents.each do |agent|
  step "setup"
  parent = agent.tmpdir('default-mode-parent')
  on(agent, "rm -rf #{parent}")

  step "puppet should set execute bit on readable directories"
  on(agent, puppet_resource("file", parent, "ensure=directory", "mode=0644")) do
    assert_match(regexp_mode(755), stdout)
  end

  step "include execute bit on newly created directories"
  dir = "#{parent}/dir"
  on(agent, "mkdir #{dir} && cd #{dir} && cd ..")

  step "exclude execute bit from newly created files"
  file = "#{parent}/file.txt"
  on(agent, "echo foobar > #{file}")
  on(agent, "#{file}", :acceptable_exit_codes => (1..255)) do
    assert_no_match(/foobar/, stdout)
  end

  step "set execute bit on file if explicitly specified"
  file_750 = "#{parent}/file_750.txt"
  on(agent, puppet_resource("file", file_750, "ensure=file", "mode=0750")) do
    assert_match(regexp_mode(750), stdout)
  end

  step "don't set execute bit if directory not readable"
  dir_600 = "#{parent}/dir_600"
  on(agent, puppet_resource("file", dir_600, "ensure=directory", "mode=0600")) do
    assert_match(regexp_mode(700), stdout) # readable by owner, but not group
  end

  on(agent, "rm -rf #{parent}")
end

