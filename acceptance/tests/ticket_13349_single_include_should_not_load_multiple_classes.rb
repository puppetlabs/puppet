test_name "class inclusion should respect explicit scoping"

success_message = "GOOD: top level bar::something"
failure_message = "BAD: nested bar::something in foo"

manifest = %Q[
  class { 'foo::test': }

  class foo::test {
  	class { '::bar::something': }
  }

  class bar::something {
  	notify { '#{success_message}': withpath => true }
  }

  class foo::bar::something {
  	notify { '#{failure_message}': withpath => true }
  }
]

on agents, puppet_apply("--verbose"), :stdin => manifest do
  assert_match(/#{success_message}/, stdout)
  assert_no_match(/#{failure_message}/, stdout)
end
