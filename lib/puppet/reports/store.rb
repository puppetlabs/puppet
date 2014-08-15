require 'puppet'
require 'fileutils'
require 'puppet/util'

SEPARATOR = [Regexp.escape(File::SEPARATOR.to_s), Regexp.escape(File::ALT_SEPARATOR.to_s)].join

Puppet::Reports.register_report(:store) do
  desc "Store the yaml report on disk.  Each host sends its report as a YAML dump
    and this just stores the file on disk, in the `reportdir` directory.

    These files collect quickly -- one every half hour -- so it is a good idea
    to perform some maintenance on them if you use this report (it's the only
    default report)."

  def process
    validate_host(host)

    dir = File.join(Puppet[:reportdir], host)

    if ! Puppet::FileSystem.exist?(dir)
      FileUtils.mkdir_p(dir)
      FileUtils.chmod_R(0750, dir)
    end

    # Now store the report.
    now = Time.now.gmtime
    name = %w{year month day hour min}.collect do |method|
      # Make sure we're at least two digits everywhere
      "%02d" % now.send(method).to_s
    end.join("") + ".yaml"

    file = File.join(dir, name)

    begin
      Puppet::Util.replace_file(file, 0640) do |fh|
        fh.print to_yaml
      end
    rescue => detail
       Puppet.log_exception(detail, "Could not write report for #{host} at #{file}: #{detail}")
    end

    # Only testing cares about the return value
    file
  end

  # removes all reports for a given host?
  def self.destroy(host)
    validate_host(host)

    dir = File.join(Puppet[:reportdir], host)

    if Puppet::FileSystem.exist?(dir)
      Dir.entries(dir).each do |file|
        next if ['.','..'].include?(file)
        file = File.join(dir, file)
        Puppet::FileSystem.unlink(file) if File.file?(file)
      end
      Dir.rmdir(dir)
    end
  end

  def validate_host(host)
    if host =~ Regexp.union(/[#{SEPARATOR}]/, /\A\.\.?\Z/)
      raise ArgumentError, "Invalid node name #{host.inspect}"
    end
  end
  module_function :validate_host
end
