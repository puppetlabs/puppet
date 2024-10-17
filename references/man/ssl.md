---
layout: default
built_from_commit: 6893bdd69ab1291e6e6fcd6b152dda2b48e3cdb2
title: 'Man Page: puppet ssl'
canonical: "/puppet/latest/man/ssl.html"
---

# Man Page: puppet ssl

> **NOTE:** This page was generated from the Puppet source code on 2024-10-17 02:36:47 +0000

NAME
====

**puppet-ssl** - Manage SSL keys and certificates for puppet SSL clients

SYNOPSIS
========

Manage SSL keys and certificates for SSL clients needing to communicate
with a puppet infrastructure.

USAGE
=====

puppet ssl *action* \[-h\|\--help\] \[-v\|\--verbose\] \[-d\|\--debug\]
\[\--localca\] \[\--target CERTNAME\]

OPTIONS
=======

-   \--help: Print this help message.

-   \--verbose: Print extra information.

-   \--debug: Enable full debugging.

-   \--localca Also clean the local CA certificate and CRL.

-   \--target CERTNAME Clean the specified device certificate instead of
    this host\'s certificate.

-   

ACTIONS
=======

bootstrap

:   Perform all of the steps necessary to request and download a client
    certificate. If autosigning is disabled, then puppet will wait every
    **waitforcert** seconds for its certificate to be signed. To only
    attempt once and never wait, specify a time of 0. Since
    **waitforcert** is a Puppet setting, it can be specified as a time
    interval, such as 30s, 5m, 1h.

submit\_request

:   Generate a certificate signing request (CSR) and submit it to the
    CA. If a private and public key pair already exist, they will be
    used to generate the CSR. Otherwise, a new key pair will be
    generated. If a CSR has already been submitted with the given
    **certname**, then the operation will fail.

generate\_request

:   Generate a certificate signing request (CSR). If a private and
    public key pair exist, they will be used to generate the CSR.
    Otherwise a new key pair will be generated.

download\_cert

:   Download a certificate for this host. If the current private key
    matches the downloaded certificate, then the certificate will be
    saved and used for subsequent requests. If there is already an
    existing certificate, it will be overwritten.

verify

:   Verify the private key and certificate are present and match, verify
    the certificate is issued by a trusted CA, and check revocation
    status.

clean

:   Remove the private key and certificate related files for this host.
    If **\--localca** is specified, then also remove this host\'s local
    copy of the CA certificate(s) and CRL bundle. if **\--target
    CERTNAME** is specified, then remove the files for the specified
    device on this host instead of this host.

show

:   Print the full-text version of this host\'s certificate.
