#!/usr/bin/env ruby

# Script to clean up stored configs for (a) given host(s)
#
# Credits:
# Script was taken from http://reductivelabs.com/trac/puppet/attachment/wiki/UsingStoredConfiguration/kill_node_in_storedconfigs_db.rb (link no longer valid),
# which haven been initially posted by James Turnbull
# duritong adapted and improved the script a bit.

require 'getoptlong'
require 'puppet'
require 'puppet/rails'

config = Puppet[:config]

def printusage(error_code)
  puts "Usage: #{$0} [ list of hostnames as stored in hosts table ]"
  puts "\n Options:"
  puts "--config <puppet config file>"
  exit(error_code)
end

opts = GetoptLong.new(
  [ "--config",  "-c", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--help",    "-h", GetoptLong::NO_ARGUMENT ],
  [ "--usage",   "-u", GetoptLong::NO_ARGUMENT ],
  [ "--version", "-v", GetoptLong::NO_ARGUMENT ]
)

begin
  opts.each do |opt, arg|
    case opt
    when "--config"
      config = arg

    when "--help"
      printusage(0)

    when "--usage"
      printusage(0)

    when "--version"
      puts "#{Puppet.version}"
      exit
    end
  end
rescue GetoptLong::InvalidOption => detail
  $stderr.puts "Try '#{$0} --help'"
  exit(1)
end

printusage(1) unless ARGV.size > 0

if config != Puppet[:config]
  Puppet[:config]=config
  Puppet.settings.parse
end

master = Puppet.settings.instance_variable_get(:@values)[:master]
main = Puppet.settings.instance_variable_get(:@values)[:main]
db_config = main.merge(master)

# get default values
[:master, :main, :rails].each do |section|
  Puppet.settings.params(section).each do |key|
    db_config[key] ||= Puppet[key]
  end
end

adapter = db_config[:dbadapter]
args = {:adapter => adapter, :log_level => db_config[:rails_loglevel]}

case adapter
  when "sqlite3"
    args[:dbfile] = db_config[:dblocation]
  when "mysql", "mysql2", "postgresql"
    args[:host]     = db_config[:dbserver] unless db_config[:dbserver].to_s.empty?
    args[:username] = db_config[:dbuser] unless db_config[:dbuser].to_s.empty?
    args[:password] = db_config[:dbpassword] unless db_config[:dbpassword].to_s.empty?
    args[:database] = db_config[:dbname] unless db_config[:dbname].to_s.empty?
    args[:port]     = db_config[:dbport] unless db_config[:dbport].to_s.empty?
    socket          = db_config[:dbsocket]
    args[:socket]   = socket unless socket.to_s.empty?
  else
    raise ArgumentError, "Invalid db adapter #{adapter}"
end

args[:database] = "puppet" unless not args[:database].to_s.empty?

ActiveRecord::Base.establish_connection(args)

ARGV.each do |hostname|
  if @host = Puppet::Rails::Host.find_by_name(hostname.strip)
    print "Removing #{hostname} from storedconfig..."
    $stdout.flush
    @host.destroy
    puts "done."
  else
    puts "Error: Can't find host #{hostname}."
  end
end

exit 0
