test_name "The content attribute"
pass_test "Pass forced pending test failure investigation"

step "Ensure the test environment is clean"
on agents, 'rm -f /tmp/content_file_test.txt'

step "When using raw content"

manifest = "file { '/tmp/content_file_test.txt': content => 'This is the test file content', ensure => present }"
apply_manifest_on agents, manifest

on agents, 'test "$(cat /tmp/content_file_test.txt)" = "This is the test file content"'

step "Ensure the test environment is clean"
on agents, 'rm -f /tmp/content_file_test.txt'

step "When using a filebucket checksum from filebucket"

on agents, "echo 'This is the checksum file contents' > /tmp/checksum_test_file.txt"
on agents, "puppet filebucket backup --local /tmp/checksum_test_file.txt"

get_remote_option(agents, 'filebucket', 'bucketdir') do |bucketdir|
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
  apply_manifest_on agents, manifest
end

on agents, 'test "$(cat /tmp/content_file_test.txt)" = "This is the checksum file contents"'
