test_name "Commandline modulepath and manifest settings override environment"

testdir = master.tmpdir('cmdline_and_environment')
environmentpath = "#{testdir}/environments"
modulepath = "#{testdir}/modules"
manifests = "#{testdir}/manifests"
sitepp = "#{manifests}/site.pp"
other_manifestdir = "#{testdir}/other_manifests"
other_sitepp = "#{other_manifestdir}/site.pp"
other_modulepath = "#{testdir}/some_other_modulepath"
cmdline_manifest = "#{testdir}/cmdline.pp"

step "Prepare manifests and modules"
apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner => puppet,
  mode => 0700,
}

##############################################
# The default production directory environment
file {
  "#{testdir}":;
  "#{environmentpath}":;
  "#{environmentpath}/production":;
  "#{environmentpath}/production/manifests":;
  "#{environmentpath}/production/modules":;
  "#{environmentpath}/production/modules/amod":;
  "#{environmentpath}/production/modules/amod/manifests":;
}

file { "#{environmentpath}/production/modules/amod/manifests/init.pp":
  ensure => file,
  content => 'class amod {
    notify { "amod from production environment": }
  }'
}

file { "#{environmentpath}/production/manifests/production.pp":
  ensure => file,
  content => '
    notify { "in production.pp": }
    include amod
  '
}

##############################################################
# To be set as default manifests and modulepath in puppet.conf
file {
  "#{modulepath}":;
  "#{modulepath}/amod/":;
  "#{modulepath}/amod/manifests":;
}

file { "#{modulepath}/amod/manifests/init.pp":
  ensure => file,
  content => 'class amod {
    notify { "amod from modulepath": }
  }'
}

file { "#{manifests}": }
file { "#{sitepp}":
  ensure => file,
  content => '
    notify { "in site.pp": }
    include amod
  '
}

file { "#{other_manifestdir}": }
file { "#{other_sitepp}":
  ensure => file,
  content => '
    notify { "in other manifestdir site.pp": }
    include amod
  '
}

################################
# To be specified on commandline
file {
  "#{other_modulepath}":;
  "#{other_modulepath}/amod/":;
  "#{other_modulepath}/amod/manifests":;
}

file { "#{other_modulepath}/amod/manifests/init.pp":
  ensure => file,
  content => 'class amod {
    notify { "amod from commandline modulepath": }
  }'
}

file { "#{cmdline_manifest}":
  ensure => file,
  content => '
    notify { "in cmdline.pp": }
    include amod
  '
}
MANIFEST

master_opts = {
  'master' => {
    'environmentpath' => environmentpath,
    'manifest' => sitepp,
    'modulepath' => modulepath,
  }
}

# Note: this is the semantics seen with legacy environments if commandline
# manifest/modulepath are set.
step "puppet master with --manifest and --modulepath overrides existing default production directory environment" do
  master_opts = master_opts.merge(:__commandline_args__ => "--manifest=#{cmdline_manifest} --modulepath=#{other_modulepath}")
  with_puppet_running_on master, master_opts, testdir do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2] ) do
        assert_match(/in cmdline\.pp/, stdout)
        assert_match(/amod from commandline modulepath/, stdout)
        assert_not_match(/production/, stdout)
      end

      step "even if environment is specified"
      on(agent, puppet("agent -t --server #{master} --environment production"), :acceptable_exit_codes => [2]) do
        assert_match(/in cmdline\.pp/, stdout)
        assert_match(/amod from commandline modulepath/, stdout)
        assert_not_match(/production/, stdout)
      end
    end
  end

  step "or if you set --manifestdir" do
    master_opts = master_opts.merge(:__commandline_args__ => "--manifestdir=#{other_manifestdir} --modulepath=#{other_modulepath}")
    step "it is ignored if manifest is set in puppet.conf to something not using $manifestdir"
    with_puppet_running_on master, master_opts, testdir do
      agents.each do |agent|
        on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2]) do
          assert_match(/in production\.pp/, stdout)
          assert_match(/amod from commandline modulepath/, stdout)
        end
      end
    end

    step "but does pull in the default manifest via manifestdir if manifest is not set"
    master_opts = master_opts.merge(:__commandline_args__ => "--manifestdir=#{other_manifestdir} --modulepath=#{other_modulepath}")
    master_opts['master'].delete('manifest')
    with_puppet_running_on master, master_opts, testdir do
      agents.each do |agent|
        on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2]) do
          assert_match(/in other manifestdir site\.pp/, stdout)
          assert_match(/amod from commandline modulepath/, stdout)
          assert_not_match(/production/, stdout)
        end
      end
    end
  end
end

step "puppet master with manifest and modulepath set in puppet.conf is overriden by an existing default production directory" do
  with_puppet_running_on master, master_opts, testdir do
    agents.each do |agent|
      step "this case is unfortunate, but will be irrelevant when we remove legacyenv in 4.0"
      on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2] ) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
      end

      step "if environment is specified"
      on(agent, puppet("agent -t --server #{master} --environment production"), :acceptable_exit_codes => [2]) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
      end
    end
  end
end

step "puppet master with default manifest, modulepath, environment, environmentpath and an existing default production directory environment directory" do
  master_opts = {
    :__commandline_args__ => "--confdir=#{testdir} --ssldir=#{master[:puppetpath]}/ssl"
  }
  with_puppet_running_on master, master_opts, testdir do
    agents.each do |agent|
      step "default production directory environment takes precedence"
      on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2] ) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
      end
      on(agent, puppet("agent -t --server #{master} --environment production"), :acceptable_exit_codes => [2]) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
      end
    end
  end
end
