test_name "puppet module generate (agent)"

# functions and variable declarations
module_user = "user"
module_name = "hello"

# Test
agents.each do |agent|

  step "Generate #{module_user}-#{module_name} module"
  on agent, puppet("module generate #{module_user}-#{module_name}")

  step "Check for #{module_user}-#{module_name} scaffolding"
  on agent,"test -d #{module_user}-#{module_name}"  do
    assert_equal(0, exit_code)
  end
  on agent,"test -f #{module_user}-#{module_name}/manifests/init.pp"  do
    assert_equal(0, exit_code)
  end


  teardown do
    on agent, "rm -fr #{module_user}-#{module_name}"
  end

end
