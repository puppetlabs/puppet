# For the Win #

This project is a small set of Rake tasks to automate the process of building
MSI packages for Puppet on Windows systems.

This is a separate repository because it is meant to build MSI packages for
arbitrary versions of Puppet, Facter and other related tools.

This project is meant to be checked out into a special Puppet Windows Dev Kit
directory structure.  This Dev Kit will provide the tooling necessary to
actually build the packages.

This project requires these tools from the `puppetbuilder` Dev Kit for Windows
systems.

 * Ruby
 * Rake
 * Git
 * 7zip
 * WiX

# Getting Started #

Given a basic Windows 2003 R2 x64 system with the [Puppet Win
Builder](http://links.puppetlabs.com/puppetwinbuilder) archive unpacked into
`C:/puppetwinbuilder/` the following are all that is required to build the MSI
packages.

    C:\>cd puppetwinbuilder
    C:\puppetwinbuilder\> build
    ...

(REVISIT - This is the thing we're working to.  Make sure this is accurate once
implemented)

# Making Changes #

The [Puppet Win Builder](http://links.puppetlabs.com/puppetwinbuilder) archive
should remain relatively static.  The purpose of this archive is simply to
bootstrap the tools required for the build process.

Changes to the build process itself should happen in the [Puppet For the
Win](https://github.com/puppetlabs/puppet_for_the_win) repository on Github.

# Continuous Integration #

The `build.bat` build script _should_ work just fine with a build system like
Jenkins.  If it does not, please let us know.

EOF
