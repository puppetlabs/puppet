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

  has_feature :versionable

  has_feature :upgradable

  has_feature :holdable

  commands :pkg => "/usr/bin/pkg"

  confine :osfamily => :solaris

  defaultfor :osfamily => :solaris, :kernelrelease => '5.11'

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
    (
      case flags[0..0]
      when 'i'
        {:status => 'installed'}
      when '-'
        {:status => 'known'}
      else
        raise ArgumentError, 'Unknown format %s: %s[%s]' % [self.name, flags, flags[0..0]]
      end
    ).merge(
      case flags[1..1]
      when 'f'
        {:ensure => 'held'}
      when '-'
        {}
      else
        raise ArgumentError, 'Unknown format %s: %s[%s]' % [self.name, flags, flags[1..1]]
      end
    )
  end

  # The UFOXI field is the field present in the older pkg
  # (solaris 2009.06 - snv151a)
  # similar to IFO, UFOXI is also an either letter or -
  # u_pdate indicates that an update for the package is available.
  # f_rozen(n/i) o_bsolete x_cluded(n/i) i_constrained(n/i)
  # note that u_pdate flag may not be trustable due to constraints.
  # so we dont rely on it
  # Frozen was never implemented in UFOXI so skipping frozen here.
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
      {:status => 'installed'}
    when /known/
      {:status => 'known'}
    else
      raise ArgumentError, 'Unknown format %s: %s' % [self.name, state]
    end
  end

  # Here is (hopefully) the only place we will have to deal with multiple
  # formats of output for different pkg versions.
  def self.parse_line(line)
    (case line.chomp
    # NAME (PUBLISHER)            VERSION           IFO  (new:630e1ffc7a19)
    # system/core-os              0.5.11-0.169      i--
    when /^(\S+) +(\S+) +(...)$/
      {:name => $1, :ensure => $2}.merge ifo_flag($3)

    # x11/wm/fvwm (fvwm.org)      2.6.1-3           i--
    when /^(\S+) \((.+)\) +(\S+) +(...)$/
      {:name => $1, :publisher => $2, :ensure => $3}.merge ifo_flag($4)

    # NAME (PUBLISHER)                  VERSION          STATE      UFOXI (dvd:052adf36c3f4)
    # SUNWcs                            0.5.11-0.126     installed  -----
    when /^(\S+) +(\S+) +(\S+) +(.....)$/
      {:name => $1, :ensure => $2}.merge pkg_state($3).merge(ufoxi_flag($4))

    # web/firefox/plugin/flash (extra)  10.0.32.18-0.111 installed  -----
    when /^(\S+) \((.+)\) +(\S+) +(\S+) +(.....)$/
      {:name => $1, :publisher => $2, :ensure => $3}.merge pkg_state($4).merge(ufoxi_flag($5))

    else
      raise ArgumentError, 'Unknown line format %s: %s' % [self.name, line]
    end).merge({:provider => self.name})
  end

  def hold
    pkg(:freeze, @resource[:name])
  end

  def unhold
    r = exec_cmd(command(:pkg), 'unfreeze', @resource[:name])
    raise Puppet::Error, "Unable to unfreeze #{r[:out]}" unless [0,4].include? r[:exit]
  end

  # Return the version of the package. Note that the bug
  # http://defect.opensolaris.org/bz/show_bug.cgi?id=19159%
  # notes that we can't use -Ha for the same even though the manual page reads that way.
  def latest
    lst = pkg(:list, "-Hn", @resource[:name]).split("\n").map{|l|self.class.parse_line(l)}

    # Now we know there is a newer version. But is that installable? (i.e are there any constraints?)
    # return the first known we find. The only way that is currently available is to do a dry run of
    # pkg update and see if could get installed (`pkg update -n res`).
    known = lst.find {|p| p[:status] == 'known' }
    return known[:ensure] if known and exec_cmd(command(:pkg), 'update', '-n', @resource[:name])[:exit].zero?

    # If not, then return the installed, else nil
    (lst.find {|p| p[:status] == 'installed' } || {})[:ensure]
  end

  # install the package and accept all licenses.
  def install(nofail = false)
    name = @resource[:name]
    should = @resource[:ensure]
    # always unhold if explicitly told to install/update
    self.unhold
    unless should.is_a? Symbol
      name += "@#{should}"
      is = self.query
      unless is[:ensure].to_sym == :absent
        self.uninstall if Puppet::Util::Package.versioncmp(should, is[:ensure]) < 0
      end
    end
    r = exec_cmd(command(:pkg), 'install', '--accept', name)
    return r if nofail
    raise Puppet::Error, "Unable to update #{r[:out]}" if r[:exit] != 0
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
    r = install(true)
    # 4 == /No updates available for this image./
    return if [0,4].include? r[:exit]
    raise Puppet::Error, "Unable to update #{r[:out]}"
  end

  # list a specific package
  def query
    r = exec_cmd(command(:pkg), 'list', '-H', @resource[:name])
    return {:ensure => :absent, :name => @resource[:name]} if r[:exit] != 0
    self.class.parse_line(r[:out])
  end

  def exec_cmd(*cmd)
    output = Puppet::Util::Execution.execute(cmd, :failonfail => false, :combine => true)
    {:out => output, :exit => $CHILD_STATUS.exitstatus}
  end
end
