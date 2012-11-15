require 'puppet/error'

# Puppet::Forge specific exceptions
module Puppet::Forge::Errors

  # This exception is the parent for all Forge API errors
  class ForgeError < Puppet::Error
    # This is normally set by the child class, but if it is not this will
    # fall back to displaying the message as a multiline.
    #
    # @return [String] the multiline version of the error message
    def multiline
      self.message
    end
  end

  # This exception is raised when there is an SSL verification error when
  # communicating with the forge.
  class SSLVerifyError < ForgeError
    # @option options [String] :uri The URI that failed
    # @option options [String] :original the original exception
    def initialize(options)
      @uri     = options[:uri]
      original = options[:original]

      super("Unable to verify the SSL certificate at #{@uri}", original)
    end

    # Return a multiline version of the error message
    #
    # @return [String] the multiline version of the error message
    def multiline
      message = <<-EOS.chomp
Could not connect via HTTPS to #{@uri}
  Unable to verify the SSL certificate
    The certificate may not be signed by a valid CA
    The CA bundle included with OpenSSL may not be valid or up to date
      EOS
    end
  end

  # This exception is raised when there is a communication error when connecting
  # to the forge
  class CommunicationError < ForgeError
    # @option options [String] :uri The URI that failed
    # @option options [String] :original the original exception
    def initialize(options)
      @uri     = options[:uri]
      original = options[:original]
      @detail  = original.message

      message = "Unable to connect to the server at #{@uri}. Detail: #{@detail}."
      super(message, original)
    end

    # Return a multiline version of the error message
    #
    # @return [String] the multiline version of the error message
    def multiline
      message = <<-EOS.chomp
Could not connect to #{@uri}
  There was a network communications problem
    The error we caught said '#{@detail}'
    Check your network connection and try again
      EOS
    end
  end

end
