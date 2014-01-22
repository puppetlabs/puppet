require 'puppet/util/package'
require 'puppet/util/package/ports/record'

module Puppet::Util::Package::Ports

# Represents single data record returned by {PkgSearch#search_packages}.
#
# This is a kind of hash to hold results obtained from `portversion` command.
class PkgRecord < ::Puppet::Util::Package::Ports::Record

  # These fields may be obtained directly from {PkgSearch#search_packages}
  # without doing {#amend!}. See also {Record.std_fields}.
  def self.std_fields
    [
      :pkgname,
      :portorigin,
      :portstatus,
      :portinfo
    ]
  end

  # Default set of fields requested from {PkgSearch#search_packages}. See also
  # {Record.default_fields}.
  def self.default_fields
    [
      :pkgname,
      :portname,
      :portorigin,
      :pkgversion,
      :portstatus,
      :portinfo,
      :options,
      :options_file,
      :options_files
    ]
  end

  # If we want {#amend!} to add extra fields to PkgRecord we must first
  # ensure that we request certain fields from {PkgSearch#search_packages}. For
  # example, to determine `:pkgversion` field, one needs to have the `:pkgname`
  # field in the `portversion`s search result.
  #
  # The following hash describes these dependencies. See also
  # {Record.deps_for_amend}.
  #
  # See [portversion(1)](http://www.freebsd.org/cgi/man.cgi?query=portversion&manpath=ports&sektion=1)
  # for more information about `portversion`.
  def self.deps_for_amend
    {
      :options        => [:portname, :portorigin],
      :options_file   => [:portname, :portorigin],
      :options_files  => [:portname, :portorigin],
      :pkgversion     => [:pkgname],
    }
  end

  # Add extra fields to an already existing PkgRecord.
  #
  # Most of the extra fields that can be added do not introduce any new
  # information in fact - they're just computed from already existing fields.
  # The exception is the `:options` field. Options are loaded from existing
  # port options files (`/var/db/ports/*/options{,.local}).
  #
  # @param fields [Array] list of fields to be included in output
  # @return self
  #
  def amend!(fields)
    if self[:pkgname]
      self[:portname], self[:pkgversion] = self.class.split_pkgname(self[:pkgname])
    end
    super
  end

end
end
