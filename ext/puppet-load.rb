#!/usr/bin/env ruby
# == Synopsis
#
# This tool can exercize a puppetmaster by simulating an arbitraty number of concurrent clients
# in a lightweight way.
# 
# = Prerequisites
# 
# This tool requires Event Machine and em-http-request, and an installation of Puppet.
# Event Machine can be installed from gem.
# em-http-request can be installed from gem.
# 
# = Usage
#
#   puppet-load [-d|--debug] [--concurrency <num>] [--repeat <num>] [-V|--version] [-v|--verbose]
#               [--node <host.domain.com>] [--facts <factfile>] [--cert <certfile>] [--key <keyfile>]
#               [--factsdir <factsdir>] [--server <server.domain.com>]
#
# = Description
#
# This is a simple script meant for doing performance tests of puppet masters. It does this
# by simulating concurrent connections to a puppet master and asking for catalog compilation.
#
# = Options
#
# Unlike other puppet executables, puppet-load doesn't parse puppet.conf nor use puppet options
#
# debug::
#   Enable full debugging.
#
# concurreny::
#   Number of simulated concurrent clients.
#
# server::
#   Set the puppet master hostname or IP address..
#
# node::
#   Set the fully-qualified domain name of the client. This option can be given multiple
#   times. In this case puppet-load will ask for catalog compilation of all the given nodes
#   on a round robin way.
#
# help::
#   Print this help message
#
# facts::
#   This can be used to provide facts for the compilation, directly from a YAML
#   file as found in the clientyaml directory. If none are provided, puppet-load
#   will look by itself using Puppet facts indirector.
#
# factsdir::
#   Specify a directory where the yaml facts files can be found. If provided puppet-load
#   will look up facts in this directory. If not found it will resort to using Puppet Facts
#   indirector.
#
# cert::
#   This option is mandatory. It should be set to the cert PEM file that will be used
#   to quthenticate the client connections.
#
# key::
#   This option is mandatory. It should be set to the private key PEM file that will be used
#   to quthenticate the client connections.
#
# timeout::
#   The number of seconds after which a simulated client is declared in error if it didn't get
#   a catalog. The default is 180s.
#
# repeat::
#  How many times to perform the test. This means puppet-load will ask for
#  concurrency * repeat catalogs. 
#
# verbose::
#   Turn on verbose reporting.
#
# version::
#   Print the puppet version number and exit.
#
# = Example usage
#
# SINGLE NODE:
#   1) On the master host, generate a new certificate and private key for our test host:
#   puppet ca --generate puppet-load.domain.com
#
#   2) Copy the cert and key to the puppet-load host (which can be the same as the master one)
#
#   3) On the master host edit or create the auth.conf so that the catalog ACL match:
#      path ~ ^/catalog/([^/]+)$
#      method find
#      allow $1
#      allow puppet-load.domain.com
#
#   4) launch the master(s)
#
#   5) Prepare or get a fact file. One way to get one is to look on the master in $vardir/yaml/ for the host
#   you want to simulate.
#
#   5) launch puppet-load
#   puppet-load -debug --node server.domain.com --server master.domain.com --facts server.domain.com.yaml --concurrency 2 --repeat 20 
#
# MULTIPLE NODES:
#   1) On the master host, generate a new certificate and private key for our test host:
#   puppet ca --generate puppet-load.domain.com
#
#   2) Copy the cert and key to the puppet-load host (which can be the same as the master one)
#
#   3) On the master host edit or create the auth.conf so that the catalog ACL match:
#      path ~ ^/catalog/([^/]+)$
#      method find
#      allow $1
#      allow puppet-load.domain.com
#
#   4) launch the master(s)
#
#   5) Prepare or get a fact file. One way to get one is to look on the master in $vardir/yaml/ for the host
#   you want to simulate.
#
#   5) launch puppet-load
#   puppet-load -debug --node server1.domain.com --node server2.domain.com --node server3.domain.com \
#                      --server master.domain.com --factsdir /var/lib/puppet/yaml/facts --concurrency 2 --repeat 20 
#
#   puppet-load will load facts file in the --factsdir directory based on the node name.
#
# = TODO
#   * More output stats for error connections (ie report errors, HTTP code...)
#
#

