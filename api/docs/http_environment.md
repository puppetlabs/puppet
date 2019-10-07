Environment Catalog
===================

**Warning: the format of the response for this endpoint will change in a
future version in an incompatible way. It should be considered private for
the time being**

Issuing a `GET` request against this endpoint causes the compiler to
compile an _environment catalog_ and return it.

Get
---

Get the catalog for an environment

    GET /puppet/v3/environment/:environment

### Supported Response Formats

`application/json`

### Parameters

None

### Example Request & Response

    GET /puppet/v3/environment/production

    HTTP 200 OK
    Content-Type: application/json

    {
      "environment": "production",
      "applications": {
        "Webapp[pao]": {
          "Db[pao_db]": {
            "produces": [ "Sql[pao_db]" ],
            "consumes": [],
            "node": "agent1" },
          "Web[pao_w1]": {
            "produces": [ "Http[pao_w1]" ],
            "consumes": [ "Sql[pao_db]" ],
            "node": "agent2" },
          "Web[pao_w2]": {
            "produces": [ "Http[pao_w2]" ],
            "consumes": [ "Sql[pao_db]" ],
            "node": "agent2" },
          "Web[pao_w3]": {
            "produces": [ "Http[pao_w3]" ],
            "consumes": [ "Sql[pao_db]" ],
            "node": "agent2" },
          "Lb[pao_lb]": {
            "produces": [],
            "consumes": [ "Http[pao_w1]", "Http[pao_w2]", "Http[pao_w3]" ],
            "node": "agent3" }
        }
      }
    }

The response contains the name of the environment in the `environment` key,
and a list of applications in that environment in the `applications`
hash. The type/title of each application is used as the key in that hash,
and the entry for that application consists of a hash of the components,
again keyed by the type and title of the component.

For each component, the catalog indicates what service resources the
component `produces` and `consumes`, as well as the `node` to which that
component is mapped.

#### Planned response change

The response format is likely to change in the following way:

* the `applications` hash will become an array of hashes, where each hash
  represents an application with separate keys for type and title, and for
  the components of the application
* the components of an application will similarly be represented as an
  array of hashes, similar to the format used today, but with the addition
  of the component's type and title inside the hash
