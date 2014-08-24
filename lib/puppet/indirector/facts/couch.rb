require 'puppet/node/facts'
require 'puppet/indirector/couch'
class Puppet::Node::Facts::Couch < Puppet::Indirector::Couch

  desc "DEPRECATED. This terminus will be removed in Puppet 4.0.

    Store facts in CouchDB. This should not be used with the inventory service;
    it is for more obscure custom integrations. If you are wondering whether you
    should use it, you shouldn't; use PuppetDB instead."
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

