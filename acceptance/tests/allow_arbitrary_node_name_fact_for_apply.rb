test_name "node_name_fact should be used to determine the node name for puppet apply"

success_message = "node_name_fact setting was correctly used to determine the node name"

node_names = []

on agents, facter('kernel') do
  node_names << stdout.chomp
end

node_names.uniq!

manifest = %Q[
  Exec { path => "/usr/bin:/bin" }
  node default {
    exec { "false": }
  }
]

node_names.each do |node_name|
  manifest << %Q[
    node "#{node_name}" {
      exec { "%s": }
    }
  ]
end

agents.each do |agent|
  echo_cmd = agent.echo(success_message)
  on agent, puppet_apply("--verbose --node_name_fact kernel"), :stdin => manifest % echo_cmd do
    assert_match(/#{success_message}.*executed successfully/, stdout)
  end
end
