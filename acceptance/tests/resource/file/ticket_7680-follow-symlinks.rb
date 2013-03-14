test_name "#7680: 'links => follow' should use the file source content"
confine :except, :platform => 'windows'

agents.each do |agent|

  step "Create file content"
  real_source = agent.tmpfile('follow_links_source')
  dest        = agent.tmpfile('follow_links_dest')
  symlink     = agent.tmpfile('follow_links_symlink')

  on agent, "echo 'This is the real content' > #{real_source}"
  on agent, "ln -sf #{real_source} #{symlink}"

  manifest = <<-MANIFEST
    file { '#{dest}':
      ensure => file,
      source => '#{symlink}',
      links  => follow,
    }
  MANIFEST
  apply_manifest_on(agent, manifest, :trace => true)

  on agent, "cat #{dest}" do
    assert_match /This is the real content/, stdout
  end

  step "Cleanup"
  [real_source, dest, symlink].each do |file|
    on agent, "rm -f '#{file}'"
  end
end


