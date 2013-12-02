Services
--------

Puppet Agents use various network services which the Puppet Master provides in
order to manage systems. Other systems can access these services in order to
put the information that the Puppet Master has to use.

### Configuration Management Services

These services are all related to how the Puppet Agent is able to manage the
configuration of a node.

* {file:api/docs/http_catalog.md Catalog}
* {file:api/docs/http_file_bucket_file.md File Bucket File}
* {file:api/docs/http_file_content.md File Content}
* {file:api/docs/http_file_metadata.md File Metadata}
* {file:api/docs/http_report.md Report}

### Informational Services

These services all provide extra information that can be used to understand how
the Puppet Master will be providing configuration management information to
Puppet Agents.

* {file:api/docs/http_facts.md Facts}
* {file:api/docs/http_node.md Node}
* {file:api/docs/http_resource_type.md Resource Type}
* {file:api/docs/http_status.md Status}

### SSL Certificate Related Services

These services are all in support of Puppet's PKI system.

* {file:api/docs/http_certificate.md Certificate}
* {file:api/docs/http_certificate_request.md Certificate Signing Requests}
* {file:api/docs/http_certificate_status.md Certificate Status}
* {file:api/docs/http_certificate_revocation_list.md Certificate Revocation List}


Serialization Formats
---------------------

Puppet sends messages using several different serialization formats. Not all
REST services support all of the formats.

* {file:api/docs/pson.md PSON}
* {http://www.yaml.org/spec/1.2/spec.html YAML}
