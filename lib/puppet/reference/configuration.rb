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
    if name.to_s == 'vardir'
      val = 'Unix/Linux: /opt/puppetlabs/puppet/cache -- Windows: C:\ProgramData\PuppetLabs\puppet\cache -- Non-root user: ~/.puppetlabs/opt/puppet/cache'
    elsif name.to_s == 'confdir'
      val = 'Unix/Linux: /etc/puppetlabs/puppet -- Windows: C:\ProgramData\PuppetLabs\puppet\etc -- Non-root user: ~/.puppetlabs/etc/puppet'
    elsif name.to_s == 'codedir'
      val = 'Unix/Linux: /etc/puppetlabs/code -- Windows: C:\ProgramData\PuppetLabs\code -- Non-root user: ~/.puppetlabs/etc/code'
    elsif name.to_s == 'rundir'
      val = 'Unix/Linux: /var/run/puppetlabs -- Windows: C:\ProgramData\PuppetLabs\puppet\var\run -- Non-root user: ~/.puppetlabs/var/run'
    elsif name.to_s == 'logdir'
      val = 'Unix/Linux: /var/log/puppetlabs/puppet -- Windows: C:\ProgramData\PuppetLabs\puppet\var\log -- Non-root user: ~/.puppetlabs/var/log'
    elsif name.to_s == 'hiera_config'
      val = '$confdir/hiera.yaml. However, if a file exists at $codedir/hiera.yaml, Puppet uses that instead.'
    elsif name.to_s == 'certname'
      val = "the Host's fully qualified domain name, as determined by facter"
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
## Configuration settings

* Each of these settings can be specified in `puppet.conf` or on the
  command line.
* When using boolean settings on the command line, use `--setting` and
  `--no-setting` instead of `--setting (true|false)`. (Using `--setting false`
  results in "Error: Could not parse application options: needless argument".)
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
* If you use the `splay` setting, note that the period that it waits changes
  each time the Puppet agent is restarted.
* Settings that take a single file or directory can optionally set the owner,
  group, and mode for their value: `rundir = $vardir/run { owner = puppet,
  group = puppet, mode = 644 }`
* The Puppet executables will ignore any setting that isn't relevant to
  their function.

See the [configuration guide][confguide] for more details.

[confguide]: https://puppet.com/docs/puppet/latest/config_about_settings.html

* * *

EOT
