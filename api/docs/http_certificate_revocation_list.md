Certificate Revocation List
===========================

The `certificate_revocation_list` endpoint retrieves a Certificate Revocation List (CRL)
from the master. The master must be configured to be a CA. The returned
CRL is always in the `.pem` format.

Under Puppet Server's CA service, the `environment` parameter is ignored and can
be omitted. Under a Rack or WEBrick Puppet master, `environment` is required and
must be a valid environment, but it has no effect on the response.

The `:nodename` should always be `ca`, due to the default auth.conf rules for
WEBrick and Rack Puppet masters. (You can use a different `:nodename` if you
change the auth rules, but it will have no effect on the response.)

Find
----

Get the submitted CRL

    GET /puppet-ca/v1/certificate_revocation_list/:nodename?environment=:environment
    Accept: text/plain

### Supported HTTP Methods

GET

### Supported Response Formats

`text/plain`

The returned CRL is always in the `.pem` format.

### Parameters

None

### Examples

Since the returned CRL always looks similar to the human eye, the successful examples are each followed by an openssl
decoding of the CRL PEM file.

#### Empty revocation list

    GET /puppet-ca/v1/certificate_revocation_list/ca?environment=env

    HTTP/1.1 200 OK
    Content-Type: text/plain

    -----BEGIN X509 CRL-----
    MIICdzBhAgEBMA0GCSqGSIb3DQEBBQUAMB8xHTAbBgNVBAMMFFB1cHBldCBDQTog
    bG9jYWxob3N0Fw0xMzA3MTYyMDQ4NDJaFw0xODA3MTUyMDQ4NDNaoA4wDDAKBgNV
    HRQEAwIBADANBgkqhkiG9w0BAQUFAAOCAgEAqyBJOy3dtCOcrb0Fu7ZOOiDQnarg
    IzXUV/ug1dauPEVyURLNNr+CJrr89QZnU/71lqgpWTN/J47mO/lffMSPjmINE+ng
    XzOffm0qCG2+gNyaOBOdEmQTLdHPIXvcm7T+wEqc7XFW2tjEdpEubZgweruU/+DB
    RX6/PhFbalQ0bKcMeFLzLAD4mmtBaQCJISmUUFWx1pyCS6pgBtQ1bNy3PJPN2PNW
    YpDf3DNZ16vrAJ4a4SzXLXCoONw0MGxZcS6/hctJ75Vz+dTMrArKwckytWgQS/5e
    c/1/wlMZn4xlho+EcIPMPfCB5hW1qzGU2WjUakTVxzF4goamnfFuKbHKEoXVOo9C
    3dEQ9un4Uyd1xHxj8WvQck79In5/S2l9hdqp4eud4BaYB6tNRKxlUntSCvCNriR2
    wrDNsMuQ5+KJReG51vM0OzzKmlScgIHaqbVeNFZI9X6TpsO2bLEZX2xyqKw4xrre
    OIEZRoJrmX3VQ/4u9hj14Qbt72/khYo6z/Fckc5zVD+dW4fjP2ztVTSPzBqIK3+H
    zAgewYW6cJ6Aan8GSl3IfRqj6WlOubWj8Gr1U0dOE7SkBX6w/X61uqsHrOyg/E/Z
    0Wcz/V+W5iZxa4Spm0x4sfpNzf/bNmjTe4M2MXyn/hXx5MdHf/HZdhOs/lzwKUGL
    kEwcy38d6hYtUjs=
    -----END X509 CRL-----

    > openssl crl -inform PEM -in empty.crl -text -noout
    Certificate Revocation List (CRL):
            Version 2 (0x1)
            Signature Algorithm: sha1WithRSAEncryption
            Issuer: /CN=Puppet CA: localhost
            Last Update: Jul 16 20:48:42 2013 GMT
            Next Update: Jul 15 20:48:43 2018 GMT
            CRL extensions:
                X509v3 CRL Number:
                    0
    No Revoked Certificates.
        Signature Algorithm: sha1WithRSAEncryption
            ab:20:49:3b:2d:dd:b4:23:9c:ad:bd:05:bb:b6:4e:3a:20:d0:
            9d:aa:e0:23:35:d4:57:fb:a0:d5:d6:ae:3c:45:72:51:12:cd:
            36:bf:82:26:ba:fc:f5:06:67:53:fe:f5:96:a8:29:59:33:7f:
            27:8e:e6:3b:f9:5f:7c:c4:8f:8e:62:0d:13:e9:e0:5f:33:9f:
            7e:6d:2a:08:6d:be:80:dc:9a:38:13:9d:12:64:13:2d:d1:cf:
            21:7b:dc:9b:b4:fe:c0:4a:9c:ed:71:56:da:d8:c4:76:91:2e:
            6d:98:30:7a:bb:94:ff:e0:c1:45:7e:bf:3e:11:5b:6a:54:34:
            6c:a7:0c:78:52:f3:2c:00:f8:9a:6b:41:69:00:89:21:29:94:
            50:55:b1:d6:9c:82:4b:aa:60:06:d4:35:6c:dc:b7:3c:93:cd:
            d8:f3:56:62:90:df:dc:33:59:d7:ab:eb:00:9e:1a:e1:2c:d7:
            2d:70:a8:38:dc:34:30:6c:59:71:2e:bf:85:cb:49:ef:95:73:
            f9:d4:cc:ac:0a:ca:c1:c9:32:b5:68:10:4b:fe:5e:73:fd:7f:
            c2:53:19:9f:8c:65:86:8f:84:70:83:cc:3d:f0:81:e6:15:b5:
            ab:31:94:d9:68:d4:6a:44:d5:c7:31:78:82:86:a6:9d:f1:6e:
            29:b1:ca:12:85:d5:3a:8f:42:dd:d1:10:f6:e9:f8:53:27:75:
            c4:7c:63:f1:6b:d0:72:4e:fd:22:7e:7f:4b:69:7d:85:da:a9:
            e1:eb:9d:e0:16:98:07:ab:4d:44:ac:65:52:7b:52:0a:f0:8d:
            ae:24:76:c2:b0:cd:b0:cb:90:e7:e2:89:45:e1:b9:d6:f3:34:
            3b:3c:ca:9a:54:9c:80:81:da:a9:b5:5e:34:56:48:f5:7e:93:
            a6:c3:b6:6c:b1:19:5f:6c:72:a8:ac:38:c6:ba:de:38:81:19:
            46:82:6b:99:7d:d5:43:fe:2e:f6:18:f5:e1:06:ed:ef:6f:e4:
            85:8a:3a:cf:f1:5c:91:ce:73:54:3f:9d:5b:87:e3:3f:6c:ed:
            55:34:8f:cc:1a:88:2b:7f:87:cc:08:1e:c1:85:ba:70:9e:80:
            6a:7f:06:4a:5d:c8:7d:1a:a3:e9:69:4e:b9:b5:a3:f0:6a:f5:
            53:47:4e:13:b4:a4:05:7e:b0:fd:7e:b5:ba:ab:07:ac:ec:a0:
            fc:4f:d9:d1:67:33:fd:5f:96:e6:26:71:6b:84:a9:9b:4c:78:
            b1:fa:4d:cd:ff:db:36:68:d3:7b:83:36:31:7c:a7:fe:15:f1:
            e4:c7:47:7f:f1:d9:76:13:ac:fe:5c:f0:29:41:8b:90:4c:1c:
            cb:7f:1d:ea:16:2d:52:3b

