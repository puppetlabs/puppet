class Puppet::Indirector::Couch < Puppet::Indirector::Terminus

  # The CouchRest database instance. One database instance per Puppet runtime
  # should be sufficient.
  #
  def self.db; @db ||= CouchRest.database! Puppet[:couchdb_url] end
  def db; self.class.db end

  def find(request)
    attributes_of get(request)
  end

  def initialize(*args)
    raise "Couch terminus not supported without couchrest gem" unless Puppet.features.couchdb?
    super
  end

  # Create or update the couchdb document with the request's data hash.
  #
  def save(request)
    raise ArgumentError, "PUT does not accept options" unless request.options.empty?
    update(request) || create(request)
  end

  private

  # RKH:TODO: Do not depend on error handling, check if the document exists
  # first. (Does couchrest support this?)
  #
  def get(request)
    db.get(id_for(request))
  rescue RestClient::ResourceNotFound
    Puppet.debug "No couchdb document with id: #{id_for(request)}"
    return nil
  end

  def update(request)
    doc = get request
    return unless doc
    doc.merge!(hash_from(request))
    doc.save
    true
  end

  def create(request)
    db.save_doc hash_from(request)
  end

  # The attributes hash that is serialized to CouchDB as JSON. It includes
  # metadata that is used to help aggregate data in couchdb. Add
  # model-specific attributes in subclasses.
  #
  def hash_from(request)
    {
      "_id"         => id_for(request),
      "puppet_type" => document_type_for(request)
    }
  end

  # The couchdb response stripped of metadata, used to instantiate the model
  # instance that is returned by save.
  #
  def attributes_of(response)
    response && response.reject{|k,v| k =~ /^(_rev|puppet_)/ }
  end

  def document_type_for(request)
    request.indirection_name
  end

  # The id used to store the object in couchdb. Implemented in subclasses.
  #
  def id_for(request)
    raise NotImplementedError
  end

end

