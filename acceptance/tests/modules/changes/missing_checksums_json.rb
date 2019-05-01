test_name "puppet module changes (module missing checksums.json)" do

  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |agent|
    testdir = agent.tmpdir("module_changes_on_invalid_checksums")

    step "Setup" do
      apply_manifest_on agent, <<~MANIFEST
        file { '#{testdir}/nginx': ensure => directory;
               '#{testdir}/nginx/metadata.json': ensure => present,
                 content => '
                   {
                     "name": "puppetlabs-nginx",
                     "version": "0.0.1",
                     "author": "Puppet Labs",
                     "summary": "Nginx Module",
                     "license": "Apache Version 2.0",
                     "source": "git://github.com/puppetlabs/puppetlabs-nginx.git",
                     "project_page": "https://github.com/puppetlabs/puppetlabs-nginx",
                     "issues_url": "https://github.com/puppetlabs/puppetlabs-nginx",
                     "dependencies": [
                       {"name":"puppetlabs-stdlub","version_requirement":">= 1.0.0"}
                     ]
                   }'
        }
      MANIFEST
    end

    step "Run module changes on a module which is missing checksums.json" do
      on(agent, puppet("module changes #{testdir}/nginx"),
         acceptable_exit_codes: [1]) do

        pattern = Regexp.new([
          ".*Error: No file containing checksums found.*",
          ".*Error: Try 'puppet help module changes' for usage.*"
        ].join("\n"), Regexp::MULTILINE)
        assert_match(pattern, result.stderr)
      end
    end
  end
end
