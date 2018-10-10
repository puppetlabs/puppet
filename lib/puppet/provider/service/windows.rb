# Windows Service Control Manager (SCM) provider

Puppet::Type.type(:service).provide :windows, :parent => :service do

  desc <<-EOT
    Support for Windows Service Control Manager (SCM). This provider can
    start, stop, enable, and disable services, and the SCM provides working
    status methods for all services.

    Control of service groups (dependencies) is not yet supported, nor is running
    services as a specific user.
  EOT

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  has_feature :refreshable

  def enable
    Puppet::Util::Windows::Service.set_startup_mode( @resource[:name], :SERVICE_AUTO_START )
  rescue => detail
    raise Puppet::Error.new(_("Cannot enable %{resource_name}, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail )
  end

  def disable
    Puppet::Util::Windows::Service.set_startup_mode( @resource[:name], :SERVICE_DISABLED )
  rescue => detail
    raise Puppet::Error.new(_("Cannot disable %{resource_name}, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail )
  end

  def manual_start
    Puppet::Util::Windows::Service.set_startup_mode( @resource[:name], :SERVICE_DEMAND_START )
  rescue => detail
    raise Puppet::Error.new(_("Cannot enable %{resource_name} for manual start, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail )
  end

  def enabled?
    return :false unless Puppet::Util::Windows::Service.exists?(@resource[:name])

    start_type = Puppet::Util::Windows::Service.service_start_type(@resource[:name])
    debug("Service #{@resource[:name]} start type is #{start_type}")
    case start_type
      when :SERVICE_AUTO_START,
           :SERVICE_BOOT_START,
           :SERVICE_SYSTEM_START
        :true
      when :SERVICE_DEMAND_START
        :manual
      when :SERVICE_DISABLED
        :false
      else
        raise Puppet::Error.new(_("Unknown start type: %{start_type}") % { start_type: start_type })
    end
  rescue => detail
    raise Puppet::Error.new(_("Cannot get start type %{resource_name}, error was: %{detail}") % { resource_name: @resource[:name], detail: detail }, detail )
  end

  def start
    if status == :paused
      Puppet::Util::Windows::Service.resume(@resource[:name])
      return
    end

    # status == :stopped here

    if enabled? == :false
      # If disabled and not managing enable, respect disabled and fail.
      if @resource[:enable].nil?
        raise Puppet::Error.new(_("Will not start disabled service %{resource_name} without managing enable. Specify 'enable => false' to override.") % { resource_name: @resource[:name] })
      # Otherwise start. If enable => false, we will later sync enable and
      # disable the service again.
      elsif @resource[:enable] == :true
        enable
      else
        manual_start
      end
    end
    Puppet::Util::Windows::Service.start(@resource[:name])
  end

  def stop
    Puppet::Util::Windows::Service.stop(@resource[:name])
  end

  def status
    return :stopped unless Puppet::Util::Windows::Service.exists?(@resource[:name])

    current_state = Puppet::Util::Windows::Service.service_state(@resource[:name])
    state = case current_state
      when :SERVICE_STOPPED,
           :SERVICE_STOP_PENDING
        :stopped
      when :SERVICE_PAUSED,
           :SERVICE_PAUSE_PENDING
        :paused
      when :SERVICE_RUNNING,
           :SERVICE_CONTINUE_PENDING,
           :SERVICE_START_PENDING
        :running
      else
        raise Puppet::Error.new(_("Unknown service state '%{current_state}' for service '%{resource_name}'") % { current_state: current_state, resource_name: @resource[:name] })
    end
    debug("Service #{@resource[:name]} is #{current_state}")
    return state
  end

  # returns all providers for all existing services and startup state
  def self.instances
    services = []
    Puppet::Util::Windows::Service.services.each do |service_name, _|
      services.push(new(:name => service_name))
    end
    services
  end
end
