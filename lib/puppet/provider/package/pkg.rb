require 'puppet/provider/package'

Puppet::Type.type(:package).provide :pkg, :parent => Puppet::Provider::Package do
  desc "OpenSolaris image packaging system. See pkg(5) for more information"
  # http://docs.oracle.com/cd/E19963-01/html/820-6572/managepkgs.html
  # A few notes before we start :
  # Opensolaris pkg has two slightly different formats (as of now.)
  # The first one is what is distributed with the Solaris 11 Express 11/10 dvd
  # The latest one is what you get when you update package.
  # To make things more interesting, pkg version just returns a sha sum.
  # dvd:     pkg version => 052adf36c3f4
  # updated: pkg version => 630e1ffc7a19
  # Thankfully, solaris has not changed the commands to be used.
  # TODO: We still have to allow packages to specify a preferred publisher.

  commands :pkg => "/usr/bin/pkg"

  confine :osfamily => :solaris

  #defaultfor [:osfamily => :solaris, :kernelrelease => "5.11"]

  def self.instances
    pkg(:list, '-H').split("\n").map{|l| new(parse_line(l))}
  end

  # The IFO flag field is just what it names, the first field can have ether
  # i_nstalled or -, and second field f_rozen or -, and last
  # o_bsolate or r_rename or -
  # so this checks if the installed field is present, and also verifies that
  # if not the field is -, else we dont know what we are doing and exit with
  # out doing more damage.
  def self.ifo_flag(flags)
    case flags
    when /i../
      {:status => 'installed', :ensure => :present}
    when /-../
      {:status => 'known', :ensure => :absent}
    else
      raise ArgumentError, 'Unknown format %s: %s' % [self.name, flags]
    end
  end

  # The UFOXI field is the field present in the older pkg
  # (solaris 2009.06 - snv151a)
  # similar to IFO, UFOXI is also an either letter or -
  # u_pdate indicates that an update for the package is available.
  # f_rozen(n/i) o_bsolete x_cluded(n/i) i_constrained(n/i)
  # note that u_pdate flag may not be trustable due to constraints.
  # so we dont rely on it
  def self.ufoxi_flag(flags)
    {}
  end

  # pkg state was present in the older version of pkg (with UFOXI) but is
  # no longer available with the IFO field version. When it was present,
  # it was used to indicate that a particular version was present (installed)
  # and later versions were known. Note that according to the pkg man page,
  # known never lists older versions of the package. So we can rely on this
  # field to make sure that if a known is present, then the pkg is upgradable.
  def self.pkg_state(state)
    case state
    when /installed/
      {:status => 'installed', :ensure => :present}
    when /known/
      {:status => 'known', :ensure => :absent}
    else
      raise ArgumentError, 'Unknown format %s: %s,%s' % [self.name, state, flags]
    end
  end

  # Here is (hopefully) the only place we will have to deal with multiple
  # formats of output for different pkg versions.
  def self.parse_line(line)
    (case line.chomp
    # NAME (PUBLISHER)            VERSION           IFO  (new:630e1ffc7a19)
    # system/core-os              0.5.11-0.169      i--
    when /^(\S+) +(\S+) +(...)$/
       {:name => $1, :version => $2}.merge ifo_flag($3)

    # x11/wm/fvwm (fvwm.org)      2.6.1-3           i--
    when /^(\S+) \((.+)\) +(\S+) +(\S+)$/
       {:name => $1, :publisher => $2, :version => $3}.merge ifo_flag($4)

    # NAME (PUBLISHER)                  VERSION          STATE      UFOXI (dvd:052adf36c3f4)
    # SUNWcs                            0.5.11-0.126     installed  -----
    when /^(\S+) +(\S+) +(\S+) +(.....)$/
       {:name => $1, :version => $2}.merge pkg_state($3).merge(ufoxi_flag($4))

    # web/firefox/plugin/flash (extra)  10.0.32.18-0.111 installed  -----
    when /^(\S+) \((.+)\) +(\S+) +(\S+) +(.....)$/
       {:name => $1, :publisher => $2, :version => $3}.merge pkg_state($4).merge(ufoxi_flag($5))

    else
      raise ArgumentError, 'Unknown line format %s: %s' % [self.name, line]
    end).merge({:provider => self.name})
  end

  # return the version of the package. Note that this returns only installable versions of the package.
  # This output is different from pkg list -Hn which also lists other versions that are not installable.
  # due to various constraints.
  def latest
    lst = pkg(:list, "-Ha", @resource[:name]).split("\n").map{|l| self.class.parse_line(l)[:status]}
    # First check if there are any known lines (updatable), if so, we can update ourselves.
    # else it may be installed.
    ['known', 'installed'].each do |s|
      return s if lst.include?(s)
    end
    :absent
  end

  # install the package and accept all licenses.
  def install
    pkg :install, '--accept', @resource[:name]
  end

  # uninstall the package. The complication comes from the -r_ecursive flag which is no longer
  # present in newer package version.
  def uninstall
    cmd = [:uninstall]
    case (pkg :version).chomp
    when /052adf36c3f4/
      cmd << '-r'
    end
    cmd << @resource[:name]
    pkg cmd
  end

  # update the package to the latest version available
  def update
    self.install
  end

  # list a specific package
  def query
    begin
      self.class.parse_line(pkg(:list, "-H", @resource[:name]))
    rescue Puppet::ExecutionFailure
      {:ensure => :absent, :name => @resource[:name]}
    end
  end
end
