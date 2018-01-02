test_name "node_name_value should be used as the node name for puppet apply"

tag 'audit:medium',
    'audit:integration',  # Ruby level integration tests already exist. This acceptance test can be deleted.
    'audit:delete'

success_message = "node_name_value setting was correctly used as the node name"

manifest = %Q[
  Exec { path => "/usr/bin:/bin" }
  node default {
    notify { "false": }
  }
  node a_different_node_name {
    notify { "notify #{success_message}": }
  }
]

on agents, puppet_apply("--verbose --node_name_value a_different_node_name"), :stdin => manifest do
  assert_match(/defined 'message'.*#{success_message}/, stdout)
end
