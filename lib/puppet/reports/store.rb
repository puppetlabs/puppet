require 'puppet'

SEPARATOR = [Regexp.escape(File::SEPARATOR.to_s), Regexp.escape(File::ALT_SEPARATOR.to_s)].join

Puppet::Reports.register_report(:store) do
  desc "Store the yaml report on disk.  Each host sends its report as a YAML dump
    and this just stores the file on disk, in the `reportdir` directory.

    These files collect quickly -- one every half hour -- so it is a good idea
    to perform some maintenance on them if you use this report (it's the only
    default report)."

  def process
    # We don't want any tracking back in the fs.  Unlikely, but there
    # you go.
    if host =~ Regexp.union(/[#{SEPARATOR}]/, /\A\.\.?\Z/)
      raise ArgumentError, "Invalid node name #{host.inspect}"
    end

    dir = File.join(Puppet[:reportdir], host)

    if ! FileTest.exists?(dir)
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
      File.open(file, "w", 0640) do |f|
        f.print to_yaml
      end
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      Puppet.warning "Could not write report for #{host} at #{file}: #{detail}"
    end

    # Only testing cares about the return value
    file
  end
end

