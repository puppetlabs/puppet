test_name "#6541: file type truncates target when filebucket cannot retrieve hash"

agents.each do |agent|
  target=agent.tmpfile('6541-target')

  on agent, host_command('rm -rf #{host["puppetvardir"]}/*bucket')

  step "write zero length file"
  manifest = "file { '#{target}': content => '' }"
  apply_manifest_on(agent, manifest)

  step "overwrite file, causing zero-length file to be backed up"
  manifest = "file { '#{target}': content => 'some text' }"
  apply_manifest_on(agent, manifest)

  test_name "verify invalid hashes should not change the file"
  manifest = "file { '#{target}': content => '{md5}notahash' }"
  apply_manifest_on(agent, manifest) do
    assert_no_match(/content changed/, stdout, "#{agent}: shouldn't have overwrote the file")
  end

  test_name "verify valid but unbucketed hashes should not change the file"
  manifest = "file { '#{target}': content => '{md5}13ad7345d56b566a4408ffdcd877bc78' }"
  apply_manifest_on(agent, manifest) do
    assert_no_match(/content changed/, stdout, "#{agent}: shouldn't have overwrote the file")
  end

  test_name "verify that an empty file can be retrieved from the filebucket"
  manifest = "file { '#{target}': content => '{md5}d41d8cd98f00b204e9800998ecf8427e' }"
  apply_manifest_on(agent, manifest) do
    assert_match(/content changed '\{md5\}552e21cd4cd9918678e3c1a0df491bc3' to '\{md5\}d41d8cd98f00b204e9800998ecf8427e'/, stdout, "#{agent}: shouldn't have overwrote the file")
  end
end
