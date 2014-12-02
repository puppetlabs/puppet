test_name 'Update pe-puppet pkg' do

  repo_path = ENV['PUPPET_REPO_CONFIGS']
  version = ENV['PUPPET_REF']

  unless repo_path && version
    skip_test "The puppet version to install isn't specified, using what's in the tarball..."
  end

  hosts.each do |host|
    deploy_package_repo(host, repo_path, "pe-puppet", version)
    host.upgrade_package("pe-puppet")
  end

  with_puppet_running_on master, {} do
    # this bounces the puppet master for us
  end
end
