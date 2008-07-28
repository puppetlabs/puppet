require 'puppet/network'

module Puppet::Network::FormatHandler
    def self.extended(klass)
        klass.extend(ClassMethods)

        # LAK:NOTE This won't work in 1.9 ('send' won't be able to send
        # private methods, but I don't know how else to do it.
        klass.send(:include, InstanceMethods)
    end

    module ClassMethods
        def convert_from(format, data)
            raise ArgumentError, "Format %s not supported" % format unless support_format?(format)
            send("from_%s" % format, data)
        end

        def convert_from_multiple(format, data)
            if respond_to?("from_multiple_%s" % format)
                send("from_multiple_%s" % format, data)
            else
                convert_from(format, data)
            end
        end

        def render_multiple(format, instances)
            if respond_to?("to_multiple_%s" % format)
                send("to_multiple_%s" % format, instances)
            else
                instances.send("to_%s" % format)
            end
        end

        def default_format
            supported_formats[0]
        end

        def support_format?(name)
            respond_to?("from_%s" % name) and instance_methods.include?("to_%s" % name)
        end

        def supported_formats
            instance = instance_methods.collect { |m| m =~ /^to_(.+)$/ and $1 }.compact
            klass = methods.collect { |m| m =~ /^from_(.+)$/ and $1 }.compact

            # Return the intersection of the two lists.
            return instance & klass
        end
    end

    module InstanceMethods
        def render(format = nil)
            if format
                raise ArgumentError, "Format %s not supported" % format unless support_format?(format)
            else
                format = self.class.default_format
            end

            send("to_%s" % format)
        end

        def support_format?(name)
            self.class.support_format?(name)
        end
    end
end
