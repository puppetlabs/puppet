Puppet::Type.type(:package).provide :dnf, :parent => :yum do
  desc "Support via `dnf`.

  Using this provider's `uninstallable` feature will not remove dependent packages. To
  remove dependent packages with this provider use the `purgeable` feature, but note this
  feature is destructive and should be used with the utmost care.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to dnf.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  has_feature :install_options, :versionable, :virtual_packages

  commands :cmd => "dnf", :rpm => "rpm"

  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end

  defaultfor :operatingsystem => :fedora, :operatingsystemmajrelease => '22'

  # The value to pass to DNF as its error output level.
  # DNF differs from Yum slightly with regards to error outputting.
  #
  # @param None
  # @return [String]
  def self.error_level
    '1'
  end
end
