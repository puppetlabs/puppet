require 'puppet/application'

class Puppet::Application::Inspect < Puppet::Application

  should_parse_config
  run_mode :agent

  option("--debug","-d")
  option("--verbose","-v")

  option("--logdest LOGDEST", "-l") do |arg|
    begin
      Puppet::Util::Log.newdestination(arg)
      options[:logset] = true
    rescue => detail
      $stderr.puts detail.to_s
    end
  end

  def help
    <<-HELP

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
http://docs.puppetlabs.com/references/latest/configuration.html for
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
    Puppet::Util::Log.newdestination(:console) unless options[:logset]

    Signal.trap(:INT) do
      $stderr.puts "Exiting"
      exit(1)
    end

    if options[:debug]
      Puppet::Util::Log.level = :debug
    elsif options[:verbose]
      Puppet::Util::Log.level = :info
    end

    Puppet::Transaction::Report.indirection.terminus_class = :rest
    Puppet::Resource::Catalog.indirection.terminus_class = :yaml
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
          puts detail.backtrace if Puppet[:trace]
          ral_resource.err "Could not inspect #{ral_resource}; skipping: #{detail}"
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
          if File.readable?(path)
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
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Could not send report: #{detail}"
      end
    end
  end
end
