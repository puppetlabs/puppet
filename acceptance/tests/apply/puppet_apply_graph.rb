test_name 'C100316 - puppet apply should generate a graph'

tag 'audit:low',
    'audit:integration',  # Core testing of `vardir` should occur in another test.
    'audit:refactor'      # The test should validate that the content of the dot file is sane.

agents.each do |agent|
  step "Create var temp directory"
  vardir = agent.tmpdir('vardir')
  graphdir = File.join(vardir, 'state', 'graphs')

  step "Ensure it creates parent directories and generates the graph"
  on(agent, puppet("apply --graph --graphdir #{graphdir} --vardir #{vardir} -e 'notify { \"hi\": }'")) do
    resources_dot = File.join(graphdir, 'resources.dot')
    if !agent.file_exist?(resources_dot)
      fail_test("Failed to create graph: #{resources_dot}")
    end
  end
end
