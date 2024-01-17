# frozen_string_literal: true

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
  def find(request)
    raise NotImplementedError
  end

  def head(request)
    raise NotImplementedError
  end

  def search(request)
    raise NotImplementedError
  end

  def destroy(request)
    raise NotImplementedError
  end

  def save(request)
    raise NotImplementedError
  end

  def validate_key(request)
    # Validation happens on the remote end
  end

  private

  def convert_to_http_error(response)
    if response.body.to_s.empty? && response.reason
      returned_message = response.reason
    elsif response['content-type'].is_a?(String)
      content_type, body = parse_response(response)
      if content_type =~ /[pj]son/
        returned_message = Puppet::Util::Json.load(body)["message"]
      else
        returned_message = response.body
      end
    else
      returned_message = response.body
    end

    message = _("Error %{code} on SERVER: %{returned_message}") % { code: response.code, returned_message: returned_message }
    Net::HTTPError.new(message, Puppet::HTTP::ResponseConverter.to_ruby_response(response))
  end

  # Returns the content_type, stripping any appended charset, and the
  # body, decompressed if necessary
  def parse_response(response)
    if response['content-type']
      [response['content-type'].gsub(/\s*;.*$/, ''), response.body]
    else
      raise _("No content type in http response; cannot parse")
    end
  end

  def elide(string, length)
    if Puppet::Util::Log.level == :debug || string.length <= length
      string
    else
      string[0, length - 3] + "..."
    end
  end
end
