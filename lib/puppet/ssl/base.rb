require 'puppet/ssl'

# The base class for wrapping SSL instances.
class Puppet::SSL::Base
    def self.wraps(klass)
        @wrapped_class = klass
    end

    def self.wrapped_class
        raise(Puppet::DevError, "%s has not declared what class it wraps" % self) unless defined?(@wrapped_class)
        @wrapped_class
    end

    attr_accessor :name, :content

    def generate
        raise Puppet::DevError, "%s did not override 'generate'" % self.class
    end

    def initialize(name)
        @name = name
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

    private

    def wrapped_class
        self.class.wrapped_class
    end
end
