test_name "concurrent catalog requests (PUP-2659)"

tag 'audit:low',
    'audit:integration',
    'server'

# we're only testing the effects of loading a master with concurrent requests
confine :except, :platform => 'windows'
confine :except, :platform => /osx/ # see PUP-4820
confine :except, :platform => 'solaris'
confine :except, :platform => 'aix'
confine :except, :platform => /^cisco_/ # PA-622

step "setup a manifest"

testdir = master.tmpdir("concurrent")

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
    mode => '750',
  }

  file { '#{testdir}': }
  file { '#{testdir}/busy': }
  file { '#{testdir}/busy/one.txt':
    ensure => file,
    mode => '640',
    content => "Something to read",
  }
  file { '#{testdir}/busy/two.txt':
    ensure => file,
    mode => '640',
    content => "Something else to read",
  }
  file { '#{testdir}/busy/three.txt':
    ensure => file,
    mode => '640',
    content => "Something more else to read",
  }

  file { '#{testdir}/environments': }
  file { '#{testdir}/environments/production': }
  file { '#{testdir}/environments/production/manifests': }
  file { '#{testdir}/environments/production/manifests/site.pp':
    ensure => file,
    content => '
      $foo = inline_template("
        <%- 1000.times do
             Dir.glob(\\'#{testdir}/busy/*.txt\\').each do |f|
               File.read(f)
             end
           end
        %>
        \\'touched the file system for a bit\\'
      ")
      notify { "end":
        message => $foo,
      }
    ',
    mode => '640',
  }
MANIFEST

step "start master"
master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
  }
}
with_puppet_running_on(master, master_opts, testdir) do

  step "concurrent catalog curls (with alliterative alacrity)"
  agents.each do |agent|
    cert_path    = on(agent, puppet('config', 'print', 'hostcert')).stdout.chomp
    key_path     = on(agent, puppet('config', 'print', 'hostprivkey')).stdout.chomp
    cacert_path  = on(agent, puppet('config', 'print', 'localcacert')).stdout.chomp
    agent_cert   = on(agent, puppet('config', 'print', 'certname')).stdout.chomp

    run_count = 6
    agent_tmpdir = agent.tmpdir("concurrent-loop-script")
    test_script = "#{agent_tmpdir}/loop.sh"
    create_remote_file(agent, test_script, <<-EOF)
      declare -a MYPIDS
      loops=#{run_count}

      for (( i=0; i<$loops; i++ )); do
        (
          sleep_for="0.$(( $RANDOM % 49 ))"
          sleep $sleep_for
          url='https://#{master}:8140/puppet/v3/catalog/#{agent_cert}?environment=production'
          echo "Curling: $url"
          env PATH="#{agent[:privatebindir]}:$PATH" curl --tlsv1 -v -# -H 'Accept: text/pson' --cert #{cert_path} --key #{key_path} --cacert #{cacert_path} $url
          echo "$PPID Completed"
        ) > "#{agent_tmpdir}/catalog-request-$i.out" 2>&1 &
        echo "Launched $!"
        MYPIDS[$i]=$!
      done

      for (( i=0; i<$loops; i++ )); do
        wait ${MYPIDS[$i]}
      done

      echo "All requests are finished"
    EOF
    on(agent, "chmod +x #{test_script}")
    on(agent, "#{test_script}")
    run_count.times do |i|
      step "Checking the results of catalog request ##{i}"
      on(agent, "cat #{agent_tmpdir}/catalog-request-#{i}.out") do
        assert_match(%r{< HTTP/1.* 200}, stdout)
        assert_match(%r{touched the file system for a bit}, stdout)
      end
    end
  end
end
