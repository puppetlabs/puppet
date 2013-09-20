module Puppet
  module Acceptance
    module CronUtils
      def clean(agent, o={})
        o = {:user => 'tstuser'}.merge(o)
        run_cron_on(agent, :remove, o[:user])
        apply_manifest_on(agent, %[user { '%s': ensure => absent, managehome => false }] % o[:user])
      end

      def setup(agent, o={})
        o = {:user => 'tstuser'}.merge(o)
        apply_manifest_on(agent, %[user { '%s': ensure => present, managehome => false }] % o[:user])
        apply_manifest_on(agent, %[case $operatingsystem {
                                     centos, redhat: {$cron = 'cronie'}
                                     solaris: { $cron = 'core-os' }
                                     default: {$cron ='cron'} }
                                     package {'cron': name=> $cron, ensure=>present, }])
      end
    end
  end
end
