module Puppet
  module SSL
    class CertificateAuthority
      # This class is basically a hidden class that knows how to act on the
      # CA.  Its job is to provide a CLI-like interface to the CA class.
      class Interface
        INTERFACE_METHODS = [:destroy, :list, :revoke, :generate, :sign, :print, :verify, :fingerprint, :reinventory]
        DESTRUCTIVE_METHODS = [:destroy, :revoke]
        SUBJECTLESS_METHODS = [:list, :reinventory]

        CERT_STATUS_GLYPHS = {:signed => '+', :request => ' ', :invalid => '-'}
        VALID_CONFIRMATION_VALUES = %w{y Y yes Yes YES}

        class InterfaceError < ArgumentError; end

        attr_reader :method, :subjects, :digest, :options

        # Actually perform the work.
        def apply(ca)
          unless subjects || SUBJECTLESS_METHODS.include?(method)
            raise ArgumentError, "You must provide hosts or --all when using #{method}"
          end

          destructive_subjects = [:signed, :all].include?(subjects)
          if DESTRUCTIVE_METHODS.include?(method) && destructive_subjects
            subject_text = (subjects == :all ? subjects : "all signed")
            raise ArgumentError, "Refusing to #{method} #{subject_text} certs, provide an explicit list of certs to #{method}"
          end

          # if the interface implements the method, use it instead of the ca's method
          if respond_to?(method)
            send(method, ca)
          else
            (subjects == :all ? ca.list : subjects).each do |host|
              ca.send(method, host)
            end
          end
        end

        def generate(ca)
          raise InterfaceError, "It makes no sense to generate all hosts; you must specify a list" if subjects == :all

          subjects.each do |host|
            ca.generate(host, options)
          end
        end

        def initialize(method, options)
          self.method = method
          self.subjects = options.delete(:to)
          @digest = options.delete(:digest)
          @options = options
        end

        # List the hosts.
        def list(ca)
          signed = ca.list if [:signed, :all].include?(subjects)
          requests = ca.waiting?

          case subjects
          when :all
            hosts = [signed, requests].flatten
          when :signed
            hosts = signed.flatten
          when nil
            hosts = requests
          else
            hosts = subjects
            signed = ca.list(hosts)
          end

          certs = {:signed => {}, :invalid => {}, :request => {}}

          return if hosts.empty?

          hosts.uniq.sort.each do |host|
            verify_error = nil

            begin
              ca.verify(host) unless requests.include?(host)
            rescue Puppet::SSL::CertificateAuthority::CertificateVerificationError => details
              verify_error = "(#{details.to_s})"
            end

            if verify_error
              type = :invalid
              cert = Puppet::SSL::Certificate.indirection.find(host)
            elsif (signed and signed.include?(host))
              type = :signed
              cert = Puppet::SSL::Certificate.indirection.find(host)
            else
              type = :request
              cert = Puppet::SSL::CertificateRequest.indirection.find(host)
            end

            certs[type][host] = {
              :cert         => cert,
              :type         => type,
              :verify_error => verify_error,
            }
          end

          names = certs.values.map(&:keys).flatten

          name_width = names.sort_by(&:length).last.length rescue 0
          # We quote these names, so account for those characters
          name_width += 2

          output = [:request, :signed, :invalid].map do |type|
            next if certs[type].empty?

            certs[type].map do |host, info|
              format_host(host, info, name_width, options[:format])
            end
          end.flatten.compact.sort.join("\n")

          puts output
        end

        def format_host(host, info, width, format)
          case format
          when :machine
            machine_host_formatting(host, info)
          when :human
            human_host_formatting(host, info)
          else
            if options[:verbose]
              machine_host_formatting(host, info)
            else
              legacy_host_formatting(host, info, width)
            end
          end
        end

        def machine_host_formatting(host, info)
          type         = info[:type]
          verify_error = info[:verify_error]
          cert         = info[:cert]
          alt_names    = cert.subject_alt_names - [host]
          extensions   = format_attrs_and_exts(cert)

          glyph       = CERT_STATUS_GLYPHS[type]
          name        = host.inspect
          fingerprint = cert.digest(@digest).to_s

          expiration  = cert.expiration.iso8601 if type == :signed

          if type != :invalid
            if !alt_names.empty?
              extensions.unshift("alt names: #{alt_names.map(&:inspect).join(', ')}")
            end

            if !extensions.empty?
              metadata_string = "(#{extensions.join(', ')})" unless extensions.empty?
            end
          end

          [glyph, name, fingerprint, expiration, metadata_string, verify_error].compact.join(' ')
        end

        def human_host_formatting(host, info)
          type         = info[:type]
          verify_error = info[:verify_error]
          cert         = info[:cert]
          alt_names    = cert.subject_alt_names - [host]
          extensions   = format_attrs_and_exts(cert)

          glyph       = CERT_STATUS_GLYPHS[type]
          fingerprint = cert.digest(@digest).to_s

          if type == :invalid || (extensions.empty? && alt_names.empty?)
            extension_string = ''
          else
            if !alt_names.empty?
              extensions.unshift("alt names: #{alt_names.map(&:inspect).join(', ')}")
            end

            extension_string = "\n    Extensions:\n      "
            extension_string << extensions.join("\n      ")
          end

          if type == :signed
            expiration_string = "\n    Expiration: #{cert.expiration.iso8601}"
          else
            expiration_string = ''
          end

          status = case type
                   when :invalid then "Invalid - #{verify_error}"
                   when :request then "Request Pending"
                   when :signed then "Signed"
                   end

          output = "#{glyph} #{host.inspect}"
          output << "\n  #{fingerprint}"
          output << "\n    Status: #{status}"
          output << expiration_string
          output << extension_string
          output << "\n"

          output
        end

        def legacy_host_formatting(host, info, width)
          type         = info[:type]
          verify_error = info[:verify_error]
          cert         = info[:cert]
          alt_names    = cert.subject_alt_names - [host]
          extensions   = format_attrs_and_exts(cert)

          glyph       = CERT_STATUS_GLYPHS[type]
          name        = host.inspect.ljust(width)
          fingerprint = cert.digest(@digest).to_s

          if type != :invalid
            if alt_names.empty?
              alt_name_string = nil
            else
              alt_name_string = "(alt names: #{alt_names.map(&:inspect).join(', ')})"
            end

            if extensions.empty?
              extension_string = nil
            else
              extension_string = "**"
            end
          end

          [glyph, name, fingerprint, alt_name_string, verify_error, extension_string].compact.join(' ')
        end

        def format_attrs_and_exts(cert)
          exts = []
          exts += cert.custom_extensions if cert.respond_to?(:custom_extensions)
          exts += cert.custom_attributes if cert.respond_to?(:custom_attributes)
          exts += cert.request_extensions if cert.respond_to?(:request_extensions)

          exts.map {|e| "#{e['oid']}: #{e['value'].inspect}" }.sort
        end

        # Set the method to apply.
        def method=(method)
          raise ArgumentError, "Invalid method #{method} to apply" unless INTERFACE_METHODS.include?(method)
          @method = method
        end

        # Print certificate information.
        def print(ca)
          (subjects == :all ? ca.list  : subjects).each do |host|
            if value = ca.print(host)
              puts value
            else
              raise ArgumentError, "Could not find certificate for #{host}"
            end
          end
        end

        # Print certificate information.
        def fingerprint(ca)
          (subjects == :all ? ca.list + ca.waiting?: subjects).each do |host|
            if cert = (Puppet::SSL::Certificate.indirection.find(host) || Puppet::SSL::CertificateRequest.indirection.find(host))
              puts "#{host} #{cert.digest(@digest)}"
            else
	      raise ArgumentError, "Could not find certificate for #{host}"
            end
          end
        end

        # Signs given certificates or all waiting if subjects == :all
        def sign(ca)
          list = subjects == :all ? ca.waiting? : subjects
          raise InterfaceError, "No waiting certificate requests to sign" if list.empty?

          signing_options = options.select { |k,_|
            [:allow_authorization_extensions, :allow_dns_alt_names].include?(k)
          }

          list.each do |host|
            cert = Puppet::SSL::CertificateRequest.indirection.find(host)

            raise InterfaceError, "Could not find CSR for: #{host.inspect}." unless cert

            # ca.sign will also do this - and it should if it is called
            # elsewhere - but we want to reject an attempt to sign a
            # problematic csr as early as possible for usability concerns.
            ca.check_internal_signing_policies(host, cert, signing_options)

            name_width = host.inspect.length
            info = {:type => :request, :cert => cert}
            host_string = format_host(host, info, name_width, options[:format])
            puts "Signing Certificate Request for:\n#{host_string}"

            if options[:interactive]
              STDOUT.print "Sign Certificate Request? [y/N] "

              if !options[:yes]
                input = STDIN.gets.chomp
                raise InterfaceError, "NOT Signing Certificate Request" unless VALID_CONFIRMATION_VALUES.include?(input)
              else
                puts "Assuming YES from `-y' or `--assume-yes' flag"
              end
            end

            ca.sign(host, signing_options)
          end
        end

        def reinventory(ca)
          ca.inventory.rebuild
        end

        # Set the list of hosts we're operating on.  Also supports keywords.
        def subjects=(value)
          unless value == :all || value == :signed || value.is_a?(Array)
            raise ArgumentError, "Subjects must be an array or :all; not #{value}"
          end

          @subjects = (value == []) ? nil : value
        end
      end
    end
  end
end

