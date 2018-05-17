require 'resolv'

module Puppet::Network
  class Resolver

    def initialize
      @resolver = Resolv::DNS.new
      @record_cache = {}
    end

    # Iterate through the list of servers that service this hostname
    # and yield each server/port since SRV records have ports in them
    # It will override whatever masterport setting is already set.
    def each_srv_record(domain, service_name = :puppet, &block)
      if (domain.nil? or domain.empty?)
        Puppet.debug "Domain not known; skipping SRV lookup"
        return
      end

      Puppet.debug "Searching for SRV records for domain: #{domain}"

      case service_name
        when :puppet then service = '_x-puppet'
        when :ca     then service = '_x-puppet-ca'
        when :report then service = '_x-puppet-report'
        when :file   then service = '_x-puppet-fileserver'
        else              service = "_x-puppet-#{service_name.to_s}"
      end
      srv_record = "#{service}._tcp.#{domain}"

      if @record_cache.has_key?(service_name)
        records = @record_cache[service_name]
        Puppet.debug "Using cached record for #{srv_record}"
      else
        records = @resolver.getresources(srv_record, Resolv::DNS::Resource::IN::SRV)
        @record_cache[service_name] = records
        Puppet.debug "Found #{records.size} SRV records for: #{srv_record}"
      end

      if records.size == 0 && service_name != :puppet
        # Try the generic :puppet service if no SRV records were found
        # for the specific service.
        each_srv_record(domain, :puppet, &block)
      else
        each_priority(records) do |priority, recs|
          while next_rr = recs.delete(find_weighted_server(recs))
            Puppet.debug "Yielding next server of #{next_rr.target.to_s}:#{next_rr.port}"
            yield next_rr.target.to_s, next_rr.port
          end
        end
      end
    end

    def find_weighted_server(records)
      return nil if records.nil? || records.empty?
      return records.first if records.size == 1

      # Calculate the sum of all weights in the list of resource records,
      # This is used to then select hosts until the weight exceeds what
      # random number we selected.  For example, if we have weights of 1 8 and 3:
      #
      # |-|---|--------|
      #        ^
      # We generate a random number 5, and iterate through the records, adding
      # the current record's weight to the accumulator until the weight of the
      # current record plus previous records is greater than the random number.

      total_weight = records.inject(0) { |sum,record|
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

    private

    def each_priority(records)
      pri_hash = records.inject({}) do |groups, element|
        groups[element.priority] ||= []
        groups[element.priority] << element
        groups
      end

      pri_hash.keys.sort.each do |key|
        yield key, pri_hash[key]
      end
    end
  end
end
