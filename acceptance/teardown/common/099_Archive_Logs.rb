require 'date'

def file_glob(host, path)
  result = on(host, "ls #{path}", :acceptable_exit_codes => [0, 2])
  return [] if result.exit_code != 0
  return result.stdout.strip.split("\n")
end

# This test is prefixed with zzz so it will hopefully run last.
test_name 'Backup puppet logs and app data on all hosts' do
  today = Date.today().to_s
  # truncate the job name so it only has the name-y part and no parameters
  job_name = (ENV['JOB_NAME'] || 'unknown_jenkins_job')
               .sub(/[A-Z0-9_]+=.*$/, '')
               .gsub(/[\/,.]/, '_')[0..200]
  archive_name = "#{job_name}__#{ENV['BUILD_ID']}__#{today}__sut-files.tgz"
  archive_root = "SUT_#{today}"

  hosts.each do |host|
    step("Capturing log errors for #{host}") do
      case host[:platform]
      when /windows/
        # on Windows, all of the desired data (including logs) is in the data dir
        puppetlabs_data = 'C:/ProgramData/PuppetLabs'
        archive_file_from(host, puppetlabs_data, {}, archive_root, archive_name)

        # Note: Windows `ls` uses absolute paths for all matches when an absolute path is supplied.
        tempdir = 'C:/Windows/TEMP'
        file_glob(host, File.join(tempdir, 'install-puppet-*.log')).each do |install_log|
          archive_file_from(host, install_log, {}, archive_root, archive_name)
        end
        file_glob(host, File.join(tempdir, 'puppet-*-installer.log')).each do |install_log|
          archive_file_from(host, install_log, {}, archive_root, archive_name)
        end
      else
        puppetlabs_logdir = '/var/log/puppetlabs'
        grep_for_alerts = if host[:platform] =~ /solaris/
                            "egrep -i 'warn|error|fatal'"
                          elsif host[:platform] =~ /aix/
                            "grep -iE -B5 -A10 'warn|error|fatal'"
                          else
                            "grep -i -B5 -A10 'warn\\|error\\|fatal'"
                          end

        ## If there are any PL logs, try to echo all warning, error, and fatal
        ## messages from all PL logs to the job's output
        on(host, <<-GREP_FOR_ALERTS, :accept_all_exit_codes => true )
  if [ -d #{puppetlabs_logdir} ] && [ -n "$(find #{puppetlabs_logdir} -name '*.log*')" ]; then
    for log in $(find #{puppetlabs_logdir} -name '*.log*'); do
      # grep /dev/null only to get grep to print filenames, since -H is not in POSIX spec for grep
      #{grep_for_alerts} $log /dev/null;
      echo ""
    done
  fi
  GREP_FOR_ALERTS

        step("Archiving logs for #{host} into #{archive_name} (muzzling everything but :warn or higher beaker logs...)") do
          ## turn the logger off to avoid getting hundreds of lines of scp progress output
          previous_level = @logger.log_level
          @logger.log_level = :warn

          pxp_cache = '/opt/puppetlabs/pxp-agent/spool'
          puppetlabs_data = '/etc/puppetlabs'

          version_lookup_result = on(host, "cat /opt/puppetlabs/puppet/VERSION", :accept_all_exit_codes => true)

          # If we can't find a VERSION file, chances are puppet wasn't
          # installed and these paths aren't present.  Beaker's
          # archive_file_from() will fail if it can't find the file, and we
          # want to proceed...
          if version_lookup_result.exit_code == 0
            agent_version = version_lookup_result.output.strip
            archive_file_from(host, pxp_cache, {}, archive_root, archive_name) unless version_is_less(agent_version, "1.3.2")
            archive_file_from(host, puppetlabs_data, {}, archive_root, archive_name)
            archive_file_from(host, puppetlabs_logdir, {}, archive_root, archive_name)
          end

          syslog_dir = '/var/log'
          syslog_name = 'messages'
          if host[:platform] =~ /ubuntu|debian/
            syslog_name = 'syslog'
          elsif host[:platform] =~ /solaris/
            syslog_dir = '/var/adm'
            # Next few lines are for debugging POOLER-200, once that is resolved this can be removed
            @logger.log_level = previous_level
            on(host, 'egrep -i \'reboot after panic\' /var/adm/messages', :acceptable_exit_codes => [0,1,2])
            @logger.log_level = :warn
          elsif host[:platform] =~ /osx/
            syslog_name = "system.log"
          elsif host[:platform] =~ /fedora/
            on(host, "journalctl --no-pager > /var/log/messages")
          elsif host[:platform] =~ /aix/
            on(host, "alog -o -t console > /var/log/messages")
          end

          syslog_path = File.join(syslog_dir, syslog_name)
          if host.file_exist?(syslog_path)
            archive_file_from(host, syslog_path, {}, archive_root, archive_name)
          end

          ## turn the logger back on in case someone else wants to log things
          @logger.log_level = previous_level
        end
      end
    end
  end
end
