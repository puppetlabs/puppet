test_name 'ca_key created by puppet generate should not be world readable' do
require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils

  confine :to, :roles => 'master'

  backupdir = master.tmpdir('ssl')

  teardown do
    on(master, "cp -a #{backupdir} #{master.puppet[:ssldir]}", :acceptable_exit_codes => (0..254))
  end

  #------- SETUP -------#
  step '(setup) backup ssl files'
  on(master, "cp -a  #{master.puppet[:ssldir]} #{backupdir}")

  step '(setup) destroy ssldir'
  on(master, "rm -fr #{master.puppet[:ssldir]} #{backupdir}")

  #------- TESTS -------#
  step 'generate ca cert and validate that its mode is 640'
  on(master, puppet('cert', 'generate', 'foo'))
  perms = stat(master, "#{master.puppet[:ssldir]}/ca/ca_key.pem")
  assert_equal('640', perms[2].to_s(8))

end
