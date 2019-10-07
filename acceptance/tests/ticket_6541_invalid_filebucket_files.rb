test_name "#6541: file type truncates target when filebucket cannot retrieve hash"

tag 'audit:medium',
    'audit:integration', # file type and file bucket interop
    'audit:refactor'     # look into combining with ticket_4622_filebucket_diff_test.rb
                         # Use block style `test_run`

agents.each do |agent|
  target=agent.tmpfile('6541-target')

  on agent, "rm -rf \"#{agent.puppet['vardir']}/*bucket\""

  step "write zero length file"
  manifest = "file { '#{target}': content => '' }"
  apply_manifest_on(agent, manifest)

  step "overwrite file, causing zero-length file to be backed up"
  manifest = "file { '#{target}': content => 'some text' }"
  apply_manifest_on(agent, manifest)

  test_name "verify invalid hashes should not change the file"
  
  fips_mode = on(agent, facter("fips_enabled")).stdout =~ /true/

  if fips_mode
    manifest = "file { '#{target}': content => '{sha256}notahash' }"
  else
    manifest = "file { '#{target}': content => '{md5}notahash' }"
  end

  apply_manifest_on(agent, manifest) do
    assert_no_match(/content changed/, stdout, "#{agent}: shouldn't have overwrote the file")
  end

  test_name "verify valid but unbucketed hashes should not change the file"
  manifest = "file { '#{target}': content => '{md5}13ad7345d56b566a4408ffdcd877bc78' }"
  apply_manifest_on(agent, manifest) do
    assert_no_match(/content changed/, stdout, "#{agent}: shouldn't have overwrote the file")
  end

  test_name "verify that an empty file can be retrieved from the filebucket"
  if fips_mode
    manifest = "file { '#{target}': content => '{sha256}e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }"
  else
    manifest = "file { '#{target}': content => '{md5}d41d8cd98f00b204e9800998ecf8427e' }"
  end

  apply_manifest_on(agent, manifest) do
    if fips_mode
      assert_match(/content changed '\{sha256\}b94f6f125c79e3a5ffaa826f584c10d52ada669e6762051b826b55776d05aed2' to '\{sha256\}e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'/, stdout, "#{agent}: shouldn't have overwrote the file")
    else
      assert_match(/content changed '\{md5\}552e21cd4cd9918678e3c1a0df491bc3' to '\{md5\}d41d8cd98f00b204e9800998ecf8427e'/, stdout, "#{agent}: shouldn't have overwrote the file")
    end
  end
end
