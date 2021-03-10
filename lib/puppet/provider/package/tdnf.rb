Puppet::Type.type(:package).provide :tdnf, :parent => :dnf do
  desc "Support via `tdnf`.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to tdnf.
  These options should be spcified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}), or an
  array where each element is either a string or a hash."

  has_feature :install_options, :versionable, :virtual_packages

  commands :cmd => "tdnf", :rpm => "rpm"

  # Note: this confine was borrowed from the Yum provider. The
  # original purpose (from way back in 2007) was to make sure we
  # never try to use RPM on a machine without it. We think this
  # has probably become obsolete with the way `commands` work, so
  # we should investigate removing it at some point.
  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end

  defaultfor :operatingsystem => "PhotonOS" 
end
