module Puppet
  module SSL
    class CertificateAuthority
      # This class is basically a hidden class that knows how to act on the
      # CA.  Its job is to provide a CLI-like interface to the CA class.
      class Interface
        INTERFACE_METHODS = [:destroy, :list, :revoke, :generate, :sign, :print, :verify, :fingerprint, :reinventory]
        DESTRUCTIVE_METHODS = [:destroy, :revoke]
        SUBJECTLESS_METHODS = [:list, :reinventory]

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
            begin
              ca.verify(host) unless requests.include?(host)
            rescue Puppet::SSL::CertificateAuthority::CertificateVerificationError => details
              verify_error = details.to_s
            end

            if verify_error
              certs[:invalid][host] = [ Puppet::SSL::Certificate.indirection.find(host), verify_error ]
            elsif (signed and signed.include?(host))
              certs[:signed][host]  = Puppet::SSL::Certificate.indirection.find(host)
            else
              certs[:request][host] = Puppet::SSL::CertificateRequest.indirection.find(host)
            end
          end

          names = certs.values.map(&:keys).flatten

          name_width = names.sort_by(&:length).last.length rescue 0
          # We quote these names, so account for those characters
          name_width += 2

          output = [:request, :signed, :invalid].map do |type|
            next if certs[type].empty?

            certs[type].map do |host,info|
              format_host(ca, host, type, info, name_width)
            end
          end.flatten.compact.sort.join("\n")

          puts output
        end

        def format_host(ca, host, type, info, width)
          cert, verify_error = info
          alt_names = case type
                      when :signed
                        cert.subject_alt_names
                      when :request
                        cert.subject_alt_names
                      else
                        []
                      end

          alt_names.delete(host)

          alt_str = "(alt names: #{alt_names.map(&:inspect).join(', ')})" unless alt_names.empty?

          glyph = {:signed => '+', :request => ' ', :invalid => '-'}[type]

          name = host.inspect.ljust(width)
          fingerprint = cert.digest(@digest).to_s

          explanation = "(#{verify_error})" if verify_error

          [glyph, name, fingerprint, alt_str, explanation].compact.join(' ')
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

        # Signs given certificates or waiting of subjects == :all
        def sign(ca)
          list = subjects == :all ? ca.waiting? : subjects
          raise InterfaceError, "No waiting certificate requests to sign" if list.empty?
          list.each do |host|
            ca.sign(host, options[:allow_dns_alt_names])
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

