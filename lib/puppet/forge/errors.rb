# Puppet::Forge specific exceptions
module Puppet::Forge::Errors

  # This exception is the parent for all Forge API errors
  class ForgeError < StandardError
    # This is normally set by the child class, but if it is not this will
    # fall back to displaying the message as a multiline.
    def multiline
      self.message
    end
  end

  # This exception is raised when there is an SSL verification error when
  # communicating with the forge.
  #
  # @option options [String] :uri The URI that failed
  class SSLVerifyError < ForgeError
    def initialize(options)
      @uri    = options[:uri]

      super "Unable to verify the SSL certificate at #{@uri}"
    end

    # A multiline version of the error message
    def multiline
      message = <<-EOS.chomp
Unable to verify the SSL certificate at #{@uri}
  This could be because the certificate is invalid or that the CA bundle
  installed with your version of OpenSSL is not available, not valid or
  not up to date.
      EOS
    end
  end

  # This exception is raised when there is a communication error when connecting
  # to the forge
  #
  # @option options [String] :uri The URI that failed
  class CommunicationError < ForgeError
    def initialize(options)
      @uri    = options[:uri]

      super "Unable to connect to the server at #{@uri}"
    end

    # A multiline version of the error message
    def multiline
      message = <<-EOS.chomp
Could not connect to #{@uri}
  There was a network communications problem
    Check your network connection and try again
      EOS
    end
  end

end
