# The JsonCatalogEncoder is a wrapper around a catalog produced by the Pal::CatalogCompiler.with_json_encoding
# method.
# It allows encoding the entire catalog or an individual resource as Rich Data Json.
#
# @api public
#
class JsonCatalogEncoder
  # Is the resulting Json pretty printed or not.
  attr_reader :pretty

  # Should unrealized virtual resources be included in the result or not.
  attr_reader :exclude_virtual

  # The internal catalog being build - what this class wraps with a public API.
  attr_reader :catalog
  private :catalog

  # Do not instantiate this class directly! Use the `Pal::CatalogCompiler#with_json_encoding` method
  # instead.
  #
  # @param catalog [Puppet::Resource::Catalog] the internal catalog that this class wraps
  # @param pretty [Boolean] (true), if the resulting JSON should be pretty printed or not
  # @param exclude_virtual [Boolean] (true), if the resulting catalog should contain unrealzed virtual resources or not
  #
  # @api private
  #
  def initialize(catalog, pretty: true, exclude_virtual: true)
    @catalog = catalog
    @pretty = pretty
    @exclude_virtual = exclude_virtual
  end

  # Encodes the entire catalog as a rich-data Json catalog.
  # @return String The catalog in Json format using rich data format
  # @api public
  #
  def encode
    possibly_filtered_catalog.to_json(:pretty => pretty)
  end

  # Returns one particular resource as a Json string, or returns nil if resource was not found.
  # @param type [String] the name of the puppet type (case independent)
  # @param title [String] the title of the wanted resource
  # @return [String] the resulting Json text
  # @api public
  #
  def encode_resource(type, title)
    # Ensure that both type and title are given since the underlying API will do mysterious things
    # if 'title' is nil. (Other assertions are made by the catalog when looking up the resource).
    #
    # TRANSLATORS 'type' and 'title' are internal parameter names - do not translate
    raise ArgumentError, _("Both type and title must be given") if type.nil? or title.nil?
    r = possibly_filtered_catalog.resource(type, title)
    return nil if r.nil?
    r.to_data_hash.to_json(:pretty => pretty)
  end

  # Applies a filter for virtual resources and returns filtered catalog
  # or the catalog itself if filtering was not needed.
  # The result is cached.
  # @api private
  #
  def possibly_filtered_catalog
    @filtered ||= (exclude_virtual ? catalog.filter { |r| r.virtual? } : catalog)
  end
  private :possibly_filtered_catalog
end
