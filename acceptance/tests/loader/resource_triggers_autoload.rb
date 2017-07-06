test_name 'C100296: can auto-load defined types using a Resource statement' do
  tag 'risk:medium'

  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

  app_type               = File.basename(__FILE__, '.*')
  tmp_environment        = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath = "#{environmentpath}/#{tmp_environment}"

  relative_define_type_dir    = 'modules/one/manifests'
  relative_define_type_1_path = "#{relative_define_type_dir}/tst1.pp"
  relative_define_type_2_path = "#{relative_define_type_dir}/tst2.pp"
  step 'create custom type in two environments' do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/#{relative_define_type_dir}")

    define_type_1 = <<-END
    define one::tst1($var) {
      notify { "tst1: ${var}": }
    }
    END
    define_type_2 = <<-END
    define one::tst2($var) {
      notify { "tst2: ${var}": }
    }
    END
    create_remote_file(master, "#{fq_tmp_environmentpath}/#{relative_define_type_1_path}", define_type_1)
    create_remote_file(master, "#{fq_tmp_environmentpath}/#{relative_define_type_2_path}", define_type_2)

    site_pp = <<-PP
    each(['tst1', 'tst2']) |$nr| {
      Resource["one::${nr}"] { "some_title_${nr}": var => "Define found one::${nr}" }
    }
    PP
    create_sitepp(master, tmp_environment, site_pp)
  end

  on(master, "chmod -R 755 /tmp/#{tmp_environment}")

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
         :acceptable_exit_codes => 2) do |puppet_result|
        assert_match(/Notice: tst1: Define found one::tst1/, puppet_result.stdout, 'Expected to see output from define notify')
        assert_match(/Notice: tst2: Define found one::tst2/, puppet_result.stdout, 'Expected to see output from define notify')
      end
    end
  end
end
