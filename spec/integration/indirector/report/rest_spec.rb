#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/transaction/report'
require 'puppet/network/server'
require 'puppet/network/http/webrick/rest'

describe "Report REST Terminus" do
    before do
        Puppet[:masterport] = 34343
        Puppet[:server] = "localhost"

        # Get a safe temporary file
        @tmpfile = Tempfile.new("webrick_integration_testing")
        @dir = @tmpfile.path + "_dir"

        Puppet.settings[:confdir] = @dir
        Puppet.settings[:vardir] = @dir
        Puppet.settings[:server] = "127.0.0.1"
        Puppet.settings[:masterport] = "34343"

        Puppet::Util::Cacher.expire

        Puppet[:servertype] = 'webrick'
        Puppet[:server] = '127.0.0.1'
        Puppet[:certname] = '127.0.0.1'

        # Generate the certificate with a local CA
        Puppet::SSL::Host.ca_location = :local
        ca = Puppet::SSL::CertificateAuthority.new
        ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.find(Puppet[:certname])
        ca.generate("foo.madstop.com") unless Puppet::SSL::Certificate.find(Puppet[:certname])

        @host = Puppet::SSL::Host.new(Puppet[:certname])

        @params = { :port => 34343, :handlers => [ :report ] }
        @server = Puppet::Network::Server.new(@params)
        @server.listen

        # Let's use REST for our reports :-)
        @old_terminus = Puppet::Transaction::Report.indirection.terminus_class
        Puppet::Transaction::Report.terminus_class = :rest

        # LAK:NOTE We need to have a fake model here so that our indirected methods get
        # passed through REST; otherwise we'd be stubbing 'save', which would cause an immediate
        # return.
        @report = stub_everything 'report'
        @mock_model = stub_everything 'faked model', :name => "report", :convert_from => @report
        Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)

        Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:check_authorization)
    end

    after do
        Puppet::Network::HttpPool.expire
        Puppet::SSL::Host.ca_location = :none
        Puppet.settings.clear
        @server.unlisten
        Puppet::Transaction::Report.terminus_class = @old_terminus
    end

    it "should be able to send a report to the server" do
        @report.expects(:save)

        report = Puppet::Transaction::Report.new

        resourcemetrics = {
            :total => 12,
            :out_of_sync => 20,
            :applied => 45,
            :skipped => 1,
            :restarted => 23,
            :failed_restarts => 1,
            :scheduled => 10
        }
        report.add_metric(:resources, resourcemetrics)

        timemetrics = {
            :resource1 => 10,
            :resource2 => 50,
            :resource3 => 40,
            :resource4 => 20,
        }
        report.add_metric(:times, timemetrics)

        report.add_metric(:changes,
            :total => 20
        )

        report.save
    end
end
