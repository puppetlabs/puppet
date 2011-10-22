require 'puppet/application'

class Puppet::Application::Cert < Puppet::Application

  should_parse_config
  run_mode :master

  attr_accessor :all, :ca, :digest, :signed

  def subcommand
    @subcommand
  end

  def subcommand=(name)
    # Handle the nasty, legacy mapping of "clean" to "destroy".
    sub = name.to_sym
    @subcommand = (sub == :clean ? :destroy : sub)
  end

  option("--clean", "-c") do
    self.subcommand = "destroy"
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

  require 'puppet/ssl/certificate_authority/interface'
  Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject {|m| m == :destroy }.each do |method|
    option("--#{method.to_s.gsub('_','-')}", "-#{method.to_s[0,1]}") do
      self.subcommand = method
    end
  end

  option("--[no-]allow-dns-alt-names") do |value|
    options[:allow_dns_alt_names] = value
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
      hosts = command_line.args.collect { |h| h.downcase }
    end
    begin
      @ca.apply(:revoke, options.merge(:to => hosts)) if subcommand == :destroy
      @ca.apply(subcommand, options.merge(:to => hosts, :digest => @digest))
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      puts detail.to_s
      exit(24)
    end
  end

  def setup
    require 'puppet/ssl/certificate_authority'
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    Puppet::Util::Log.newdestination :console

    if [:generate, :destroy].include? subcommand
      Puppet::SSL::Host.ca_location = :local
    else
      Puppet::SSL::Host.ca_location = :only
    end

    # If we are generating, and the option came from the CLI, it gets added to
    # the data.  This will do the right thing for non-local certificates, in
    # that the command line but *NOT* the config file option will apply.
    if subcommand == :generate
      if Puppet.settings.setting(:dns_alt_names).setbycli
        options[:dns_alt_names] = Puppet[:dns_alt_names]
      end
    end

    begin
      @ca = Puppet::SSL::CertificateAuthority.new
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      puts detail.to_s
      exit(23)
    end
  end

  def parse_options
    # handle the bareword subcommand pattern.
    result = super
    unless self.subcommand then
      if sub = self.command_line.args.shift then
        self.subcommand = sub
      else
        help
      end
    end
    result
  end
end
