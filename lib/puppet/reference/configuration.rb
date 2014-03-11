config = Puppet::Util::Reference.newreference(:configuration, :depth => 1, :doc => "A reference for all settings") do
  docs = {}
  Puppet.settings.each do |name, object|
    docs[name] = object
  end

  str = ""
  docs.sort { |a, b|
    a[0].to_s <=> b[0].to_s
  }.each do |name, object|
    # Make each name an anchor
    header = name.to_s
    str << markdown_header(header, 3)

    # Print the doc string itself
    begin
      str << Puppet::Util::Docs.scrub(object.desc)
    rescue => detail
      Puppet.log_exception(detail)
    end
    str << "\n\n"

    # Now print the data about the item.
    val = object.default
    if name.to_s == "vardir"
      val = "/var/lib/puppet"
    elsif name.to_s == "confdir"
      val = "/etc/puppet"
    end

    # Leave out the section information; it was apparently confusing people.
    #str << "- **Section**: #{object.section}\n"
    unless val == ""
      str << "- *Default*: #{val}\n"
    end
    str << "\n"
  end

  return str
end

config.header = <<EOT
## Configuration Settings

* Each of these settings can be specified in `puppet.conf` or on the
  command line.
* When using boolean settings on the command line, use `--setting` and
  `--no-setting` instead of `--setting (true|false)`.
* Settings can be interpolated as `$variables` in other settings; `$environment`
  is special, in that puppet master will interpolate each agent node's
  environment instead of its own.
* Multiple values should be specified as comma-separated lists; multiple
  directories should be separated with the system path separator (usually
  a colon).
* Settings that represent time intervals should be specified in duration format:
  an integer immediately followed by one of the units 'y' (years of 365 days),
  'd' (days), 'h' (hours), 'm' (minutes), or 's' (seconds). The unit cannot be
  combined with other units, and defaults to seconds when omitted. Examples are
  '3600' which is equivalent to '1h' (one hour), and '1825d' which is equivalent
  to '5y' (5 years).
* Settings that take a single file or directory can optionally set the owner,
  group, and mode for their value: `rundir = $vardir/run { owner = puppet,
  group = puppet, mode = 644 }`
* The Puppet executables will ignore any setting that isn't relevant to
  their function.

See the [configuration guide][confguide] for more details.

[confguide]: http://docs.puppetlabs.com/guides/configuring.html

* * *

EOT
