test_name "Use environments from the environmentdir"

testdir = master.tmpdir('use_environmentdir')

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner => puppet,
  mode => 0700,
}

file {
  "#{testdir}":;
  "#{testdir}/environments":;
  "#{testdir}/environments/special":;
  "#{testdir}/environments/special/manifests":;
  "#{testdir}/environments/special/modules":;
  "#{testdir}/environments/special/modules/amod":;
  "#{testdir}/environments/special/modules/amod/manifests":;
  "#{testdir}/environments/special/modules/amod/files":;
  "#{testdir}/environments/special/modules/amod/templates":;
  "#{testdir}/environments/special/modules/amod/lib":;
  "#{testdir}/environments/special/modules/amod/lib/facter":;

  "#{testdir}/environments/special/modules/amod/manifests/init.pp":
    ensure => file,
    content => 'class amod {
      notify { template: message => template("amod/our_template.erb") }
      file { "$agent_file_location/file": source => "puppet:///modules/amod/data" }
    }'
  ;
  "#{testdir}/environments/special/modules/amod/lib/facter/environment_fact.rb":
    ensure => file,
    content => "Facter.add(:environment_fact) { setcode { 'environment fact' } }"
  ;
  "#{testdir}/environments/special/modules/amod/files/data":
    ensure => file,
    content => "data file"
  ;
  "#{testdir}/environments/special/modules/amod/templates/our_template.erb":
    ensure => file,
    content => "<%= @environment_fact %>"
  ;
  "#{testdir}/environments/special/manifests/site.pp":
    ensure => file,
    content => "include amod"
  ;
}
MANIFEST

master_opts = {
  'master' => {
    'environmentdir' => "#{testdir}/environments"
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    atmp = agent.tmpdir('use_environmentdir')
    on agent, puppet("agent",
                     "--environment", "special",
                     "-t",
                     "--server", master,
                     "--trace",
                     'ENV' => { "FACTER_agent_file_location" => atmp }),
       :acceptable_exit_codes => [2] do |result|
      assert_match(/environment fact/, result.stdout)
    end

    on agent, "cat #{atmp}/file" do |result|
      assert_match(/data file/, result.stdout)
    end

    on agent, "rm -rf #{atmp}"
  end
end