#### One-item revocation list

    GET /puppet-ca/v1/certificate_revocation_list/ca?environment=env

    HTTP/1.1 200 OK
    Content-Type: text/plain

    -----BEGIN X509 CRL-----
    MIICnDCBhQIBATANBgkqhkiG9w0BAQUFADAfMR0wGwYDVQQDDBRQdXBwZXQgQ0E6
    IGxvY2FsaG9zdBcNMTMxMDA3MTk0ODQwWhcNMTgxMDA2MTk0ODQxWjAiMCACAQUX
    DTEzMTAwNzE5NDg0MVowDDAKBgNVHRUEAwoBAaAOMAwwCgYDVR0UBAMCAQEwDQYJ
    KoZIhvcNAQEFBQADggIBALrh49WNdmrJOPCRntD1nxCObmqZgl8ZwTv7TO9VkmCG
    Ksvo8zR2aTIOH9VUKqWrE0squhtFJXl8dxL4PR1RiLbmhO7dp+NHdu8ejTQpoOTp
    h69xbQFT3oHcIdn2cBGrLJQcZgXsiswT0KJ8nuw6eDO93yXDrguSUdou99M99wTw
    2nn1kUQKW9b0vUI7t2ADF5U8/DES+1IrvBq2IEHmg4+ekZRCxeJMuqd1R13gymcJ
    osSPbRgIjCli6zD3aK4Nq5OMMpVLV/VVPwyQb4GwW4Wj5iyNAp8d/EAqtZ21ZHUi
    nvuXmRtUWHJwfi40D5T2GQXxuUjB4pnh8cFq7f89iUvqoCwFo7nRIacrrweNFMYD
    GxVJVMfz4PkP66ckIPQ5Uuey92dg5p2w4b2cp8NstxMdgcc3KAF483ItKA8uIDuU
    1dbzw1v2k5qUjoImueHwKolbLmPyYmvFp7hbnV+WpFbvGjyIfW3BMankDEv4ig0L
    MCw6n2GKv1hSWM6Mrk8Ja1yYOFLsjI0RoVCZsf1iNiRT28haldXVTPyNtct9mGAv
    6az5W/nyixIPrrHubTx28zhmuHZx6y3hQMCLmuYOT+e7F/eFsYXVEjuJjxjr33uA
    O/ii4EkTls1gzvonOtoBoGElzQAogrZI3HXCwFYvU2whLKr9cwv5bpRkUfPCMQ4n
    -----END X509 CRL-----

    > openssl crl -inform PEM -in 1revoked.crl -text -noout
    Certificate Revocation List (CRL):
            Version 2 (0x1)
            Signature Algorithm: sha1WithRSAEncryption
            Issuer: /CN=Puppet CA: localhost
            Last Update: Oct  7 19:48:40 2013 GMT
            Next Update: Oct  6 19:48:41 2018 GMT
            CRL extensions:
                X509v3 CRL Number:
                    1
    Revoked Certificates:
        Serial Number: 05
            Revocation Date: Oct  7 19:48:41 2013 GMT
            CRL entry extensions:
                X509v3 CRL Reason Code:
                    Key Compromise
        Signature Algorithm: sha1WithRSAEncryption
            ba:e1:e3:d5:8d:76:6a:c9:38:f0:91:9e:d0:f5:9f:10:8e:6e:
            6a:99:82:5f:19:c1:3b:fb:4c:ef:55:92:60:86:2a:cb:e8:f3:
            34:76:69:32:0e:1f:d5:54:2a:a5:ab:13:4b:2a:ba:1b:45:25:
            79:7c:77:12:f8:3d:1d:51:88:b6:e6:84:ee:dd:a7:e3:47:76:
            ef:1e:8d:34:29:a0:e4:e9:87:af:71:6d:01:53:de:81:dc:21:
            d9:f6:70:11:ab:2c:94:1c:66:05:ec:8a:cc:13:d0:a2:7c:9e:
            ec:3a:78:33:bd:df:25:c3:ae:0b:92:51:da:2e:f7:d3:3d:f7:
            04:f0:da:79:f5:91:44:0a:5b:d6:f4:bd:42:3b:b7:60:03:17:
            95:3c:fc:31:12:fb:52:2b:bc:1a:b6:20:41:e6:83:8f:9e:91:
            94:42:c5:e2:4c:ba:a7:75:47:5d:e0:ca:67:09:a2:c4:8f:6d:
            18:08:8c:29:62:eb:30:f7:68:ae:0d:ab:93:8c:32:95:4b:57:
            f5:55:3f:0c:90:6f:81:b0:5b:85:a3:e6:2c:8d:02:9f:1d:fc:
            40:2a:b5:9d:b5:64:75:22:9e:fb:97:99:1b:54:58:72:70:7e:
            2e:34:0f:94:f6:19:05:f1:b9:48:c1:e2:99:e1:f1:c1:6a:ed:
            ff:3d:89:4b:ea:a0:2c:05:a3:b9:d1:21:a7:2b:af:07:8d:14:
            c6:03:1b:15:49:54:c7:f3:e0:f9:0f:eb:a7:24:20:f4:39:52:
            e7:b2:f7:67:60:e6:9d:b0:e1:bd:9c:a7:c3:6c:b7:13:1d:81:
            c7:37:28:01:78:f3:72:2d:28:0f:2e:20:3b:94:d5:d6:f3:c3:
            5b:f6:93:9a:94:8e:82:26:b9:e1:f0:2a:89:5b:2e:63:f2:62:
            6b:c5:a7:b8:5b:9d:5f:96:a4:56:ef:1a:3c:88:7d:6d:c1:31:
            a9:e4:0c:4b:f8:8a:0d:0b:30:2c:3a:9f:61:8a:bf:58:52:58:
            ce:8c:ae:4f:09:6b:5c:98:38:52:ec:8c:8d:11:a1:50:99:b1:
            fd:62:36:24:53:db:c8:5a:95:d5:d5:4c:fc:8d:b5:cb:7d:98:
            60:2f:e9:ac:f9:5b:f9:f2:8b:12:0f:ae:b1:ee:6d:3c:76:f3:
            38:66:b8:76:71:eb:2d:e1:40:c0:8b:9a:e6:0e:4f:e7:bb:17:
            f7:85:b1:85:d5:12:3b:89:8f:18:eb:df:7b:80:3b:f8:a2:e0:
            49:13:96:cd:60:ce:fa:27:3a:da:01:a0:61:25:cd:00:28:82:
            b6:48:dc:75:c2:c0:56:2f:53:6c:21:2c:aa:fd:73:0b:f9:6e:
            94:64:51:f3:c2:31:0e:27

#### No node name given

    GET /puppet-ca/v1/certificate_revocation_list?environment=env

    HTTP/1.1 400 Bad Request
    Content-Type: text/plain

    No request key specified in /puppet-ca/v1/certificate_revocation_list

Schema
------

A `certificate_revocation_list` response body is not structured data according to any
standard scheme such as json/pson/yaml, so no schema is applicable.
