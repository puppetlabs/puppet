require 'puppet/util/network_device'
require 'puppet/util/network_device/transport'
require 'puppet/util/network_device/transport/base'

if Puppet.features.telnet?
  require 'net/telnet'

  class Puppet::Util::NetworkDevice::Transport::Telnet < Puppet::Util::NetworkDevice::Transport::Base
      def initialize(verbose = false)
        super()
        @verbose = verbose
      end

      def handles_login?
        false
      end

      def connect
        @telnet = Net::Telnet::new("Host" => host, "Port" => port || 23,
                                   "Timeout" => 10,
                                   "Prompt" => default_prompt)
      end

      def close
        @telnet.close if @telnet
        @telnet = nil
      end

      def expect(prompt)
        @telnet.waitfor(prompt) do |out|
          yield out if block_given?
        end
      end

      def command(cmd, options = {})
        send(cmd)
        expect(options[:prompt] || default_prompt) do |output|
          yield output if block_given?
        end
      end

      def send(line)
        Puppet.debug("telnet: send #{line}") if @verbose
        @telnet.puts(line)
      end
  end
end
