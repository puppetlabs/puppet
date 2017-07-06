require 'json'
require 'puppet/error'
require 'puppet/forge'

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
      <<-EOS.chomp
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
      <<-EOS.chomp
Could not connect to #{@uri}
  There was a network communications problem
    The error we caught said '#{@detail}'
    Check your network connection and try again
      EOS
    end
  end

  # This exception is raised when there is a bad HTTP response from the forge
  # and optionally a message in the response.
  class ResponseError < ForgeError
    # @option options [String] :uri The URI that failed
    # @option options [String] :input The user's input (e.g. module name)
    # @option options [String] :message Error from the API response (optional)
    # @option options [Net::HTTPResponse] :response The original HTTP response
    def initialize(options)
      @uri     = options[:uri]
      @message = options[:message]
      response = options[:response]
      @response = "#{response.code} #{response.message.strip}"

      begin
        body = JSON.parse(response.body)
        if body['message']
          @message ||= body['message'].strip
        end
      rescue JSON::ParserError
      end

      message = "Request to Puppet Forge failed. Detail: "
      message << @message << " / " if @message
      message << @response << "."
      super(message, original)
    end

    # Return a multiline version of the error message
    #
    # @return [String] the multiline version of the error message
    def multiline
      message = <<-EOS.chomp
Request to Puppet Forge failed.
  The server being queried was #{@uri}
  The HTTP response we received was '#{@response}'
      EOS
      message << "\n  The message we received said '#{@message}'" if @message
      message
    end
  end

end
