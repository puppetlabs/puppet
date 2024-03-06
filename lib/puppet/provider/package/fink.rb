# frozen_string_literal: true

Puppet::Type.type(:package).provide :fink, :parent => :dpkg, :source => :dpkg do
  # Provide sorting functionality
  include Puppet::Util::Package

  desc "Package management via `fink`."

  commands :fink => "/sw/bin/fink"
  commands :aptget => "/sw/bin/apt-get"
  commands :aptcache => "/sw/bin/apt-cache"
  commands :dpkgquery => "/sw/bin/dpkg-query"

  has_feature :versionable

  # A derivative of DPKG; this is how most people actually manage
  # Debian boxes, and the only thing that differs is that it can
  # install packages from remote sites.

  def finkcmd(*args)
    fink(*args)
  end

  # Install a package using 'apt-get'.  This function needs to support
  # installing a specific version.
  def install
    run_preseed if @resource[:responsefile]
    should = @resource.should(:ensure)

    str = @resource[:name]
    case should
    when true, false, Symbol
      # pass
    else
      # Add the package version
      str += "=#{should}"
    end
    cmd = %w[-b -q -y]

    cmd << :install << str

    unhold if properties[:mark] == :hold
    begin
      finkcmd(cmd)
    ensure
      hold if @resource[:mark] == :hold
    end
  end

  # What's the latest package version available?
  def latest
    output = aptcache :policy, @resource[:name]

    if output =~ /Candidate:\s+(\S+)\s/
      Regexp.last_match(1)
    else
      err _("Could not find latest version")
      nil
    end
  end

  #
  # preseeds answers to dpkg-set-selection from the "responsefile"
  #
  def run_preseed
    response = @resource[:responsefile]
    if response && Puppet::FileSystem.exist?(response)
      info(_("Preseeding %{response} to debconf-set-selections") % { response: response })

      preseed response
    else
      info _("No responsefile specified or non existent, not preseeding anything")
    end
  end

  def update
    install
  end

  def uninstall
    unhold if properties[:mark] == :hold
    begin
      finkcmd "-y", "-q", :remove, @model[:name]
    rescue StandardError, LoadError => e
      hold if properties[:mark] == :hold
      raise e
    end
  end

  def purge
    unhold if properties[:mark] == :hold
    begin
      aptget '-y', '-q', 'remove', '--purge', @resource[:name]
    rescue StandardError, LoadError => e
      hold if properties[:mark] == :hold
      raise e
    end
  end
end
