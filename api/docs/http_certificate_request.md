Certificate Request
=============

The `certificate_request` endpoint submits a Certificate Signing Request (CSR)
to the master.  The master must be configured to be a CA.  The returned
CSR is always in the `.pem` format.

In all requests the `:environment` must be given, but it has no bearing on the request. CSRs are not managed within environments, all CSRs are global.

Find
----

Get a submitted CSR

    GET /:environment/certificate_request/:nodename
    Accept: s

Save
----

Submit a CSR

    PUT /:environment/certificate_request/:nodename
    Content-Type: text/plain

Note: The `:nodename` must match the Common Name on the submitted CSR.

Note: Although the `Content-Type` is sent as `text/plain` the content is
specifically a CSR in PEM format.

Search
----

List submitted CSRs

    GET /:environment/certificate_requests/:ignored_pattern
    Accept: s

The `:ignored_pattern` parameter is not used, but must still be provided.

Destroy
----

Delete a submitted CSR

    DELETE /:environment/certificate_request/:nodename
    Accept: s

### Supported HTTP Methods

The default configuration only allows requests that result in a Find and a
Save. You need to modify auth.conf in order to allow clients to use Search and
Destroy actions. It is not recommended that you change the default settings.

GET, PUT, DELETE

### Supported Format

Accept: s

### Parameters

None

### Examples

#### CSR found

    GET /env/certificate_request/agency

    HTTP/1.1 200 OK
    Content-Type: text/plain

    -----BEGIN CERTIFICATE REQUEST-----
    MIIBnzCCAQwCAQAwYzELMAkGA1UEBhMCVUsxDzANBgNVBAgTBkxvbmRvbjEPMA0G
    A1UEBxMGTG9uZG9uMSEwHwYDVQQKExhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQx
    DzANBgNVBAMTBmFnZW5jeTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAxSCr
    FKUKjVGFPuQ0iGM9mZKw94sOIgGohqrHH743kPvjsId3d38Qk+H+1DbVf42bQY0W
    kAVcwNDqmBnx0lOtQ0oeGnbbwlJFjhqXr8jFEljPrc9S2/IIILDf/FeYWw9lRiOV
    LoU6ZfCIBfq6v4D4KX3utRbOoELNyBeT6VA1ufMCAwEAAaAAMAkGBSsOAwIPBQAD
    gYEAno7O1jkR56TNMe1Cw/eyQUIaniG22+0kmoftjlcMYZ/IKCOz+HRgnDtBPf8j
    O5nt0PQN8YClW7Xx2U8ZTvBXn/UEKMtCBkbF+SULiayxPgfyKy/axinfutEChnHS
    ZtUMUBLlh+gGFqOuH69979SJ2QmQC6FNomTkYI7FOHD/TG0=
    -----END CERTIFICATE REQUEST-----

#### CSR not found

    GET /env/certificate_request/does_not_exist

    HTTP/1.1 404 Not Found: Could not find certificate_request does_not_exist
    Content-Type: text/plain

    Not Found: Could not find certificate_request does_not_exist

#### No node name given

    GET /env/certificate_request/

    HTTP/1.1 400 No request key specified in /env/certificate_request/
    Content-Type: text/plain

    No request key specified in /env/certificate_request/

#### Delete a CSR that exists

    DELETE /production/certificate_request/agency
    Accept: s

    HTTP/1.1 200 OK
    Content-Type: text/plain

    1

#### Delete a CSR that does not exists

    DELETE /production/certificate_request/missing
    Accept: s

    HTTP/1.1 200 OK
    Content-Type: text/plain

    false

#### Retrieve all CSRs

     GET /production/certificate_requests/ignored
     Accept: s

     HTTP/1.1 200 OK
     Content-Type: text/plain

     -----BEGIN CERTIFICATE REQUEST-----
     MIIBnzCCAQwCAQAwYzELMAkGA1UEBhMCVUsxDzANBgNVBAgTBkxvbmRvbjEPMA0G
     A1UEBxMGTG9uZG9uMSEwHwYDVQQKExhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQx
     DzANBgNVBAMTBmFnZW5jeTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAxSCr
     FKUKjVGFPuQ0iGM9mZKw94sOIgGohqrHH743kPvjsId3d38Qk+H+1DbVf42bQY0W
     kAVcwNDqmBnx0lOtQ0oeGnbbwlJFjhqXr8jFEljPrc9S2/IIILDf/FeYWw9lRiOV
     LoU6ZfCIBfq6v4D4KX3utRbOoELNyBeT6VA1ufMCAwEAAaAAMAkGBSsOAwIPBQAD
     gYEAno7O1jkR56TNMe1Cw/eyQUIaniG22+0kmoftjlcMYZ/IKCOz+HRgnDtBPf8j
     O5nt0PQN8YClW7Xx2U8ZTvBXn/UEKMtCBkbF+SULiayxPgfyKy/axinfutEChnHS
     ZtUMUBLlh+gGFqOuH69979SJ2QmQC6FNomTkYI7FOHD/TG0=
     -----END CERTIFICATE REQUEST-----

     ---
     -----BEGIN CERTIFICATE REQUEST-----
     MIIBnjCCAQsCAQAwYjELMAkGA1UEBhMCVUsxDzANBgNVBAgTBkxvbmRvbjEPMA0G
     A1UEBxMGTG9uZG9uMSEwHwYDVQQKExhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQx
     DjAMBgNVBAMTBWFnZW50MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC1tucK
     enT1CkDPgsCU/0e2cbzRsiKF8yHH7+ntF6Q3d9ZCaZWJ00mj0+YmiYrnum+KAikE
     45Iaf9vaUV3CPsDVrUPOI8kYehiv868ZhP3nxblE6iuNBK+Fdv9GN/vKQrmL5iRE
     bIrOM3/lxpS7SpidGdA6EIVlS3604bwLY4xHNQIDAQABoAAwCQYFKw4DAg8FAAOB
     gQAXH0YFuidPqB6P2MyPEEGZ3rzozINBx/oXvGptXI60Zy5mgH6iAkrZfi57pEzP
     jFoO2JRaFxTJC1FVpc4zR1K6sq4h3fIMwqppJRX+5wJNKyhU61eY2gR2O/rAJzw4
     wcUKf9JhoE7/p1cUulIIIq7t/ibCvf0LYSFwGqTwGqN2TQ==
     -----END CERTIFICATE REQUEST-----

The CSR PEMs are separated by "\n---\n"

Schema
------

A certificate_request response body is not structured data according to any
standard scheme such as json/pson/yaml, so no schema is applicable.
