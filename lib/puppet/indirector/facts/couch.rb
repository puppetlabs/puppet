require 'puppet/node/facts'
require 'puppet/indirector/couch'
class Puppet::Node::Facts::Couch < Puppet::Indirector::Couch

  # Return the facts object or nil if there is no document
  def find(request)
    doc = super
    doc ? model.new(doc['_id'], doc['facts']) : nil
  end

  private

  # Facts values are stored to the document's 'facts' attribute. Hostname is
  # stored to 'name'
  #
  def hash_from(request)
    super.merge('facts' => request.instance.values)
  end

  # Facts are stored to the 'node' document.
  def document_type_for(request)
    'node'
  end

  # The id used to store the object in couchdb.
  def id_for(request)
    request.key.to_s
  end

end

