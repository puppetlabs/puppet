test_name 'C99977 corrupted clientbucket' do
  agents.each do |agent|
    tmpfile = agent.tmpfile('c99977file')
    unmanaged_content = "unmanaged\n"
    unmanaged_sha = Digest::MD5.hexdigest(unmanaged_content)
    managed_content = "managed\n"
    manifest = "file { '#{tmpfile}': content => '#{managed_content}', }"

    step 'create unmanaged file' do
      create_remote_file(agent, tmpfile, unmanaged_content)
    end

    step 'manage file' do
      apply_manifest_on(agent, manifest)
    end

    step 'corrupt clientbucket of file' do
      if agent['platform'] =~ /windows/
        vardir = 'C:/ProgramData/PuppetLabs/puppet/cache'
      else
        vardir = '/opt/puppetlabs/puppet/cache'
      end
      clientbucket_base = "#{vardir}/clientbucket"
      sha_array = unmanaged_sha.scan(/\w/)
      clientbucket_path = clientbucket_base
      (0..7).each do |i|
        clientbucket_path = "#{clientbucket_path}/#{sha_array[i]}"
      end
      clientbucket_path = "#{clientbucket_path}/#{unmanaged_sha}"

      contents_path = "#{clientbucket_path}/contents"
      paths_path = "#{clientbucket_path}/paths"

      create_remote_file(agent, contents_path, "corrupted\n")
      create_remote_file(agent, paths_path, "corrupted\n")
    end

    step 'reset file to pre-managed state' do
      create_remote_file(agent, tmpfile, unmanaged_content)
    end

    step 'manage file again' do
      apply_manifest_on(agent, manifest) do |result|
        expect_failure('no stdrr') do
          assert_equal('', result.stderr)
        end
        expect_failure('file managed') do
          on(agent, "cat #{tmpfile}") do |r2|
            assert_equal(managed_content, r2.stdout)
          end
        end
      end
    end

  end

end
