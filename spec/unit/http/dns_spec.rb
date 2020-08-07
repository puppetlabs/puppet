require 'spec_helper'
require 'puppet/http'

describe Puppet::HTTP::DNS do
  before do
    @dns_mock_object = double('dns')
    allow(Resolv::DNS).to receive(:new).and_return(@dns_mock_object)

    @rr_type         = Resolv::DNS::Resource::IN::SRV
    @test_srv_domain = "domain.com"
    @test_a_hostname = "puppet.domain.com"
    @test_port       = 1000

    # The records we should use.
    @test_records = [
      #                                  priority,  weight, port, target
      Resolv::DNS::Resource::IN::SRV.new(0,         20,     8140, "puppet1.domain.com"),
      Resolv::DNS::Resource::IN::SRV.new(0,         80,     8140, "puppet2.domain.com"),
      Resolv::DNS::Resource::IN::SRV.new(1,         1,      8140, "puppet3.domain.com"),
      Resolv::DNS::Resource::IN::SRV.new(4,         1,      8140, "puppet4.domain.com")
    ]

    @test_records.each do |rec|
      # Resources do not expose public API for setting the TTL
      rec.instance_variable_set(:@ttl, 3600)
    end
  end

  let(:resolver) { described_class.new }

  describe 'when the domain is not known' do
    before :each do
      allow(@dns_mock_object).to receive(:getresources).and_return(@test_records)
    end

    describe 'because domain is nil' do
      it 'does not yield' do
        resolver.each_srv_record(nil) do |_,_,_|
          raise Exception.new("nil domain caused SRV lookup")
        end
      end
    end

    describe 'because domain is an empty string' do
      it 'does not yield' do
        resolver.each_srv_record('') do |_,_,_|
          raise Exception.new("nil domain caused SRV lookup")
        end
      end
    end
  end

  describe "when resolving a host without SRV records" do

    it "should not yield anything" do
      # No records returned for a DNS entry without any SRV records
      expect(@dns_mock_object).to receive(:getresources).with(
        "_x-puppet._tcp.#{@test_a_hostname}",
        @rr_type
      ).and_return([])

      resolver.each_srv_record(@test_a_hostname) do |hostname, port, remaining|
        raise Exception.new("host with no records passed block")
      end
    end
  end

  describe "when resolving a host with SRV records" do
    it "should iterate through records in priority order" do
      # The order of the records that should be returned,
      # an array means unordered (for weight)
      order = {
        0 => ["puppet1.domain.com", "puppet2.domain.com"],
        1 => ["puppet3.domain.com"],
        2 => ["puppet4.domain.com"]
      }

      expect(@dns_mock_object).to receive(:getresources).with(
        "_x-puppet._tcp.#{@test_srv_domain}",
        @rr_type
      ).and_return(@test_records)

      resolver.each_srv_record(@test_srv_domain) do |hostname, port|
        expected_priority = order.keys.min

        expect(order[expected_priority]).to include(hostname)
        expect(port).not_to be(@test_port)

        # Remove the host from our expected hosts
        order[expected_priority].delete hostname

        # Remove this priority level if we're done with it
        order.delete expected_priority if order[expected_priority] == []
      end
    end

    it "should fall back to the :puppet service if no records are found for a more specific service" do
      # The order of the records that should be returned,
      # an array means unordered (for weight)
      order = {
        0 => ["puppet1.domain.com", "puppet2.domain.com"],
        1 => ["puppet3.domain.com"],
        2 => ["puppet4.domain.com"]
      }

      expect(@dns_mock_object).to receive(:getresources).with(
        "_x-puppet-report._tcp.#{@test_srv_domain}",
        @rr_type
      ).and_return([])

      expect(@dns_mock_object).to receive(:getresources).with(
        "_x-puppet._tcp.#{@test_srv_domain}",
        @rr_type
      ).and_return(@test_records)

      resolver.each_srv_record(@test_srv_domain, :report) do |hostname, port|
        expected_priority = order.keys.min

        expect(order[expected_priority]).to include(hostname)
        expect(port).not_to be(@test_port)

        # Remove the host from our expected hosts
        order[expected_priority].delete hostname

        # Remove this priority level if we're done with it
        order.delete expected_priority if order[expected_priority] == []
      end
    end

    it "should use SRV records from the specific service if they exist" do
      # The order of the records that should be returned,
      # an array means unordered (for weight)
      order = {
        0 => ["puppet1.domain.com", "puppet2.domain.com"],
        1 => ["puppet3.domain.com"],
        2 => ["puppet4.domain.com"]
      }

      bad_records = [
        #                                  priority,  weight, port, hostname
        Resolv::DNS::Resource::IN::SRV.new(0,         20,     8140, "puppet1.bad.domain.com"),
        Resolv::DNS::Resource::IN::SRV.new(0,         80,     8140, "puppet2.bad.domain.com"),
        Resolv::DNS::Resource::IN::SRV.new(1,         1,      8140, "puppet3.bad.domain.com"),
        Resolv::DNS::Resource::IN::SRV.new(4,         1,      8140, "puppet4.bad.domain.com")
      ]

      expect(@dns_mock_object).to receive(:getresources).with(
        "_x-puppet-report._tcp.#{@test_srv_domain}",
        @rr_type
      ).and_return(@test_records)

      allow(@dns_mock_object).to receive(:getresources).with(
        "_x-puppet._tcp.#{@test_srv_domain}",
        @rr_type
      ).and_return(bad_records)

      resolver.each_srv_record(@test_srv_domain, :report) do |hostname, port|
        expected_priority = order.keys.min

        expect(order[expected_priority]).to include(hostname)
        expect(port).not_to be(@test_port)

        # Remove the host from our expected hosts
        order[expected_priority].delete hostname

        # Remove this priority level if we're done with it
        order.delete expected_priority if order[expected_priority] == []
      end
    end
  end

  describe "when finding weighted servers" do
    it "should return nil when no records were found" do
      expect(resolver.find_weighted_server([])).to eq(nil)
    end

    it "should return the first record when one record is passed" do
      result = resolver.find_weighted_server([@test_records.first])
      expect(result).to eq(@test_records.first)
    end

    {
      "all have weights"  => [1, 3, 2, 4],
      "some have weights" => [2, 0, 1, 0],
      "none have weights" => [0, 0, 0, 0],
    }.each do |name, weights|
      it "should return correct results when #{name}" do
        records = []
        count   = 0
        weights.each do |w|
          count += 1
          #                                             priority, weight, port, server
          records << Resolv::DNS::Resource::IN::SRV.new(0,        w,      1,    count.to_s)
        end

        seen  = Hash.new(0)
        total_weight = records.inject(0) do |sum, record|
          sum + resolver.weight(record)
        end

        total_weight.times do |n|
          expect(Kernel).to receive(:rand).once.with(total_weight).and_return(n)
          server = resolver.find_weighted_server(records)
          seen[server] += 1
        end

        expect(seen.length).to eq(records.length)
        records.each do |record|
          expect(seen[record]).to eq(resolver.weight(record))
        end
      end
    end
  end

  describe "caching records" do
    it "should query DNS when no cache entry exists, then retrieve the cached value" do
      expect(@dns_mock_object).to receive(:getresources).with(
        "_x-puppet._tcp.#{@test_srv_domain}",
        @rr_type
      ).and_return(@test_records).once

      fetched_servers = []
      resolver.each_srv_record(@test_srv_domain) do |server, port|
        fetched_servers << server
      end

      cached_servers = []
      expect(resolver).to receive(:expired?).and_return(false)
      resolver.each_srv_record(@test_srv_domain) do |server, port|
        cached_servers << server
      end
      expect(fetched_servers).to match_array(cached_servers)
    end

    context "TTLs" do
      before(:each) do
        # The TTL of an SRV record cannot be set via any public API
        ttl_record1 = Resolv::DNS::Resource::IN::SRV.new(0, 20, 8140, "puppet1.domain.com")
        ttl_record1.instance_variable_set(:@ttl, 10)
        ttl_record2 = Resolv::DNS::Resource::IN::SRV.new(0, 20, 8140, "puppet2.domain.com")
        ttl_record2.instance_variable_set(:@ttl, 20)
        records = [ttl_record1, ttl_record2]

        expect(@dns_mock_object).to receive(:getresources).with(
          "_x-puppet._tcp.#{@test_srv_domain}",
          @rr_type
        ).and_return(records)
      end

      it "should save the shortest TTL among records for a service" do
        resolver.each_srv_record(@test_srv_domain) { |server, port| }
        expect(resolver.ttl(:puppet)).to eq(10)
      end

      it "should fetch records again if the TTL has expired" do
        # Fetch from DNS
        resolver.each_srv_record(@test_srv_domain) do |server, port|
          expect(server).to match(/puppet.*domain\.com/)
        end

        expect(resolver).to receive(:expired?).with(:puppet).and_return(false)
        # Load from cache
        resolver.each_srv_record(@test_srv_domain) do |server, port|
          expect(server).to match(/puppet.*domain\.com/)
        end

        new_record = Resolv::DNS::Resource::IN::SRV.new(0, 20, 8140, "new.domain.com")
        new_record.instance_variable_set(:@ttl, 10)
        expect(@dns_mock_object).to receive(:getresources).with(
          "_x-puppet._tcp.#{@test_srv_domain}",
          @rr_type
        ).and_return([new_record])
        expect(resolver).to receive(:expired?).with(:puppet).and_return(true)
        # Refresh from DNS
        resolver.each_srv_record(@test_srv_domain) do |server, port|
          expect(server).to eq("new.domain.com")
        end
      end
    end
  end
end
