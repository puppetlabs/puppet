require 'puppet'
require 'puppet/application'
require 'puppet/file_bucket/dipper'

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

  def setup
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    raise "Inspect requires reporting to be enabled. Set report=true in puppet.conf to enable reporting." unless Puppet[:report]

    @report = Puppet::Transaction::Report.new("inspect")

    Puppet::Util::Log.newdestination(@report)
    Puppet::Util::Log.newdestination(:console) unless options[:logset]

    trap(:INT) do
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

  def run_command
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
