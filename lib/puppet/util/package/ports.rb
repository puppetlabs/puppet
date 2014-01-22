require 'facter'
require 'puppet/util/package'
require 'puppet/util/package/ports/port_search'
require 'puppet/util/package/ports/pkg_search'


# Utilities for FreeBSD ports.
#
# This module includes {PortSearch} and {PkgSearch} modules to help searching
# through ports and packages.
#
# ### Short introduction
#
# On BSD system we have these two "databases":
#
# 1. Ports - index of source packages ready to compile and install.
# 2. Packages - index of binary (installed) packages (includes installed ports).
#
# ### Functionality of PortSearch and PkgSearch
#
# The {PortSearch} module provides methods that facilitate searching ports
# INDEX for information describing available ports. The {PkgSearch} module
# provides method that facilitate searching the database of installed packages.
# It supports the old
# [pkg](http://www.freebsd.org/doc/handbook/packages-using.html) database and
# the new [pkgng](http://www.freebsd.org/doc/handbook/pkgng-intro.html).
# Search methods in both modules are designed such that they yield one *record*
# for each package found in database. The returned record is either
# {PortRecord} object (for {PortSearch}) or {PkgRecord} (for {PkgSearch}). The
# record is basically a `{:field=>value}` hash (the record classes inherit from
# `Hash`), but it also provides some additional methods. Example fields that
# may be found in a record are `:name`, `:pkgname`, `:portorigin`, `:path`,
# etc..
#
# Searches are customizable. You may, for example, specify what fields should
# be included in search results (in records).
# 
# You may search ports INDEX by *pkgname*, *portname*, by *portorigin*, or
# (with a little extra effort) perform a custom search by any key supported by
# the *make search* command (see
# [ports(7)](http://www.freebsd.org/cgi/man.cgi?query=ports&sektion=7)). You
# may also perform a heuristic search *by name* without stating whether the
# *name* represents *pkgname*, *portname* or *portorigin*  (see
# {#search_ports}).
# 
# Installed packages may be searched by *name* (the list of names is passed
# directly
# [portversion(1)](http://www.freebsd.org/cgi/man.cgi?query=portversion&manpath=ports&sektion=1)).
# It's also easy to retrieve information about __all__ installed packages.
#
# ### Ports' build options
# 
# When compiling FreeBSD ports, the user has possibility to set some build
# options with *make config* command. Here, the same build options may be
# easily manipulated with {Options} class. The {Options} object represents
# a set of options for a single *port/package*. The options are implemented
# as a hash with simple key/value validation and munging. They may be read from
# or written to options files - the ones that normally lay under
# */var/db/ports/*.
#
# ### FreeBSD ports collection and its terminology
# 
# Ports and packages in FreeBSD may be identified by either *portnames*,
# *pkgnames* or *portorigins*. We use the following terminology when referring
# ports/packages:
# 
#   * a string in form `'apache22'` or `'ruby'` is referred to as *portname*
#   * a string in form `'apache22-2.2.25'` or `'ruby-1.8.7.371,1'` is referred to
#     as a *pkgname*
#   * a string in form `'www/apache22'` or `'lang/ruby18'` is referred to as a
#     port *origin* or *portorigin*
# 
# See [http://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html](http://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html)
#
module Puppet::Util::Package::Ports

  include PortSearch
  include PkgSearch

end
