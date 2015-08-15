test_name "Authorization can be disabled with bypass_authorization"

authconf_path = on(master, puppet('config print rest_authconfig')).stdout.strip

step "Copy default auth.conf to restore on teardown" do
  original_authconf = on(master, "cat #{authconf_path}").stdout
  teardown do
    create_remote_file(master, authconf_path, original_authconf)
  end
end

cert = on(master, puppet('config print hostcert')).stdout.strip
key = on(master, puppet('config print hostprivkey')).stdout.strip
cacert = on(master, puppet('config print localcacert')).stdout.strip
curl = "curl --cert #{cert} --key #{key} --cacert #{cacert} https://#{master}:8140"

step "Authorization enabled by default" do
  with_puppet_running_on(master, {}) do
    on(master, curl + "/puppet/v3/node/foo?environment=production") do
      assert_match(/Forbidden request/, stdout, 'Expected request denied')
    end
  end
end

step "Authorization disabled with bypass_authorization" do

  step "Install deny-all auth.conf" do
    create_remote_file(master, authconf_path, <<AUTHCONF)
path /
auth any
deny all
AUTHCONF
  end

  step "Verify requests denied by auth.conf" do
    with_puppet_running_on(master, {:master => {:bypass_authorization => false}}) do
      on(master, curl + "/puppet/v3/node/#{master}?environment=production") do
        assert_match(/Forbidden request/, stdout, 'Expected request denied')
      end
    end
  end

  step "Enable bypass_authorization and verify requests succeed" do
    with_puppet_running_on(master, {:master => {:bypass_authorization => true}}) do
      on(master, curl + "/puppet/v3/node/#{master}?environment=production") do
        assert_no_match(/Forbidden request/, stdout, 'Expected request success')
      end
    end
  end
end
