test_name "node_name_value should be used as the node name for puppet apply"

success_message = "node_name_value setting was correctly used as the node name"

manifest = %Q[
  Exec { path => "/usr/bin:/bin" }
  node default {
    exec { "false": }
  }
  node a_different_node_name {
    exec { "echo #{success_message}": }
  }
]

on agents, puppet_apply("--verbose --node_name_value a_different_node_name"), :stdin => manifest do
  assert_match(success_message, stdout)
end
