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
  owner => #{master['user']},
  group => #{master['group']},
  mode => 0750,
}

##############################################
# A production directory environment
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
  mode => 0640,
  content => 'class amod {
    notify { "amod from production environment": }
  }'
}

file { "#{environmentpath}/production/manifests/production.pp":
  ensure => file,
  mode => 0640,
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
  mode => 0640,
  content => 'class amod {
    notify { "amod from modulepath": }
  }'
}

file { "#{manifests}": }
file { "#{sitepp}":
  ensure => file,
  mode => 0640,
  content => '
    notify { "in site.pp": }
    include amod
  '
}

file { "#{other_manifestdir}": }
file { "#{other_sitepp}":
  ensure => file,
  mode => 0640,
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
  mode => 0640,
  content => 'class amod {
    notify { "amod from commandline modulepath": }
  }'
}

file { "#{cmdline_manifest}":
  ensure => file,
  mode => 0640,
  content => '
    notify { "in cmdline.pp": }
    include amod
  '
}
MANIFEST

# Note: this is the semantics seen with legacy environments if commandline
# manifest/modulepath are set.
step "CASE 1: puppet master with --manifest and --modulepath overrides set production directory environment" do
  if master.is_pe?
    step "Skipping for Passenger (PE) setup; since the equivalent of a commandline override would be adding the setting to config.ru, which seems like a very odd thing to do."
  else
    master_opts = {
      'master' => {
        'environmentpath' => environmentpath,
        'manifest' => sitepp,
        'modulepath' => modulepath,
      }
    }

    master_opts_with_cmdline = master_opts.merge(:__commandline_args__ => "--manifest=#{cmdline_manifest} --modulepath=#{other_modulepath}")
    with_puppet_running_on master, master_opts_with_cmdline, testdir do
      agents.each do |agent|
        on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2] ) do
          assert_match(/in cmdline\.pp/, stdout)
          assert_match(/amod from commandline modulepath/, stdout)
          assert_no_match(/production/, stdout)
        end

        step "CASE 1a: even if environment is specified"
        on(agent, puppet("agent -t --server #{master} --environment production"), :acceptable_exit_codes => [2]) do
          assert_match(/in cmdline\.pp/, stdout)
          assert_match(/amod from commandline modulepath/, stdout)
          assert_no_match(/production/, stdout)
        end
      end
    end

    step "CASE 2: or if you set --manifestdir" do
      master_opts_with_cmdline = master_opts.merge(:__commandline_args__ => "--manifestdir=#{other_manifestdir} --modulepath=#{other_modulepath}")
      step "CASE 2: it is ignored if manifest is set in puppet.conf to something not using $manifestdir"
      with_puppet_running_on master, master_opts_with_cmdline, testdir do
        agents.each do |agent|
          on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2]) do
            assert_match(/in production\.pp/, stdout)
            assert_match(/amod from commandline modulepath/, stdout)
          end
        end
      end

      step "CASE 2a: but does pull in the default manifest via manifestdir if manifest is not set"
      master_opts_with_cmdline = master_opts.merge(:__commandline_args__ => "--manifestdir=#{other_manifestdir} --modulepath=#{other_modulepath}")
      master_opts_with_cmdline['master'].delete('manifest')
      with_puppet_running_on master, master_opts_with_cmdline, testdir do
        agents.each do |agent|
          on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2]) do
            assert_match(/in other manifestdir site\.pp/, stdout)
            assert_match(/amod from commandline modulepath/, stdout)
            assert_no_match(/production/, stdout)
          end
        end
      end
    end
  end
end

step "CASE 3: puppet master with manifest and modulepath set in puppet.conf is overriden by an existing and set production directory environment" do
  master_opts = {
    'master' => {
      'environmentpath' => environmentpath,
      'manifest' => sitepp,
      'modulepath' => modulepath,
    }
  }
  if master.is_pe?
    master_opts['master']['basemodulepath'] = master['sitemoduledir']
  end

  with_puppet_running_on master, master_opts, testdir do
    agents.each do |agent|
      step "CASE 3: this case is unfortunate, but will be irrelevant when we remove legacyenv in 4.0"
      on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2] ) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
      end

      step "CASE 3a: if environment is specified"
      on(agent, puppet("agent -t --server #{master} --environment production"), :acceptable_exit_codes => [2]) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
      end
    end
  end
end

step "CASE 4: puppet master with default manifest, modulepath, environment, environmentpath and an existing '#{environmentpath}/production' directory environment that has not been set" do

  if master.is_pe?
    step "Skipping for PE because PE requires most of the existing puppet.conf and /etc/puppetlabs/puppet configuration, and we cannot simply point to a new conf directory."
  else
    ssldir = on(master, puppet("master --configprint ssldir")).stdout.chomp
    master_opts = {
      :__commandline_args__ => "--confdir=#{testdir} --ssldir=#{ssldir}"
    }

    with_puppet_running_on master, master_opts, testdir do
      agents.each do |agent|
        step "CASE 4: #{environmentpath}/production directory environment does not take precedence because default environmentpath is ''"
        on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2] ) do
          assert_match(/in site\.pp/, stdout)
          assert_match(/amod from modulepath/, stdout)
        end
        on(agent, puppet("agent -t --server #{master} --environment production"), :acceptable_exit_codes => [2]) do
          assert_match(/in site\.pp/, stdout)
          assert_match(/amod from modulepath/, stdout)
        end
      end
    end
  end
end

step "CASE 5: puppet master with explicit dynamic environment settings and empty environmentpath" do
  step "CASE 5: Prepare an additional modulepath module"
  apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    owner => #{master['user']},
    group => #{master['group']},
    mode => 0750,
  }

  # A second module in another modules dir
  file {
    "#{other_modulepath}":;
    "#{other_modulepath}/bmod/":;
    "#{other_modulepath}/bmod/manifests":;
  }

  file { "#{other_modulepath}/bmod/manifests/init.pp":
    ensure => file,
    mode => 0640,
    content => 'class bmod {
      notify { "bmod from other modulepath": }
    }'
  }

  file { "#{environmentpath}/production/manifests/production.pp":
    ensure => file,
    mode => 0640,
    content => '
      notify { "in production.pp": }
      include amod
      include bmod
    '
  }
  MANIFEST

  master_opts = {
    'master' => {
      'manifest' => "#{environmentpath}/$environment/manifests",
      'modulepath' => "#{environmentpath}/$environment/modules:#{other_modulepath}",
    }
  }
  if master.is_pe?
    master_opts['master']['modulepath'] << ":#{master['sitemoduledir']}"
  end

  with_puppet_running_on master, master_opts, testdir do
    agents.each do |agent|
      step "CASE 5: pulls in the production environment based on $environment default"
      on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [2] ) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
        step "CASE 5: and sees modules located in later elements of the modulepath (which would not be seen by a directory env (PUP-2158)"
        assert_match(/bmod from other modulepath/, stdout)
      end

      step "CASE 5a: pulls in the production environment when explicitly set"
      on(agent, puppet("agent -t --server #{master} --environment production"), :acceptable_exit_codes => [2] ) do
        assert_match(/in production\.pp/, stdout)
        assert_match(/amod from production environment/, stdout)
        step "CASE 5a: and sees modules located in later elements of the modulepath (which would not be seen by a directory env (PUP-2158)"
        assert_match(/bmod from other modulepath/, stdout)
      end
    end
  end
end
