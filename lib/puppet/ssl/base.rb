require 'puppet/ssl'

# The base class for wrapping SSL instances.
class Puppet::SSL::Base
    # For now, use the YAML separator.
    SEPARATOR = "\n---\n"

    def self.from_multiple_s(text)
        text.split(SEPARATOR).collect { |inst| from_s(inst) }
    end

    def self.to_multiple_s(instances)
        instances.collect { |inst| inst.to_s }.join(SEPARATOR)
    end

    def self.wraps(klass)
        @wrapped_class = klass
    end

    def self.wrapped_class
        raise(Puppet::DevError, "%s has not declared what class it wraps" % self) unless defined?(@wrapped_class)
        @wrapped_class
    end

    attr_accessor :name, :content

    # Is this file for the CA?
    def ca?
        name == Puppet::SSL::Host.ca_name
    end

    def generate
        raise Puppet::DevError, "%s did not override 'generate'" % self.class
    end

    def initialize(name)
        @name = name.to_s.downcase
    end

    # Read content from disk appropriately.
    def read(path)
        @content = wrapped_class.new(File.read(path))
    end

    # Convert our thing to pem.
    def to_s
        return "" unless content
        content.to_pem
    end

    # Provide the full text of the thing we're dealing with.
    def to_text
        return "" unless content
        content.to_text
    end

    private

    def wrapped_class
        self.class.wrapped_class
    end
end
