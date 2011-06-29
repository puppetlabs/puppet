test_name "Content Attribute"

step "Ensure the test environment is clean"
on agents, 'rm -f /tmp/content_file_test.txt'

step "Content Attribute: using raw content"

manifest = "file { '/tmp/content_file_test.txt': content => 'This is the test file content', ensure => present }"
apply_manifest_on agents, manifest

agents.each do |host|
  on host, "cat /tmp/content_file_test.txt" do
    assert_match(/This is the test file content/, stdout, "File content not matched on #{host}")
  end
end

step "Ensure the test environment is clean"
on agents, 'rm -f /tmp/content_file_test.txt'

step "Content Attribute: using a checksum from filebucket"
on agents, "echo 'This is the checksum file contents' > /tmp/checksum_test_file.txt"
step "Backup file into the filebucket"
on agents, puppet_filebucket("backup --local /tmp/checksum_test_file.txt")

agents.each do |agent|
  bucketdir="not set"
  on agent, puppet_filebucket("--configprint bucketdir") do 
    bucketdir = stdout.chomp
  end

  manifest = %Q|
    filebucket { 'local':
      path => '#{bucketdir}',
    }

    file { '/tmp/content_file_test.txt':
      content => '{md5}18571d3a04b2bb7ccfdbb2c44c72caa9',
      ensure => present,
      backup => local,
    }
  |

  step "Applying Manifest on Agents"
  apply_manifest_on agent, manifest
end

step "Validate filebucket checksum file contents"
agents.each do |host|
  on host, "cat /tmp/content_file_test.txt" do
    assert_match(/This is the checksum file content/, stdout, "File content not matched on #{host}")
  end
end
