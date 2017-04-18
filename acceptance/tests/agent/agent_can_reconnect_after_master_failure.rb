require 'securerandom'
test_name 'C97323: agents can reconnect after master crash/restart' do

  username = 'er0ck'
  teardown do
    step 'stop puppet agent' do
      on(agents, puppet_resource("service puppet ensure=stopped"))
    end
    step 'remove test user' do
      on(agent, puppet_resource("user #{username} ensure=absent"))
    end
  end

  environmentpath = master.puppet['environmentpath']
  environment     = master.puppet['environment']
  step 'create a file resource manifest for checking the puppet runs' do
    manifest = "user { '#{username}': ensure=>present }"
    apply_manifest_on(master, manifest, :catch_failures => true)
    apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
     file {'#{environmentpath}/#{environment}/manifests/site.pp':
       content => 'user { "#{username}": ensure=>present }'
     }
MANIFEST
  end

  step 'start puppet master' do
    with_puppet_running_on(master, {}) do
      agents.each do |agent|
        step 'start puppet agent daemon at rapid runinterval' do
          on(agent, puppet_resource("service puppet ensure=running"))
        end
        step "check users list for successful agent run" do
          on(agent, puppet_resource("user #{username}")).stdout do |result|
            assert_match(/#{username}/, result, 'did not find evidence of successful puppet run')
          end
        end
        step 'kill master, clear user resource' do
          on master, "service #{master['puppetservice']} stop"
          on(agent, puppet_resource("user #{username} ensure=absent"))
          sleep(10)
        end
        step 'check for lack of successful agent run' do
          on(agent, puppet_resource("user #{username}")).stdout do |result|
            refute_match(/#{username}/, result, 'found evidence of successful puppet run')
          end
        end
        step 'restart master, assert agent run' do
          on master, "service #{master['puppetservice']} start"
          on(agent, puppet_resource("user #{username}")).stdout do |result|
            assert_match(/#{username}/, result, 'did not find evidence of subsequent successful puppet run')
          end
        end
      end
    end
  end

end
