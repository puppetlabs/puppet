
require 'puppet/util/network_device/cisco'
require 'puppet/util/network_device/ipcalc'

# this retrieves facts from a cisco device
class Puppet::Util::NetworkDevice::Cisco::Facts

  attr_reader :transport

  def initialize(transport)
    @transport = transport
  end

  def retrieve
    facts = {}
    facts.merge(parse_show_ver)
  end

  def parse_show_ver
    facts = {}
    out = @transport.command("sh ver")
    lines = out.split("\n")
    lines.shift; lines.pop
    lines.each do |l|
      case l
      # cisco WS-C2924C-XL (PowerPC403GA) processor (revision 0x11) with 8192K/1024K bytes of memory.
      # Cisco 1841 (revision 5.0) with 355328K/37888K bytes of memory.
      # Cisco 877 (MPC8272) processor (revision 0x200) with 118784K/12288K bytes of memory.
      # cisco WS-C2960G-48TC-L (PowerPC405) processor (revision C0) with 61440K/4088K bytes of memory.
      # cisco WS-C2950T-24 (RC32300) processor (revision R0) with 19959K bytes of memory.
      when /[cC]isco ([\w-]+) (?:\(([\w-]+)\) processor )?\(revision (.+)\) with (\d+[KMG])(?:\/(\d+[KMG]))? bytes of memory\./
        facts[:hardwaremodel] = $1
        facts[:processor] = $2 if $2
        facts[:hardwarerevision] = $3
        facts[:memorysize] = $4
      # uptime
      # Switch uptime is 1 year, 12 weeks, 6 days, 22 hours, 32 minutes
      # c2950 uptime is 3 weeks, 1 day, 23 hours, 36 minutes
      # c2960 uptime is 2 years, 27 weeks, 5 days, 21 hours, 30 minutes
      # router uptime is 5 weeks, 1 day, 3 hours, 30 minutes
      when /^\s*([\w-]+)\s+uptime is (.*?)$/
        facts[:hostname] = $1
        facts[:uptime] = $2
        facts[:uptime_seconds] = uptime_to_seconds($2)
        facts[:uptime_days] = facts[:uptime_seconds] / 86400
      # "IOS (tm) C2900XL Software (C2900XL-C3H2S-M), Version 12.0(5)WC10, RELEASE SOFTWARE (fc1)"=> { :operatingsystem => "IOS", :operatingsystemrelease => "12.0(5)WC10", :operatingsystemmajrelease => "12.0", :operatingsystemfeature => "C3H2S"},
      # "IOS (tm) C2950 Software (C2950-I6K2L2Q4-M), Version 12.1(22)EA8a, RELEASE SOFTWARE (fc1)"=> { :operatingsystem => "IOS", :operatingsystemrelease => "12.1(22)EA8a", :operatingsystemmajrelease => "12.1", :operatingsystemfeature => "I6K2L2Q4"},
      # "Cisco IOS Software, C2960 Software (C2960-LANBASEK9-M), Version 12.2(44)SE, RELEASE SOFTWARE (fc1)"=>{ :operatingsystem => "IOS", :operatingsystemrelease => "12.2(44)SE", :operatingsystemmajrelease => "12.2", :operatingsystemfeature => "LANBASEK9"},
      # "Cisco IOS Software, C870 Software (C870-ADVIPSERVICESK9-M), Version 12.4(11)XJ4, RELEASE SOFTWARE (fc2)"=>{ :operatingsystem => "IOS", :operatingsystemrelease => "12.4(11)XJ40", :operatingsystemmajrelease => "12.4XJ", :operatingsystemfeature => "ADVIPSERVICESK9"},
      # "Cisco IOS Software, 1841 Software (C1841-ADVSECURITYK9-M), Version 12.4(24)T4, RELEASE SOFTWARE (fc2)" =>{ :operatingsystem => "IOS", :operatingsystemrelease => "12.4(24)T4", :operatingsystemmajrelease => "12.4T", :operatingsystemfeature => "ADVSECURITYK9"},
      when /(?:Cisco )?(IOS)\s*(?:\(tm\) |Software, )?(?:\w+)\s+Software\s+\(\w+-(\w+)-\w+\), Version ([0-9.()A-Za-z]+),/
        facts[:operatingsystem] = $1
        facts[:operatingsystemrelease] = $3
        facts[:operatingsystemmajrelease] = ios_major_version(facts[:operatingsystemrelease])
        facts[:operatingsystemfeature] = $2
      end
    end
    facts
  end

  def ios_major_version(version)
    version.gsub(/^(\d+)\.(\d+)\(.+\)([A-Z]+)([\da-z]+)?/, '\1.\2\3')
  end

  def uptime_to_seconds(uptime)
    captures = (uptime.match(/^(?:(\d+) years?,)?\s*(?:(\d+) weeks?,)?\s*(?:(\d+) days?,)?\s*(?:(\d+) hours?,)?\s*(\d+) minutes?$/)).captures
    captures.zip([31536000, 604800, 86400, 3600, 60]).inject(0) do |total, (x,y)|
      total + (x.nil? ? 0 : x.to_i * y)
    end
  end

end
