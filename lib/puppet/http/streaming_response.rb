class Puppet::HTTP::StreamingResponse < Puppet::HTTP::Response
  def read_body(&block)
    @nethttp.read_body(&block)
  end
end
