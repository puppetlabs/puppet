test_name "Validate bucketpath" do
  tag 'risk:high',
      'server'

  bucket_dir = create_tmpdir_for_user(master, 'buckets')
  teardown do
    on master, "rm -rf #{bucket_dir}"
  end

  contents = 'cf7d0ed4-3d68-4f14-b780-b90077ab530d'
  md5 = on(master, puppet('config', 'print', 'digest_algorithm')).stdout =~ /md5/
  if md5
    hash_type = 'md5'
    hash_value = Digest::MD5.hexdigest(contents)
  else
    hash_type = 'sha256'
    hash_value = Digest::SHA256.hexdigest(contents)
  end

  # prefix is computed from the first 8 characters of the hash, eg "7/7/4/c/6/4/5/7", regardless of type
  prefix = hash_value[0,8].chars
  bucket_path = File.join(bucket_dir, *prefix, hash_value)

  key = puppet_config(master, 'hostprivkey')
  cert = puppet_config(master, 'hostcert')

  step 'setup temporary bucket'
  on master, "mkdir -p #{bucket_path}"
  on master, "touch #{bucket_path}/paths"
  on master, "echo #{contents} > #{bucket_path}/contents"
  on master, "chown -R #{puppet_user(master)}:#{puppet_group(master)} #{bucket_dir}"

  on(master, <<~CURL) do
    curl \
    -k \
    --key #{key} \
    --cert #{cert} \
    -H 'Accept: application/octet-stream' \
    'https://#{master}:8140/puppet/v3/file_bucket_file/#{hash_type}/#{hash_value}?environment=production&bucket_path=#{bucket_dir}'
  CURL
    assert_match(/Could not find file_bucket_file/,
                 stdout,
                 "Should have rejected bucket_path parameter")
    assert_no_match(/#{contents}/,
                    stdout,
                    "Should not be able to read this")
  end
end
