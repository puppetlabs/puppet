test_name "should create directory"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  target = agent.tmpfile("create-dir")
  teardown do
    step "clean up after the test run" do
      on(agent, "rm -rf #{target}")
    end
  end

  step "verify we can create a directory" do
    on(agent, puppet_resource("file", target, 'ensure=directory'))
  end

  step "verify the directory was created" do
    on(agent, "test -d #{target}")
  end

  dir_manifest = agent.tmpfile("dir-resource")
  create_remote_file(agent, dir_manifest, <<-PP)
    $dir='#{target}'
    $same_dir='#{target}/'
    file {$dir:
      ensure => directory,
    }
    file { $same_dir:
      ensure => directory,
    }
  PP

  step "verify we can't create same dir resource with a trailing slash" do
    options = {:acceptable_exit_codes => [1]}
    on(agent, puppet_apply("--noop #{dir_manifest}"), options) do |result|
      unless agent['locale'] == 'ja'
        assert_match('Cannot alias File', result.output,
                     'duplicate directory resources did not fail properly')
      end
    end
  end
end
