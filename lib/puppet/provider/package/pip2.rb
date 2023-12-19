# frozen_string_literal: true

# Puppet package provider for Python's `pip2` package management frontend.
# <http://pip.pypa.io/>

Puppet::Type.type(:package).provide :pip2,
                                    :parent => :pip do
  desc "Python packages via `pip2`.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip2.
  These options should be specified as an array where each element is either a string or a hash."

  has_feature :installable, :uninstallable, :upgradeable, :versionable, :install_options, :targetable

  def self.cmd
    ["pip2"]
  end
end
