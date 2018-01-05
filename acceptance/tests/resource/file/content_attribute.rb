test_name "Content Attribute"
tag 'audit:high',
    'audit:refactor',   # Use block stype test_name
    'audit:acceptance'

agents.each do |agent|
  target = agent.tmpfile('content_file_test')

  step "Ensure the test environment is clean"
  on agent, "rm -f #{target}"

  step "Content Attribute: using raw content"

  checksums_fips = ['sha256', 'sha256lite']
  checksums_no_fips = ['md5', 'md5lite', 'sha256', 'sha256lite']

  if on(agent, facter("fips_enabled")).stdout =~ /true/
    checksums = checksums_fips
  else
    checksums = checksums_no_fips
  end

  manifest = "file { '#{target}': content => 'This is the test file content', ensure => present }"
  manifest += checksums.collect {|checksum_type|
    "file { '#{target+checksum_type}': content => 'This is the test file content', ensure => present, checksum => #{checksum_type} }"
  }.join("\n")
  apply_manifest_on agent, manifest do
    checksums.each do |checksum_type|
      assert_no_match(/content changed/, stdout, "#{agent}: shouldn't have overwrote #{target+checksum_type}")
    end
  end

  on agent, "cat #{target}" do
    assert_match(/This is the test file content/, stdout, "File content not matched on #{agent}") unless agent['locale'] == 'ja'
  end

  step "Content Attribute: illegal timesteps"
  ['mtime', 'ctime'].each do |checksum_type|
    manifest = "file { '#{target+checksum_type}': content => 'This is the test file content', ensure => present, checksum => #{checksum_type} }"
    apply_manifest_on agent, manifest, :acceptable_exit_codes => [1] do
      assert_match(/Error: Validation of File\[#{target+checksum_type}\] failed: You cannot specify content when using checksum '#{checksum_type}'/, stderr, "#{agent}: expected failure") unless agent['locale'] == 'ja'
    end
  end

  step "Ensure the test environment is clean"
  on agent, "rm -f #{target}"

  step "Content Attribute: using a checksum from filebucket"
  on agent, "echo 'This is the checksum file contents' > #{target}"

  step "Backup file into the filebucket"
  on agent, puppet_filebucket("backup --local #{target}")

  step "Modify file to force apply to retrieve file from local clientbucket"
  on agent, "echo 'This is the modified file contents' > #{target}"

  dir = on(agent, puppet_filebucket("--configprint clientbucketdir")).stdout.chomp

  md5_manifest = %Q|
    filebucket { 'local':
      path => '#{dir}',
    }

    file { '#{target}':
      ensure  => present,
      content => '{md5}18571d3a04b2bb7ccfdbb2c44c72caa9',
      backup  => local,
    }
  |

  sha256_manifest = %Q|
    filebucket { 'local':
      path => '#{dir}',
    }

    file { '#{target}':
      ensure  => present,
      content => '{sha256}3b9238769b033b48073267b8baea00fa51c598dc14081da51f2e510c37c46a28',
      backup  => local,
    }
  |

  step "Applying Manifest on Agent"
  if on(agent, facter("fips_enabled")).stdout =~ /true/
    apply_manifest_on agent, sha256_manifest
  else    
    apply_manifest_on agent, md5_manifest
  end

  step "Validate filebucket checksum file contents"
  on agent, "cat #{target}" do
    assert_match(/This is the checksum file content/, stdout, "File content not matched on #{agent}") unless agent['locale'] == 'ja'
  end
end
