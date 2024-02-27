# frozen_string_literal: true

require 'resolv'

module Puppet::HTTP
  class DNS
    class CacheEntry
      attr_reader :records, :ttl, :resolution_time

      def initialize(records)
        @records = records
        @resolution_time = Time.now
        @ttl = choose_lowest_ttl(records)
      end

      def choose_lowest_ttl(records)
        ttl = records.first.ttl
        records.each do |rec|
          if rec.ttl < ttl
            ttl = rec.ttl
          end
        end
        ttl
      end
    end

    def initialize(resolver = Resolv::DNS.new)
      @resolver = resolver

      # Stores DNS records per service, along with their TTL
      # and the time at which they were resolved, for cache
      # eviction.
      @record_cache = {}
    end

    # Iterate through the list of records for this service
    # and yield each server and port pair. Records are only fetched
    # via DNS query the first time and cached for the duration of their
    # service's TTL thereafter.
    # @param [String] domain the domain to search for
    # @param [Symbol] service_name the key of the service we are querying
    # @yields [String, Integer] server and port of selected record
    def each_srv_record(domain, service_name = :puppet, &block)
      if domain.nil? or domain.empty?
        Puppet.debug "Domain not known; skipping SRV lookup"
        return
      end

      Puppet.debug "Searching for SRV records for domain: #{domain}"

      case service_name
      when :puppet then service = '_x-puppet'
      when :file   then service = '_x-puppet-fileserver'
      else              service = "_x-puppet-#{service_name}"
      end
      record_name = "#{service}._tcp.#{domain}"

      if @record_cache.has_key?(service_name) && !expired?(service_name)
        records = @record_cache[service_name].records
        Puppet.debug "Using cached record for #{record_name}"
      else
        records = @resolver.getresources(record_name, Resolv::DNS::Resource::IN::SRV)
        if records.size > 0
          @record_cache[service_name] = CacheEntry.new(records)
        end
        Puppet.debug "Found #{records.size} SRV records for: #{record_name}"
      end

      if records.size == 0 && service_name != :puppet
        # Try the generic :puppet service if no SRV records were found
        # for the specific service.
        each_srv_record(domain, :puppet, &block)
      else
        each_priority(records) do |recs|
          while next_rr = recs.delete(find_weighted_server(recs)) # rubocop:disable Lint/AssignmentInCondition
            Puppet.debug "Yielding next server of #{next_rr.target}:#{next_rr.port}"
            yield next_rr.target.to_s, next_rr.port
          end
        end
      end
    end

    # Given a list of records of the same priority, chooses a random one
    # from among them, favoring those with higher weights.
    # @param [[Resolv::DNS::Resource::IN::SRV]] records a list of records
    #        of the same priority
    # @return [Resolv::DNS::Resource::IN:SRV] the chosen record
    def find_weighted_server(records)
      return nil if records.nil? || records.empty?
      return records.first if records.size == 1

      # Calculate the sum of all weights in the list of resource records,
      # This is used to then select hosts until the weight exceeds what
      # random number we selected.  For example, if we have weights of 1 8 and 3:
      #
      # |-|--------|---|
      #        ^
      # We generate a random number 5, and iterate through the records, adding
      # the current record's weight to the accumulator until the weight of the
      # current record plus previous records is greater than the random number.
      total_weight = records.inject(0) { |sum, record|
        sum + weight(record)
      }
      current_weight = 0
      chosen_weight  = 1 + Kernel.rand(total_weight)

      records.each do |record|
        current_weight += weight(record)
        return record if current_weight >= chosen_weight
      end
    end

    def weight(record)
      record.weight == 0 ? 1 : record.weight * 10
    end

    # Returns TTL for the cached records for this service.
    # @param [String] service_name the service whose TTL we want
    # @return [Integer] the TTL for this service, in seconds
    def ttl(service_name)
      return @record_cache[service_name].ttl
    end

    # Checks if the cached entry for the given service has expired.
    # @param [String] service_name the name of the service to check
    # @return [Boolean] true if the entry has expired, false otherwise.
    #                  Always returns true if the record had no TTL.
    def expired?(service_name)
      entry = @record_cache[service_name]
      if entry
        return Time.now > (entry.resolution_time + entry.ttl)
      else
        return true
      end
    end

    private

    # Groups the records by their priority and yields the groups
    # in order of highest to lowest priority (lowest to highest numbers),
    # one at a time.
    # { 1 => [records], 2 => [records], etc. }
    #
    # @param [[Resolv::DNS::Resource::IN::SRV]] records the list of
    #        records for a given service
    # @yields [[Resolv::DNS::Resource::IN::SRV]] a group of records of
    #         the same priority
    def each_priority(records)
      pri_hash = records.each_with_object({}) do |element, groups|
        groups[element.priority] ||= []
        groups[element.priority] << element
      end

      pri_hash.keys.sort.each do |key|
        yield pri_hash[key]
      end
    end
  end
end
