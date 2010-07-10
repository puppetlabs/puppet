require 'puppettest'
require 'puppet/network/http_server/webrick'

module PuppetTest::ServerTest
  include PuppetTest
  def setup
    super

    if defined?(@@port)
      @@port += 1
    else
      @@port = 20000
    end
  end

  # create a simple manifest that just creates a file
  def mktestmanifest
    file = File.join(Puppet[:confdir], "#{(self.class.to_s + "test")}site.pp")
    #@createdfile = File.join(tmpdir, self.class.to_s + "manifesttesting" +
    #    "_#{@method_name}")
    @createdfile = tempfile

    File.open(file, "w") { |f|
      f.puts "file { \"%s\": ensure => file, mode => 755 }\n" % @createdfile
    }

    @@tmpfiles << @createdfile
    @@tmpfiles << file

    file
  end

  # create a server, forked into the background
  def mkserver(handlers = nil)
    Puppet[:name] = "puppetmasterd"
    # our default handlers
    unless handlers
      handlers = {
        :CA => {}, # so that certs autogenerate
        :Master => {
          :Manifest => mktestmanifest,
          :UseNodes => false
        },
      }
    end

    # then create the actual server
    server = nil
    assert_nothing_raised {

            server = Puppet::Network::HTTPServer::WEBrick.new(
                
        :Port => @@port,
        
        :Handlers => handlers
      )
    }

    # fork it
    spid = fork {
      trap(:INT) { server.shutdown }
      server.start
    }

    # and store its pid for killing
    @@tmppids << spid

    # give the server a chance to do its thing
    sleep 1
    spid
  end

end

