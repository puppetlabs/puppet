test_name "Content Attribute"

agents.each do |agent|
  target = agent.tmpfile('content_file_test')

  step "Ensure the test environment is clean"
  on agent, "rm -f #{target}"

  step "Content Attribute: using raw content"

  manifest = "file { '#{target}': content => 'This is the test file content', ensure => present }"
  apply_manifest_on agent, manifest

  on agent, "cat #{target}" do
    assert_match(/This is the test file content/, stdout, "File content not matched on #{agent}")
  end

  step "Ensure the test environment is clean"
  on agent, "rm -f #{target}"

  step "Content Attribute: using a checksum from filebucket"
  on agent, "echo 'This is the checksum file contents' > #{target}"

  step "Backup file into the filebucket"
  on agent, puppet_filebucket("backup --local #{target}")

  bucketdir="not set"
  on agent, puppet_filebucket("--configprint bucketdir") do
    bucketdir = stdout.chomp
  end

  manifest = %Q|
    filebucket { 'local':
      path => '#{bucketdir}',
    }

    file { '#{target}':
      content => '{md5}18571d3a04b2bb7ccfdbb2c44c72caa9',
      ensure => present,
      backup => local,
    }
  |

  step "Applying Manifest on Agent"
  apply_manifest_on agent, manifest

  step "Validate filebucket checksum file contents"
  on agent, "cat #{target}" do
    assert_match(/This is the checksum file content/, stdout, "File content not matched on #{agent}")
  end
end
