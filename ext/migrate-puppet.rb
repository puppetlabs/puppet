#!/usr/bin/env ruby

require 'tmpdir'
require 'optparse'

PUP_FILES = %w(routes.yaml hiera.yaml puppetdb.conf puppet.conf)
MCO_FILES = %w(server.cfg client.cfg)

# TODO: Finalize this list
OBSOLETE_PUP_KEYS = %w(ssldir vardir confdir rundir libdir logdir)

# read a single character from the user for y/n questions
def read_a_char()
  if $options[:yes]
    print 'y'
    'y'
  else
    begin
      system("stty raw")
      str = STDIN.getc
    ensure
      system("stty -raw")
    end
    str
  end
end

# Check if a package is installed
# TODO support deb
def pkg_is_installed?(pkg)
  system "rpm -q #{pkg} > /dev/null 2>&1"
  $?.success?
end

# TODO: unstub this and query puppet
def service_is_running?(service)
  true
end

def start_service(service)
  system "puppet resource service #{service} ensure=running"
end

def stop_service(service)
  system "puppet resource service #{service} ensure=stopped"
end

def puppet_config(field)
  `#{$options[:puppet]} agent --configprint #{field}`.strip
end

# TODO support deb
def install_pkg(name)
  system("yum -y install #{name}")
  raise "ohshit" unless $?.success?
end

def munge_conf_file(path)
  content = IO.readlines(File.join(confdir, "puppet.conf"))
  file = File.open(File.join(confdir, "puppet.conf"), 'w+')
  file.write("# Modified by puppet-agent migration script.\n")
  file.write("# Obsolete settings have been commented out.\n")
  file.write("\n")
  begin
    content.each do |line|
      yield file, line
    end
  ensure
    file.close
  end
end

#####
# Execution begins here
#####

$options = {
  :puppet => 'puppet' # when we install the AIO we'll update this to point to the new puppet binary
}
OptionParser.new do |opts|
  opts.banner = "Usage: migrate-puppet [options]"

  opts.on("-s", "--server SERVER", "New Puppetserver instance to migrate this agent to.") do |srv|
    $options[:server] = srv
  end

  opts.on("-c", "--confdir CONFDIR", "Configuration directory. Will use existing puppet's default if not specified.") do |cdir|
    $options[:confdir] = cdir
  end

  opts.on("-y", "--yes", "Continue instead of prompting.") do |yes|
    $options[:yes] = true
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!


#####
# Initial sanity checking
#####

# If puppet isn't installed, this is a pointless exercise
unless pkg_is_installed? 'puppet'
  print "Puppet is not found on this system. Nothing to do."
  exit
end

# If the user hasn't specified a 
unless $options[:server]
  print "WARNING: You have not specified a new server for this agent. It WILL NOT reconnect to a Puppet 3 / Puppetserver 1 master. The recommended upgrade procedure is to create a new Puppetserver 2 or higher instance and migrate agents to the new master. If you intend to upgrade your existing master, or have done so already, you may procede at your own risk.\n\nContinue? y/n: "
  action = read_a_char.downcase
  puts '' # Add the newline that's missing from our raw input
  exit if action != 'y'
end

migrate_mco = pkg_is_installed? 'mcollective'

workdir = Dir.mktmpdir
begin
  # Cache service states so we can make sure we match when we're done
  start_pup = service_is_running? 'puppet'
  if migrate_mco
    start_mco = service_is_running? 'mcollective'
  end

  old_ssldir = puppet_config 'ssldir'
  confdir = $options[:confdir] || puppet_config('confdir')

  if File.exists? old_ssldir
    FileUtils.cp_r(old_ssldir, File.join(workdir, "ssl"), :preserve => true)
  end
    
  PUP_FILES.each do |f|
    path = File.join(confdir, f)
    if File.exists? path
      FileUtils.cp(path, workdir, :preserve => true)
    end
  end

  if migrate_mco
    MCO_FILES.each do |f|
      path = File.join("/etc/mcollective", f)
      if File.exists? path
        FileUtils.cp(File.join("/etc/mcollective", f), workdir, :preserve => true)
      end
    end
  end

  # We create the backup dir early to avoid losing the files if
  # uninstall of old packages succeeds but install of new agent fails.
  FileUtils.mkdir_p('/etc/puppetlabs/backup')
  [PUP_FILES, MCO_FILES].flatten.each do |f|
    path = File.join(workdir, f)
    if File.exists? path
      FileUtils.cp(path, '/etc/puppetlabs/backup', :preserve => true)
    end
  end

  install_pkg 'puppet-agent'

  puts "SETTING UP DIRECTORIES"
  $options[:puppet] = '/opt/puppetlabs/agent/bin/puppet'
  confdir = puppet_config 'confdir' # refresh the confdir for the new agent

  puts "STOPPING SERVICES"
  # ensure services are stopped so we can reconfigure them. If either
  # service was running when we started this process, we will start it
  # again when is all done.
  stop_service 'puppet'
  if migrate_mco
    stop_service 'mcollective'
  end

  puts "COPYING PUP FILES OVER"
  PUP_FILES.each do |f|
    path = File.join(workdir, f)
    if File.exists? path
      FileUtils.cp(path, confdir, :preserve => true)
    end
  end

  puts "COPYING MCO FILES OVER"
  MCO_FILES.each do |f|
    path = File.join(workdir, f)
    if File.exists? path
      FileUtils.cp(path, '/etc/puppetlabs/agent/mcollective', :preserve => true)
    end
  end

  munge_conf_file(File.join(confdir, "puppet.conf")) do |file, line|
    key = line.split('=').first.strip
    if OBSOLETE_PUP_KEYS.include? key
      line = "# #{line}"
    end
    file.write(line)
  end

  if $options[:server]
    system("puppet config set server #{$options[:server]} --section agent")
  end
  
  if migrate_mco
    munge_conf_file('/etc/puppetlabs/agent/mcollective/server.cfg') do |file, line|
      key = line.split('=').first.strip
      if key == 'logdir'
        line = "# #{line}"
      end
      if key == 'plugin.yaml'
        line =~ /(\s*\S+\s*=\s*)(\S+)(\s*)/
        line = "#{$1}/etc/puppetlabs/agent/mcollective/facts.yaml#{$3}"
      end
      if key == 'libdir'
        line =~ /(\s*\S+\s*=\s*)(\S+)(\s*)/
        line = "#{$1}/opt/puppetlabs/mcollective/plugins:#{$2}#{$3}"
      end
      file.write(line)
    end
  end

  new_ssldir = puppet_config 'ssldir'
  FileUtils.remove_entry_secure new_ssldir
  FileUtils.mv File.join(workdir, 'ssl'), new_ssldir


  start_service 'puppet' if start_pup
  start_service 'mcollective' if start_mco
  FileUtils.remove_entry_secure old_ssldir
ensure
  FileUtils.remove_entry_secure workdir
end
