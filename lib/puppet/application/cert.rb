require 'puppet'
require 'puppet/application'
require 'puppet/ssl/certificate_authority'

class Puppet::Application::Cert < Puppet::Application

    should_parse_config

    attr_accessor :mode, :all, :ca, :digest, :signed

    def find_mode(opt)
        modes = Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS
        tmp = opt.sub("--", '').to_sym
        @mode = modes.include?(tmp) ? tmp : nil
    end

    option("--clean", "-c") do
        @mode = :destroy
    end

    option("--all", "-a") do
        @all = true
    end

    option("--digest DIGEST") do |arg|
        @digest = arg
    end

    option("--signed", "-s") do
        @signed = true
    end

    option("--debug", "-d") do |arg|
        Puppet::Util::Log.level = :debug
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject {|m| m == :destroy }.each do |method|
        option("--#{method}", "-%s" % method.to_s[0,1] ) do
            find_mode("--#{method}")
        end
    end

    option("--verbose", "-v") do
        Puppet::Util::Log.level = :info
    end

    def main
        if @all
            hosts = :all
        elsif @signed
            hosts = :signed
        else
            hosts = command_line.args.collect { |h| puts h; h.downcase }
        end
        begin
            @ca.apply(:revoke, :to => hosts) if @mode == :destroy
            @ca.apply(@mode, :to => hosts, :digest => @digest)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            puts detail.to_s
            exit(24)
        end
    end

    def setup
        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        Puppet::Util::Log.newdestination :console

        Puppet::SSL::Host.ca_location = :only

        begin
            @ca = Puppet::SSL::CertificateAuthority.new
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            puts detail.to_s
            exit(23)
        end
    end
end
