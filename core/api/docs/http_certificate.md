Certificate
=============

The `certificate` endpoint returns the certificate for the specified name,
which might be either a standard certname or `ca`.

The returned certificate is always in the `.pem` format.

Find
----

Get a certificate.

    GET /:environment/certificate/:nodename


### Supported HTTP Methods

GET

### Supported Format

Accept: s

### Parameters

None

### Notes

The environment field is ignored.

### Responses

#### Certificate found

    GET /env/certificate/elmo.mydomain.com

    HTTP 200 OK
    Content-Type: text/plain

    -----BEGIN CERTIFICATE-----
    MIIFujCCA6KgAwIBAgIBATANBgkqhkiG9w0BAQsFADBiMWAwXgYDVQQDDFdQdXBw
    ZXQgQ0EgZ2VuZXJhdGVkIG9uIGRoY3A1MC5reWxvLmJhY2tsaW5lLnB1cHBldGxh
    YnMubmV0IGF0IDIwMTMtMDYtMjQgMTY6MzA6MTcgLTA3MDAwHhcNMTMwNjIzMjMz
    MDE5WhcNMTgwNjIzMjMzMDE5WjBiMWAwXgYDVQQDDFdQdXBwZXQgQ0EgZ2VuZXJh
    dGVkIG9uIGRoY3A1MC5reWxvLmJhY2tsaW5lLnB1cHBldGxhYnMubmV0IGF0IDIw
    MTMtMDYtMjQgMTY6MzA6MTcgLTA3MDAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
    ggIKAoICAQDABq1lmzccjuRmnCdXvTmdeXJGb9S8r8+I+G6fkHTa1WKDSob9PZpS
    eXJtanbl0zNws9yBt1Dko2zhKDKctBRWf5CT42nDxBZPY7SaD7KaCzb07g9wfWgU
    BOb/6smyl/iySEmQzzFLRgZbo5A9WLiy/UdyQim1faakevRme2Xi/l/i0TKbpu27
    DhCS+E8aC8Bvaj0ph0T+TzYphTR76pP5Kps6G7Jyk/HFYrVXnY44X2PEt2mgkEXp
    xHCbU+qCFMtTLMG+ZArA/noM3I/O6W5LhLSzApjut/M7UdMlpZ45PGDrsvf2R306
    NcOh+zbbkhxuIaGqaxeaenYzbOlA3gXhZvYaV6EKjXNtm7BslpsvhLi0U+CWyb3C
    qRkpex0MgxJgxoqViJ4TDVA+EmztOnK86+G4HGeJqTPQloYO/Td1wMT1Txh9T5Ue
    Wctw/g+4o22EyJQRo+vxxzHNRIfe7EHAerMUtLT5u9MJeQb9N1iUR2ATNAN+QiB2
    KEqyc9eMapK6QUZFV23Xvbdup1WCrgsWXBqyRWKV7x0sc9Wv8RMRKEFYaBeHEVXU
    m0hGgF34Z8Rzphq2H1FjkLD+xbtGOjrA1Mb2De81Hfvrf18497X5UMPtsuzOt/XU
    PHbbSCy+05J7VNZ/gaiGqgpHfcG5yiqCdj1LIzhFuuvm+fADPxK38wIDAQABo3sw
    eTA3BglghkgBhvhCAQ0EKhYoUHVwcGV0IFJ1YnkvT3BlblNTTCBJbnRlcm5hbCBD
    ZXJ0aWZpY2F0ZTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNV
    HQ4EFgQUEhn/MqSDtuxg12klWosCGenxf1cwDQYJKoZIhvcNAQELBQADggIBAH1G
    L3FG/keKlGqs70PxxvR1wCo4VM3K/C+5uxnzm1MHEAd96nhtwE6YSkUe+XgDiXfC
    +NXS2C4TeTQAEo6grREapWDjhJvrhrgqTZmb4lTKzb91II3/VGYzG5UXxID262zy
    QLoX/IBN/xDJ5ds0wF2adUbnHUssEGGljgngewH/7kjeW/L5iL+USXZnKHPSggjM
    RAEjlucE/rDqDNoxhOS4K2PjseFm7krW4cZ0gNmxdrhc7OhmJ56dH92F4M9jn7Qy
    EqxWB304U/aMcO3NJxTQc7AreL/pUtjtI6hxM4miHbjSh6RfNBqhzRyJvxA6gc6g
    m3kumdw04KZFSs/6fPFFbI60i5K+vioB4CnUWpj+3Z+OnDEvhQJEACR1JC8A67Ih
    x+GDlbHLU1BWonwZzSMJz+ABXV3dwIrOSFHI0UmDXg+cIdZ+SaL93qMjUVU4v9nu
    gR9yJGMqNuzLjgfbD/KGCEEAITKBwPvCVd//OMlWVrXr7vvt+yo6STIlTJxABJDp
    CSLyHUtT++CsPXsPADxgRctpIbh1eMFEivkK9Oy+W/CZYIZnARVysUpMWg7TkXqx
    mSCXy9ZXLWqU/ssVhbLS9vFVa5pvxcyfiRpsFg0XZsx8mnZP6OaWcL8FjF+/NwNP
    tg1+DuYTn+d54OHi/GZEnvutgrDZyrJDrrb/Czm9
    -----END CERTIFICATE-----

#### Certificate not found

    GET /env/certificate/certificate_does_not_exist

    HTTP 404 Not Found: Could not find certificate certificate_does_not_exist
    Content-Type: text/plain

    Not Found: Could not find certificate certificate_does_not_exist

#### No Certificate name given

    GET /env/certificate/

    HTTP/1.1 400 No request key specified in /env/certificate/
    Content-Type: text/plain

    No request key specified in /env/certificate/

#### Master is not a CA

    GET /env/certificate/valid_certificate

    HTTP/1.1 400 this master is not a CA
    Content-Type: text/plain

    this master is not a CA


Schema
------

A certificate response body is not structured data according to any standard scheme such as
json/pson/yaml, so no schema is applicable.
