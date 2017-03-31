# A support module for testing character encoding
module PuppetSpec::CharacterEncoding
  def self.with_external_encoding(encoding, &blk)
    original_encoding = Encoding.default_external
    begin
      Encoding.default_external = encoding
      yield
    ensure
      Encoding.default_external = original_encoding
    end
  end
end
