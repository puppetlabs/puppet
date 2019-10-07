require 'puppet/resource/catalog'
require 'puppet/indirector/json'

class Puppet::Resource::Catalog::Json < Puppet::Indirector::JSON
  desc "Store catalogs as flat files, serialized using JSON."

  def from_json(text)
    utf8 = text.force_encoding(Encoding::UTF_8)

    if utf8.valid_encoding?
      model.convert_from(json_format, utf8)
    else
      Puppet.info(_("Unable to deserialize catalog from json, retrying with pson"))
      model.convert_from('pson', text.force_encoding(Encoding::BINARY))
    end
  end

  def to_json(object)
    object.render(json_format)
  rescue Puppet::Network::FormatHandler::FormatError => err
    Puppet.info(_("Unable to serialize catalog to json, retrying with pson"))
    Puppet.log_exception(err, err.message, level: :debug)
    object.render('pson').force_encoding(Encoding::BINARY)
  end

  private

  def json_format
    if Puppet[:rich_data]
      'rich_data_json'
    else
      'json'
    end
  end
end
