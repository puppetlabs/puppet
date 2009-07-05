# This class is basically a hidden class that knows how to act
# on the CA.  It's only used by the 'puppetca' executable, and its
# job is to provide a CLI-like interface to the CA class.
class Puppet::SSL::CertificateAuthority::Interface
    INTERFACE_METHODS = [:destroy, :list, :revoke, :generate, :sign, :print, :verify]

    class InterfaceError < ArgumentError; end

    attr_reader :method, :subjects

    # Actually perform the work.
    def apply(ca)
        unless subjects or method == :list
            raise ArgumentError, "You must provide hosts or :all when using %s" % method
        end

        begin
            if respond_to?(method)
                return send(method, ca)
            end

            (subjects == :all ? ca.list : subjects).each do |host|
                ca.send(method, host)
            end
        rescue InterfaceError
            raise
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Could not call %s: %s" % [method, detail]
        end
    end

    def generate(ca)
        raise InterfaceError, "It makes no sense to generate all hosts; you must specify a list" if subjects == :all

        subjects.each do |host|
            ca.generate(host)
        end
    end

    def initialize(method, subjects)
        self.method = method
        self.subjects = subjects
    end

    # List the hosts.
    def list(ca)
        unless subjects
            puts ca.waiting?.join("\n")
            return nil
        end

        signed = ca.list
        requests = ca.waiting?

        if subjects == :all
            hosts = [signed, requests].flatten
        else
            hosts = subjects
        end

        hosts.uniq.sort.each do |host|
            invalid = false
            begin
                ca.verify(host) unless requests.include?(host)
            rescue Puppet::SSL::CertificateAuthority::CertificateVerificationError => details
                invalid = details.to_s
            end
            if not invalid and signed.include?(host)
                puts "+ " + host
            elsif invalid
                puts "- " + host + " (" + invalid + ")"
            else
                puts host
            end
        end
    end

    # Set the method to apply.
    def method=(method)
        raise ArgumentError, "Invalid method %s to apply" % method unless INTERFACE_METHODS.include?(method)
        @method = method
    end

    # Print certificate information.
    def print(ca)
        (subjects == :all ? ca.list : subjects).each do |host|
            if value = ca.print(host)
                puts value
            else
                Puppet.err "Could not find certificate for %s" % host
            end
        end
    end

    # Sign a given certificate.
    def sign(ca)
        list = subjects == :all ? ca.waiting? : subjects
        raise InterfaceError, "No waiting certificate requests to sign" if list.empty?
        list.each do |host|
            ca.sign(host)
        end
    end

    # Set the list of hosts we're operating on.  Also supports keywords.
    def subjects=(value)
        unless value == :all or value.is_a?(Array)
            raise ArgumentError, "Subjects must be an array or :all; not %s" % value
        end

        if value.is_a?(Array) and value.empty?
            value = nil
        end

        @subjects = value
    end
end

