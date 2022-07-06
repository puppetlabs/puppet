test_name "agent run should fail if it finds an unknown resource type" do
  tag 'audit:high',
      'audit:integration'

  require 'puppet/acceptance/common_utils'

  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  step "agent should fail when it can't find a resource" do
    vendor_modules_path = master.tmpdir('vendor_modules')
    tmp_environment = mk_tmp_environment_with_teardown(master, 'tmp')

    site_pp_content = <<-SITEPP
      define foocreateresource($one) {
        $msg = 'hello'
        notify { $name: message => $msg }
      }
      class example($x) {
        if $x == undef or $x == [] or $x == '' {
          notice 'foo'
          return()
        }
        notice 'bar'
      }
      node default {
        class { example: x => [] }
        create_resources('foocreateresource', {'blah'=>{'one'=>'two'}})
        mycustomtype{'foobar':}
      }
    SITEPP
    manifests_path = "/tmp/#{tmp_environment}/manifests"
    on(master, "mkdir -p '#{manifests_path}'")
    create_remote_file(master, "#{manifests_path}/site.pp", site_pp_content)

    custom_type_content = <<-CUSTOMTYPE
      Puppet::Type.newtype(:mycustomtype) do
        @doc = "Create a new mycustomtype thing."

        newparam(:name, :namevar => true) do
          desc "Name of mycustomtype instance"
        end

        def refresh
        end
      end
    CUSTOMTYPE
    type_path = "#{vendor_modules_path}/foo/lib/puppet/type"
    on(master, "mkdir -p '#{type_path}'")
    create_remote_file(master, "#{type_path}/mycustomtype.rb", custom_type_content)

    on(master, "chmod -R 750 '#{vendor_modules_path}' '/tmp/#{tmp_environment}'")
    on(master, "chown -R #{master.puppet['user']}:#{master.puppet['group']} '#{vendor_modules_path}' '/tmp/#{tmp_environment}'")

    master_opts = {
      'main' => {
        'environment' => tmp_environment,
        'vendormoduledir' => vendor_modules_path
       }
    }

    with_puppet_running_on(master, master_opts) do
      agents.each do |agent|
        teardown do
          agent.rm_rf(vendor_modules_path)
        end

        on(agent, puppet('agent', '-t', '--environment', tmp_environment), acceptable_exit_codes: [1]) do |result|  
          assert_match(/Error: Failed to apply catalog: Resource type 'Mycustomtype' was not found/, result.stderr)
        end
      end
    end
  end
end
