require 'puppet/application'

class Puppet::Application::Inspect < Puppet::Application

  run_mode :agent

  option("--debug","-d")
  option("--verbose","-v")

  option("--logdest LOGDEST", "-l") do |arg|
    handle_logdest_arg(arg)
  end

  def help
    <<-'HELP'

puppet-inspect(8) -- Send an inspection report
========

SYNOPSIS
--------

Prepares and submits an inspection report to the puppet master.


USAGE
-----
puppet inspect [--archive_files] [--archive_file_server]


DESCRIPTION
-----------

This command uses the cached catalog from the previous run of 'puppet
agent' to determine which attributes of which resources have been
marked as auditable with the 'audit' metaparameter. It then examines
the current state of the system, writes the state of the specified
resource attributes to a report, and submits the report to the puppet
master.

Puppet inspect does not run as a daemon, and must be run manually or
from cron.


OPTIONS
-------

Any configuration setting which is valid in the configuration file is
also a valid long argument, e.g. '--server=master.domain.com'. See the
configuration file documentation at
https://docs.puppetlabs.com/puppet/latest/reference/configuration.html for
the full list of acceptable settings.

* --archive_files:
  During an inspect run, whether to archive files whose contents are audited to
  a file bucket.

* --archive_file_server:
  During an inspect run, the file bucket server to archive files to if
  archive_files is set.  The default value is '$server'.


AUTHOR
------

Puppet Labs


COPYRIGHT
---------
Copyright (c) 2011 Puppet Labs, LLC Licensed under the Apache 2.0 License

    HELP
  end

  def setup
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    raise "Inspect requires reporting to be enabled. Set report=true in puppet.conf to enable reporting." unless Puppet[:report]

    @report = Puppet::Transaction::Report.new("inspect")

    Puppet::Util::Log.newdestination(@report)
    Puppet::Util::Log.newdestination(:console) unless options[:setdest]

    Signal.trap(:INT) do
      $stderr.puts "Exiting"
      exit(1)
    end

    set_log_level

    Puppet::Transaction::Report.indirection.terminus_class = :rest
    Puppet::Resource::Catalog.indirection.terminus_class = Puppet[:catalog_cache_terminus] || :json
  end

  def preinit
    require 'puppet'
    require 'puppet/file_bucket/dipper'
  end

  def run_command
    benchmark(:notice, "Finished inspection") do
      retrieval_starttime = Time.now

      unless catalog = Puppet::Resource::Catalog.indirection.find(Puppet[:certname])
        raise "Could not find catalog for #{Puppet[:certname]}"
      end

      @report.configuration_version = catalog.version
      @report.environment = Puppet[:environment]

      inspect_starttime = Time.now
      @report.add_times("config_retrieval", inspect_starttime - retrieval_starttime)

      if Puppet[:archive_files]
        dipper = Puppet::FileBucket::Dipper.new(:Server => Puppet[:archive_file_server])
      end

      catalog.to_ral.resources.each do |ral_resource|
        audited_attributes = ral_resource[:audit]
        next unless audited_attributes

        status = Puppet::Resource::Status.new(ral_resource)

        begin
          audited_resource = ral_resource.to_resource
        rescue StandardError => detail
          ral_resource.log_exception(detail, "Could not inspect #{ral_resource}; skipping: #{detail}")
          audited_attributes.each do |name|
            event = ral_resource.event(
                                       :property => name,
                                       :status   => "failure",
                                       :audited  => true,
                                       :message  => "failed to inspect #{name}"
                                       )
            status.add_event(event)
          end
        else
          audited_attributes.each do |name|
            next if audited_resource[name].nil?
            # Skip :absent properties of :absent resources. Really, it would be nicer if the RAL returned nil for those, but it doesn't. ~JW
            if name == :ensure or audited_resource[:ensure] != :absent or audited_resource[name] != :absent
              event = ral_resource.event(
                                         :previous_value => audited_resource[name],
                                         :property       => name,
                                         :status         => "audit",
                                         :audited        => true,
                                         :message        => "inspected value is #{audited_resource[name].inspect}"
                                         )
              status.add_event(event)
            end
          end
        end
        if Puppet[:archive_files] and ral_resource.type == :file and audited_attributes.include?(:content)
          path = ral_resource[:path]
          if ::File.readable?(path)
            begin
              dipper.backup(path)
            rescue StandardError => detail
              Puppet.warning detail
            end
          end
        end
        @report.add_resource_status(status)
      end

      finishtime = Time.now
      @report.add_times("inspect", finishtime - inspect_starttime)
      @report.finalize_report

      begin
        Puppet::Transaction::Report.indirection.save(@report)
      rescue => detail
        Puppet.log_exception(detail, "Could not send report: #{detail}")
      end
    end
  end
end
