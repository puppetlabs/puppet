require 'puppet/util/json'
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

      super(_("Unable to verify the SSL certificate at %{uri}") % { uri: @uri }, original)
    end

    # Return a multiline version of the error message
    #
    # @return [String] the multiline version of the error message
    def multiline
      message = []
      message << _('Could not connect via HTTPS to %{uri}') % { uri: @uri }
      message << _('  Unable to verify the SSL certificate')
      message << _('    The certificate may not be signed by a valid CA')
      message << _('    The CA bundle included with OpenSSL may not be valid or up to date')
      message.join("\n")
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

      message = _("Unable to connect to the server at %{uri}. Detail: %{detail}.") % { uri: @uri, detail: @detail }
      super(message, original)
    end

    # Return a multiline version of the error message
    #
    # @return [String] the multiline version of the error message
    def multiline
      message = []
      message << _('Could not connect to %{uri}') % { uri: @uri }
      message << _('  There was a network communications problem')
      message << _("    The error we caught said '%{detail}'") % { detail: @detail }
      message << _('    Check your network connection and try again')
      message.join("\n")
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
        body = Puppet::Util::Json.load(response.body)
        if body['message']
          @message ||= body['message'].strip
        end
      rescue Puppet::Util::Json::ParseError
      end

      message = if @message
                  _("Request to Puppet Forge failed.") + ' ' + _("Detail: %{detail}.") % { detail: "#{@message} / #{@response}" }
                else
                  _("Request to Puppet Forge failed.") + ' ' + _("Detail: %{detail}.") % { detail: @response }
                end
      super(message, original)
    end

    # Return a multiline version of the error message
    #
    # @return [String] the multiline version of the error message
    def multiline

      message = []
      message << _('Request to Puppet Forge failed.')
      message << _('  The server being queried was %{uri}') % { uri: @uri }
      message << _("  The HTTP response we received was '%{response}'") % { response: @response }
      message << _("  The message we received said '%{message}'") % { message: @message } if @message
      message.join("\n")
    end
  end

end
