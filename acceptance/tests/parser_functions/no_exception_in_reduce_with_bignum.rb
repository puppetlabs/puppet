test_name 'C97760: Bignum in reduce() should not cause exception' do
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  tag 'audit:medium',
      'audit:unit'

  app_type = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)

  step 'On master, create site.pp with bignum' do
    create_sitepp(master, tmp_environment, <<-SITEPP)
$data = [
{
"certname"=>"xxxxxxxxx.some.domain",
"parameters"=>{
    "admin_auth_keys"=>{
        "keyname1"=>{
            "key"=>"ABCDEF",
            "options"=>["from=\\"10.0.0.0/8\\""]
        },
        "keyname2"=>{
            "key"=>"ABCDEF",
        },
        "keyname3"=>{
            "key"=>"ABCDEF",
            "options"=>["from=\\"10.0.0.0/8\\""],
            "type"=>"ssh-xxx"
        },
        "keyname4"=>{
            "key"=>"ABCDEF",
            "options"=>["from=\\"10.0.0.0/8\\""]
        }
    },
    "admin_user"=>"ertxa",
    "admin_hosts"=>["1.2.3.4",
        "1.2.3.4",
        "1.2.3.4"],
    "admin_password"=>"ABCDEF",
    "sshd_ports"=>[22,
        22, 24],
    "sudo_no_password_all"=>false,
    "sudo_no_password_commands"=>[],
    "sshd_config_template"=>"cfauth/sshd_config.epp",
    "sudo_env_keep"=>[]
},
"exported"=>false},
]
$data_reduced = $data.reduce({}) |$m, $r|{
    $cn = $r['certname']
    notice({ $cn => $r['parameters'] })
}
SITEPP
  end

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      on(agent, puppet("agent -t --environment #{tmp_environment} --server #{master.hostname}"))
    end
  end

end
