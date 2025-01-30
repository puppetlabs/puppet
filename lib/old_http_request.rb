require 'net/http'

module Net
  class HTTP
    alias old_request request
    def request(req, body = nil, &block)
      start unless started?
      old_request(req, body, &block)
    end
  end
end