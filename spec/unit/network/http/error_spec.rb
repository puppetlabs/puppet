require 'spec_helper'
require 'matchers/json'

require 'puppet/network/http'

describe Puppet::Network::HTTP::Error do
  include JSONMatchers

  describe Puppet::Network::HTTP::Error::HTTPError do
    it "should serialize to JSON that matches the error schema" do
      error = Puppet::Network::HTTP::Error::HTTPError.new("I don't like the looks of you", 400, :SHIFTY_USER)

      expect(error.to_json).to validate_against('api/schemas/error.json')
    end
  end

  describe Puppet::Network::HTTP::Error::HTTPServerError do
    it "should serialize to JSON that matches the error schema" do
      begin
        raise Exception, "a wild Exception appeared!"
      rescue Exception => e
        culpable = e
      end
      error = Puppet::Network::HTTP::Error::HTTPServerError.new(culpable)

      expect(error.to_json).to validate_against('api/schemas/error.json')
    end
  end

end
