module Puppet
  # Simple module to manage vendored code.
  #
  # To vendor a library:
  #
  # * Download its whole git repo or untar into `lib/puppet/vendor/<libname>`
  # * Create a vendor/puppetload_libraryname.rb file to add its libdir into the $:.
  #   (Look at existing load_xxx files, they should all follow the same pattern).
  # * Add a <libname>/PUPPET_README.md file describing what the library is for
  #   and where it comes from.
  # * To load the vendored lib upfront, add a `require '<vendorlib>'`line to
  #   `vendor/require_vendored.rb`.
  # * To load the vendored lib on demand, add a comment to `vendor/require_vendored.rb`
  #    to make it clear it should not be loaded upfront.
  #
  # At runtime, the #load_vendored method should be called. It will ensure
  # all vendored libraries are added to the global `$:` path, and
  # will then call execute the up-front loading specified in `vendor/require_vendored.rb`.
  #
  # The intention is to not change vendored libraries and to eventually
  # make adding them in optional so that distros can simply adjust their
  # packaging to exclude this directory and the various load_xxx.rb scripts
  # if they wish to install these gems as native packages.
  #
  class Vendor
    class << self
      # @api private
      def vendor_dir
        File.join([File.dirname(File.expand_path(__FILE__)), "vendor"])
      end

      # @api private
      def load_entry(entry)
        Puppet.debug("Loading vendored #{$1}")
        load "#{vendor_dir}/#{entry}"
      end

      # @api private
      def require_libs
        require 'puppet/vendor/require_vendored'
      end

      # Configures the path for all vendored libraries and loads required libraries.
      # (This is the entry point for loading vendored libraries).
      #
      def load_vendored
        Dir.entries(vendor_dir).each do |entry|
          if entry.match(/load_(\w+?)\.rb$/)
            load_entry entry
          end
        end

        require_libs
      end
    end
  end
end
