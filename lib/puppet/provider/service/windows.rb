# frozen_string_literal: true

# Windows Service Control Manager (SCM) provider

Puppet::Type.type(:service).provide :windows, :parent => :service do
  desc <<-EOT
    Support for Windows Service Control Manager (SCM). This provider can
    start, stop, enable, and disable services, and the SCM provides working
    status methods for all services.

    Control of service groups (dependencies) is not yet supported, nor is running
    services as a specific user.
  EOT

  defaultfor 'os.name' => :windows
  confine    'os.name' => :windows

  has_feature :refreshable, :configurable_timeout, :manages_logon_credentials

  def enable
    Puppet::Util::Windows::Service.set_startup_configuration(@resource[:name], options: { startup_type: :SERVICE_AUTO_START })
  rescue => detail
    raise Puppet::Error.new(_("Cannot enable %{resource_name}, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail)
  end

  def disable
    Puppet::Util::Windows::Service.set_startup_configuration(@resource[:name], options: { startup_type: :SERVICE_DISABLED })
  rescue => detail
    raise Puppet::Error.new(_("Cannot disable %{resource_name}, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail)
  end

  def manual_start
    Puppet::Util::Windows::Service.set_startup_configuration(@resource[:name], options: { startup_type: :SERVICE_DEMAND_START })
  rescue => detail
    raise Puppet::Error.new(_("Cannot enable %{resource_name} for manual start, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail)
  end

  def delayed_start
    Puppet::Util::Windows::Service.set_startup_configuration(@resource[:name], options: { startup_type: :SERVICE_AUTO_START, delayed: true })
  rescue => detail
    raise Puppet::Error.new(_("Cannot enable %{resource_name} for delayed start, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail)
  end

  def enabled?
    return :false unless Puppet::Util::Windows::Service.exists?(@resource[:name])

    start_type = Puppet::Util::Windows::Service.service_start_type(@resource[:name])
    debug("Service #{@resource[:name]} start type is #{start_type}")
    case start_type
    when :SERVICE_AUTO_START, :SERVICE_BOOT_START, :SERVICE_SYSTEM_START
      :true
    when :SERVICE_DEMAND_START
      :manual
    when :SERVICE_DELAYED_AUTO_START
      :delayed
    when :SERVICE_DISABLED
      :false
    else
      raise Puppet::Error, _("Unknown start type: %{start_type}") % { start_type: start_type }
    end
  rescue => detail
    raise Puppet::Error.new(_("Cannot get start type %{resource_name}, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail)
  end

  def start
    if status == :paused
      Puppet::Util::Windows::Service.resume(@resource[:name], timeout: @resource[:timeout])
      return
    end

    # status == :stopped here

    if enabled? == :false
      # If disabled and not managing enable, respect disabled and fail.
      if @resource[:enable].nil?
        raise Puppet::Error, _("Will not start disabled service %{resource_name} without managing enable. Specify 'enable => false' to override.") % { resource_name: @resource[:name] }
      # Otherwise start. If enable => false, we will later sync enable and
      # disable the service again.
      elsif @resource[:enable] == :true
        enable
      else
        manual_start
      end
    end
    Puppet::Util::Windows::Service.start(@resource[:name], timeout: @resource[:timeout])
  end

  def stop
    Puppet::Util::Windows::Service.stop(@resource[:name], timeout: @resource[:timeout])
  end

  def status
    return :stopped unless Puppet::Util::Windows::Service.exists?(@resource[:name])

    current_state = Puppet::Util::Windows::Service.service_state(@resource[:name])
    state = case current_state
            when :SERVICE_STOPPED, :SERVICE_STOP_PENDING
              :stopped
            when :SERVICE_PAUSED, :SERVICE_PAUSE_PENDING
              :paused
            when :SERVICE_RUNNING, :SERVICE_CONTINUE_PENDING, :SERVICE_START_PENDING
              :running
            else
              raise Puppet::Error, _("Unknown service state '%{current_state}' for service '%{resource_name}'") % { current_state: current_state, resource_name: @resource[:name] }
            end
    debug("Service #{@resource[:name]} is #{current_state}")
    state
  rescue => detail
    Puppet.warning("Status for service #{@resource[:name]} could not be retrieved: #{detail}")
    :stopped
  end

  def default_timeout
    Puppet::Util::Windows::Service::DEFAULT_TIMEOUT
  end

  # returns all providers for all existing services and startup state
  def self.instances
    services = []
    Puppet::Util::Windows::Service.services.each do |service_name, _|
      services.push(new(:name => service_name))
    end
    services
  end

  def logonaccount_insync?(current)
    @normalized_logon_account ||= normalize_logonaccount
    @resource[:logonaccount] = @normalized_logon_account

    insync = @resource[:logonaccount] == current
    self.logonpassword = @resource[:logonpassword] if insync
    insync
  end

  def logonaccount
    return unless Puppet::Util::Windows::Service.exists?(@resource[:name])

    Puppet::Util::Windows::Service.logon_account(@resource[:name])
  end

  def logonaccount=(value)
    validate_logon_credentials
    Puppet::Util::Windows::Service.set_startup_configuration(@resource[:name], options: { logon_account: value, logon_password: @resource[:logonpassword] })
    restart if @resource[:ensure] == :running && [:running, :paused].include?(status)
  end

  def logonpassword=(value)
    validate_logon_credentials
    Puppet::Util::Windows::Service.set_startup_configuration(@resource[:name], options: { logon_password: value })
  end

  private

  def normalize_logonaccount
    logon_account = @resource[:logonaccount].sub(/^\.\\/, "#{Puppet::Util::Windows::ADSI.computer_name}\\")
    return 'LocalSystem' if Puppet::Util::Windows::User.localsystem?(logon_account)

    @logonaccount_information ||= Puppet::Util::Windows::SID.name_to_principal(logon_account)
    return logon_account unless @logonaccount_information
    return ".\\#{@logonaccount_information.account}" if @logonaccount_information.domain == Puppet::Util::Windows::ADSI.computer_name

    @logonaccount_information.domain_account
  end

  def validate_logon_credentials
    unless Puppet::Util::Windows::User.localsystem?(@normalized_logon_account)
      raise Puppet::Error, "\"#{@normalized_logon_account}\" is not a valid account" unless @logonaccount_information && [:SidTypeUser, :SidTypeWellKnownGroup].include?(@logonaccount_information.account_type)

      user_rights = Puppet::Util::Windows::User.get_rights(@logonaccount_information.domain_account) unless Puppet::Util::Windows::User.default_system_account?(@normalized_logon_account)
      raise Puppet::Error, "\"#{@normalized_logon_account}\" has the 'Log On As A Service' right set to denied." if user_rights =~ /SeDenyServiceLogonRight/
      raise Puppet::Error, "\"#{@normalized_logon_account}\" is missing the 'Log On As A Service' right." unless user_rights.nil? || user_rights =~ /SeServiceLogonRight/
    end

    is_a_predefined_local_account = Puppet::Util::Windows::User.default_system_account?(@normalized_logon_account) || @normalized_logon_account == 'LocalSystem'
    account_info = @normalized_logon_account.split("\\")
    able_to_logon = Puppet::Util::Windows::User.password_is?(account_info[1], @resource[:logonpassword], account_info[0]) unless is_a_predefined_local_account
    raise Puppet::Error, "The given password is invalid for user '#{@normalized_logon_account}'." unless is_a_predefined_local_account || able_to_logon
  end
end
