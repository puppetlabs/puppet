test_name "#7101: template compile"

manifest = %q{
$bar = 'test 7101'
file { '/tmp/file_7101.erb':
  content => template('/tmp/template_7101.erb')
}
}


step "Agents: Create template file"
agents.each do |host|
  create_remote_file(host, '/tmp/template_7101.erb', %w{<%= bar %>} )
end

step "Run manifest referencing template file"
apply_manifest_on(agents, manifest)


step "Agents: Verify file is created with correct contents "
agents.each do |host|
  on(host, "cat /tmp/file_7101.erb") do
    assert_match(/test 7101/, stdout, "File /tmp/file_7101.erb not created with correct contents on #{host}" )
  end
end