# Do an initial trap, so that cancels don't get a stack trace.
trap(:INT) do
  $stderr.puts "Cancelling startup"
  exit(1)
end

require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'getoptlong'
require 'puppet'

$cmdargs = [
  [ "--concurrency",  "-c", GetoptLong::REQUIRED_ARGUMENT       ],
  [ "--node",     "-n", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--facts",          GetoptLong::REQUIRED_ARGUMENT ],
  [ "--factsdir",       GetoptLong::REQUIRED_ARGUMENT ],
  [ "--repeat",   "-r", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--cert",     "-C", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--key",      "-k", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--timeout",  "-t", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--server",   "-s", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--debug",    "-d", GetoptLong::NO_ARGUMENT       ],
  [ "--help",     "-h", GetoptLong::NO_ARGUMENT       ],
  [ "--verbose",  "-v", GetoptLong::NO_ARGUMENT       ],
  [ "--version",  "-V", GetoptLong::NO_ARGUMENT       ],
]

Puppet::Util::Log.newdestination(:console)

times = {}

def read_facts(file)
  Puppet.debug("reading facts from: #{file}")
  fact = YAML.load(File.read(file))
end


result = GetoptLong.new(*$cmdargs)

$args = {}
$options = {:repeat => 1, :concurrency => 1, :pause => false, :cert => nil, :key => nil, :timeout => 180, :masterport => 8140, :node => [], :factsdir => nil}

begin
  result.each { |opt,arg|
    case opt
    when "--concurrency"
      begin
        $options[:concurrency] = Integer(arg)
      rescue => detail
        $stderr.puts "The argument to 'fork' must be an integer"
        exit(14)
      end
    when "--node"
      $options[:node] << arg
    when "--factsdir"
      $options[:factsdir] = arg
    when "--server"
      $options[:server] = arg
    when "--masterport"
      $options[:masterport] = arg
    when "--facts"
      $options[:facts] = arg
    when "--repeat"
      $options[:repeat] = Integer(arg)
    when "--help"
      if Puppet.features.usage?
        RDoc::usage && exit
      else
        puts "No help available unless you have RDoc::usage installed"
        exit
      end
    when "--version"
      puts "%s" % Puppet.version
      exit
    when "--verbose"
      Puppet::Util::Log.level = :info
      Puppet::Util::Log.newdestination(:console)
    when "--debug"
      Puppet::Util::Log.level = :debug
      Puppet::Util::Log.newdestination(:console)
    when "--cert"
      $options[:cert] = arg
    when "--key"
      $options[:key] = arg
    end
  }
rescue GetoptLong::InvalidOption => detail
  $stderr.puts detail
  $stderr.puts "Try '#{$0} --help'"
  exit(1)
end

unless $options[:cert] and $options[:key]
  raise "--cert and --key are mandatory to authenticate the client"
end

parameters = []

unless $options[:node].size > 0
  raise "--node is a mandatory argument. It tells to the master what node to compile"
end

$options[:node].each do |node|
  factfile = $options[:factsdir] ? File.join($options[:factsdir], node + ".yaml") : $options[:facts]
  unless fact = read_facts(factfile) or fact = Puppet::Node::Facts.find(node)
    raise "Could not find facts for %s" % node
  end
  fact.values["fqdn"] = node
  fact.values["hostname"] = node.sub(/\..+/, '')
  fact.values["domain"] = node.sub(/^[^.]+\./, '')

  parameters << {:facts_format => "b64_zlib_yaml", :facts => CGI.escape(fact.render(:b64_zlib_yaml))}
end


class RequestPool
  include EventMachine::Deferrable

  attr_reader :requests, :responses, :times, :sizes
  attr_reader :repeat, :concurrency, :max_request

  def initialize(concurrency, repeat, parameters)
    @parameters = parameters
    @current_request = 0
    @max_request = repeat * concurrency
    @repeat = repeat
    @concurrency = concurrency
    @requests = []
    @responses = {:succeeded => [], :failed => []}
    @times = {}
    @sizes = {}

    # initial spawn
    (1..concurrency).each do |i|
      spawn
    end

  end

  def spawn_request(index)
    @times[index] = Time.now
    @sizes[index] = 0
    nodeidx = index % $options[:node].size
    node = $options[:node][nodeidx]
    EventMachine::HttpRequest.new("https://#{$options[:server]}:#{$options[:masterport]}/production/catalog/#{node}").get(
    :port => $options[:masterport],
    :query => @parameters[nodeidx],
    :timeout => $options[:timeout],
    :head => { "Accept" => "pson, yaml, b64_zlib_yaml, marshal, dot, raw", "Accept-Encoding" => "gzip, deflate" },
    :ssl => { :private_key_file => $options[:key],
              :cert_chain_file => $options[:cert],
              :verify_peer => false } ) do
        @times[index] = Time.now
        @sizes[index] = 0
        Puppet.debug("starting client #{index} for #{node}")
    end
  end

  def add(index, conn)
    @requests.push(conn)

    conn.stream { |data|
      @sizes[index] += data.length
    }

    conn.callback {
      @times[index] = Time.now - @times[index]
      code = conn.response_header.status
      if code >= 200 && code < 300
        Puppet.debug("Client #{index} finished successfully")
        @responses[:succeeded].push(conn)
      else
        Puppet.debug("Client #{index} finished with HTTP code #{code}")
        @responses[:failed].push(conn)
      end
      check_progress
    }

    conn.errback {
      Puppet.debug("Client #{index} finished with an error: #{conn.error}")
      @times[index] = Time.now - @times[index]
      @responses[:failed].push(conn)
      check_progress
    }
  end

  def all_responses
    @responses[:succeeded] + @responses[:failed]
  end

  protected

  def check_progress
    spawn unless all_spawned?
    succeed if all_finished?
  end

  def all_spawned?
    @requests.size >= max_request
  end

  def all_finished?
    @responses[:failed].size + @responses[:succeeded].size >= max_request
  end

  def spawn
    add(@current_request, spawn_request(@current_request))
    @current_request += 1
  end
end


def mean(array)
  array.inject(0) { |sum, x| sum += x } / array.size.to_f
end

def median(array)
  array = array.sort
  m_pos = array.size / 2
  return array.size % 2 == 1 ? array[m_pos] : mean(array[m_pos-1..m_pos])
end

def format_bytes(bytes)
  if bytes < 1024
    "%.2f B" % bytes
  elsif bytes < 1024 * 1024
    "%.2f KiB" % (bytes/1024.0)
  else
    "%.2f MiB" % (bytes/(1024.0*1024.0))
  end
end

EM::run {

  start = Time.now
  multi = RequestPool.new($options[:concurrency], $options[:repeat], parameters)

  multi.callback do
    duration = Time.now - start
    puts "#{multi.max_request} requests finished in #{duration} s"
    puts "#{multi.responses[:failed].size} requests failed"
    puts "Availability: %3.2f %%" % (100.0*multi.responses[:succeeded].size/(multi.responses[:succeeded].size+multi.responses[:failed].size))

    minmax = multi.times.values.minmax
    all_time = multi.times.values.reduce(:+)

    puts "\nTime (s):"
    puts "\tmin: #{minmax[0]} s"
    puts "\tmax: #{minmax[1]} s"
    puts "\taverage: #{mean(multi.times.values)} s"
    puts "\tmedian: #{median(multi.times.values)} s"

    puts "\nConcurrency: %.2f" % (all_time/duration)
    puts "Transaction Rate (tps): %.2f t/s" % (multi.max_request / duration)

    transferred = multi.sizes.values.reduce(:+)

    puts "\nReceived bytes: #{format_bytes(transferred)}"
    puts "Throughput: %.5f MiB/s" % (transferred/duration/(1024.0*1024.0))

    # this is the end
    EventMachine.stop
  end
}


