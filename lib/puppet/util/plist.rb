require 'cfpropertylist'
module Puppet::Util::Plist
  # So I don't have to prepend every method name with 'self.' Most of the
  # methods are going to be Provider methods (as opposed to methods of the
  # INSTANCE of the provider).
  class << self
    # Defines the magic number for binary plists
    #
    # @api private
    def binary_plist_magic_number
      "bplist00"
    end

    # Defines a default doctype string that should be at the top of most plist
    # files. Useful if we need to modify an invalid doctype string in memory.
    # I'm looking at you, /System/Library/LaunchDaemons/org.ntp.ntpd.plist,
    # you bastard.
    def plist_xml_doctype
      '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    end

    # Read a plist, whether its format is XML or in Apple's "binary1"
    # format, using the CFPropertyList gem.
    def read_plist_file(file_path)
      bad_xml_doctype = /^.*<!DOCTYPE plist PUBLIC -\/\/Apple Computer.*$/
      # We can't really read the file until we know the source encoding in
      # Ruby 1.9.x, so we use the magic number to detect it.
      # NOTE: We need to use IO.read to be Ruby 1.8.x compatible.
      if IO.read(file_path, binary_plist_magic_number.length) == binary_plist_magic_number
        plist_obj = CFPropertyList::List.new(:file => file_path)
      else
        plist_data = File.open(file_path, "r:UTF-8").read
        if plist_data =~ bad_xml_doctype
          plist_data.gsub!( bad_xml_doctype, plist_xml_doctype )
          Puppet.debug("Had to fix plist with incorrect DOCTYPE declaration: #{file_path}")
        end
        begin
          # This is fucking terrible - I'm redirecting $stderr because I
          # can't swallow an error bubbled up by libxml when the file
          # /System/Library/LaunchDaemons/org.cups.cupsd.plist tries to
          # be parsed. That file has invalid double hyphens within an XML
          # comment, and even though the file passes `plutil -lint`, it's
          # invalid XML. It's been that way for fucking ever and it sucks.
          # I would REALLY appreciate a pull request to handle this better.
          orig_stderr = $stderr.clone
          $stderr.reopen('/dev/null', 'w+')
          plist_obj = CFPropertyList::List.new(:data => plist_data)
          $stderr.reopen(orig_stderr)
        rescue CFFormatError, LibXML::XML::Error => e
          Puppet.debug "Failed with #{e.class} on #{file_path}: #{e.inspect}"
          return nil
        end
      end
      CFPropertyList.native_types(plist_obj.value)
    end

    # This method will write a plist file using a specified format (or XML
    # by default)
    def write_plist_file(plist, file_path, format = 'xml')
      if format == 'xml'
        plist_format = CFPropertyList::List::FORMAT_XML
      else
        plist_format = CFPropertyList::List::FORMAT_BINARY
      end

      begin
        plist_to_save       = CFPropertyList::List.new
        plist_to_save.value = CFPropertyList.guess(plist)
        plist_to_save.save(file_path, plist_format)
      rescue IOError => e
        fail("Unable to write the file #{file_path}.  #{e.inspect}")
      end
    end
  end
end
