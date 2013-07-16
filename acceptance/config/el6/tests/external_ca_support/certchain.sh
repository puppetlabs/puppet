#! /bin/bash

## NOTE:
## This script requires the follwing in /etc/hosts:
## 127.0.0.2   puppet master1.example.org

# This will fail with a stock puppet 3.1.1, but will succeed if all of the
# certificate subjects contain only the "CN" portion, and no O, OU, or
# emailAddress.

# basic config to describe the environment
# B="/tmp/certchain"
B="$(mktemp -d -t certchain.XXXXXXXX)"
HTTPS_PORT=8443
OPENSSL=$(which openssl)

# utility method to dedent a heredoc
dedent() {
    python -c 'import sys, textwrap; print textwrap.dedent(sys.stdin.read())'
}

# invoke openssl
openssl() {
    echo "----"
    echo "running" ${OPENSSL} ${@}
    echo "  in $PWD"
    ${OPENSSL} "${@}"
}

show_cert() {
    local cert="$1"
    # openssl x509 -in "${cert}" -noout -text -nameopt RFC2253
    openssl x509 -in "${cert}" -noout -text
}

hash_cert() {
    local cert="$1"
    local certdir="${B}/certdir"
    local h=$(${OPENSSL} x509 -hash -noout -in ${cert})
    mkdir -p "${certdir}"
    ln -s "$cert" "${certdir}/${h}.0"
}

show_crl() {
    local crl="$1"
    openssl crl -in "${crl}" -noout -text
}

hash_crl() {
    local crl="$1"
    local certdir="${B}/certdir"
    local h=$(${OPENSSL} crl -hash -noout -in ${crl})
    mkdir -p "${certdir}"
    ln -s "$crl" "${certdir}/${h}.r0"
}

# clean out any messes ths script has made
clean_up() {
    stop_apache
    rm -rf "$B"
}

stop_apache() {
    local pid pidfile="${B}/apache/httpd.pid"
    while true; do
        pid=$(cat "${pidfile}" 2>/dev/null || true)
        [ -z "$pid" ] && break # break if the pid is gone
        kill "$pid" || break # break if the kill fails (process is gone)
        sleep 0.1
    done
}

# perform basic setup: make directories, etc.
set_up() {
    mkdir -p "$B"
}

# create CA certificates:
#
# * $B/root_ca
# * $B/master{1..2}_ca
#
# with each containing:
#
# * openssl.conf -- suitable for signing certificates
# * ca-$name.key -- PEM format certificate key, with no password
# * ca-$name.crt -- PEM format certificate
create_ca_certs() {
    local name cn dir subj ca_config
    for name in root agent-ca master-ca; do
        dir="${B}/${name}"
        mkdir -p "${dir}"
        (   cd "${dir}"
            # if this is the root cert, make a self-signed cert
            if [ "$name" = "root" ]; then
                subj="/CN=Root CA/OU=Server Operations/O=Example Org, LLC"
                openssl req -new -newkey rsa -days 7300 -nodes -x509 \
                  -subj "${subj}" -keyout "ca-${name}.key" -out "ca-${name}.crt"
            else
                # make a new key for the CA
                openssl genrsa -out "ca-${name}.key"

                # build a CSR out of it
                dedent > openssl.tmp << OPENSSL_TMP
                    [req]
                    prompt = no
                    distinguished_name = dn_config

                    [dn_config]
                    commonName = Intermediate CA (${name})
                    emailAddress = test@example.org
                    organizationalUnitName = Server Operations
                    organizationName = Example Org, LLC
OPENSSL_TMP
                openssl req -config openssl.tmp -new -key "ca-${name}.key" -out "ca-${name}.csr"
                rm openssl.tmp

                # sign it with the root CA
                openssl ca -config ../root/openssl.conf -in "ca-${name}.csr" -notext -out "ca-${name}.crt" -batch

                # clean up the now-redundant csr
                rm "ca-${name}.csr"
            fi

            # set up the CA config; this uses the same file for all, but with different options
            # for the root and master CAs
            [ "$name" = "root" ] && ca_config=root_ca_config || ca_config=master_ca_config

            dedent > openssl.conf << OPENSSL_CONF
                SAN = DNS:puppet

                [ca]
                default_ca = ${ca_config}
                 
                # Root CA
                [root_ca_config]
                certificate = ${dir}/ca-${name}.crt
                private_key = ${dir}/ca-${name}.key
                database = ${dir}/inventory.txt
                new_certs_dir = ${dir}/certs
                serial = ${dir}/serial
                 
                default_crl_days = 7300
                default_days = 7300
                default_md = sha1
                 
                policy = root_ca_policy
                x509_extensions = root_ca_exts
                 
                [root_ca_policy]
                commonName = supplied
                emailAddress = supplied
                organizationName = supplied
                organizationalUnitName = supplied
                 
                [root_ca_exts]
                authorityKeyIdentifier = keyid,issuer:always
                basicConstraints = critical,CA:true
                keyUsage = keyCertSign, cRLSign

                # Master CA
                [master_ca_config]
                certificate = ${dir}/ca-${name}.crt
                private_key = ${dir}/ca-${name}.key
                database = ${dir}/inventory.txt
                new_certs_dir = ${dir}/certs
                serial = ${dir}/serial
                 
                default_crl_days = 7300
                default_days = 7300
                default_md = sha1
                 
                policy = master_ca_policy
                x509_extensions = master_ca_exts

                # Master CA (Email)
                [master_ca_email_config]
                certificate = ${dir}/ca-${name}.crt
                private_key = ${dir}/ca-${name}.key
                database = ${dir}/inventory.txt
                new_certs_dir = ${dir}/certs
                serial = ${dir}/serial
                 
                default_crl_days = 7300
                default_days = 7300
                default_md = sha1
                 
                email_in_dn = yes

                policy = master_ca_email_policy
                x509_extensions = master_ca_exts

                [master_ca_policy]
                commonName = supplied

                [master_ca_email_policy]
                commonName = supplied
                emailAddress = supplied
                 
                # default extensions for clients
                [master_ca_exts]
                authorityKeyIdentifier = keyid,issuer:always
                basicConstraints = critical,CA:false
                keyUsage = keyEncipherment, digitalSignature
                extendedKeyUsage = serverAuth, clientAuth

                [master_ssl_exts]
                authorityKeyIdentifier = keyid,issuer:always
                basicConstraints = critical,CA:false
                keyUsage = keyEncipherment, digitalSignature
                extendedKeyUsage = serverAuth, clientAuth
                subjectAltName = \$ENV::SAN

                # extensions for the master certificate (specifically adding subjectAltName)
                [master_self_ca_exts]
                authorityKeyIdentifier = keyid,issuer:always
                basicConstraints = critical,CA:false
                keyUsage = keyEncipherment, digitalSignature
                extendedKeyUsage = serverAuth, clientAuth
                # include the master's fqdn here, as well as in the CN, to work
                # around https://bugs.ruby-lang.org/issues/6493
                # NOTE: Alt Names should be set in the request, so they know
                # their FQDN
                # subjectAltName = DNS:puppet,DNS:${name}.example.org
OPENSSL_CONF
            touch inventory.txt
            mkdir certs
            echo 01 > serial

            show_cert "${dir}/ca-${name}.crt"
            hash_cert "${dir}/ca-${name}.crt"

            # generate an empty CRL for this CA
            openssl ca -config "${dir}/openssl.conf" -gencrl -out "${dir}/ca-${name}.crl"

            show_crl "${dir}/ca-${name}.crl"
            hash_crl "${dir}/ca-${name}.crl"
        )
    done
}

# revoke leaf cert for $1 issued by master CA $2
revoke_leaf_cert() {
    local fqdn="$1"
    local ca="${2:-agent-ca}"
    local dir="${B}/${ca}"

    # revoke the cert and regenerate the crl
    openssl ca -config "${dir}/openssl.conf" -revoke "${B}/leaves/${fqdn}.issued_by.${ca}.crt"
    openssl ca -config "${dir}/openssl.conf" -gencrl -out "${dir}/ca-${ca}.crl"
    show_crl "${dir}/ca-${ca}.crl"
    # kill -HUP $(< "${B}/apache/httpd.pid")
}

# revoke CA cert for $1
revoke_ca_cert() {
    local master="$1"
    local dir="${B}/root"

    # revoke the cert and regenerate the crl
    openssl ca -config "${dir}/openssl.conf" -revoke "${B}/${master}/ca-${master}.crt"
    openssl ca -config "${dir}/openssl.conf" -gencrl -out "${dir}/ca-root.crl"
    show_crl "${dir}/ca-root.crl"
    kill -HUP $(< "${B}/apache/httpd.pid")
}

# create a "leaf" certificate for the given fqdn, signed by the given ca name.
# $fqdn.issued_by.${ca}.{key,crt} will be placed in "${B}/leaves"
create_leaf_cert() {
    local fqdn="$1" ca="$2" exts="$3"
    local masterdir="${B}/${ca}"
    local dir="${B}/leaves"
    local fname="${fqdn}.issued_by.${ca}"

    [ -n "$exts" ] && exts="-extensions $exts"

    mkdir -p "${dir}"
    (   cd "${dir}"

        openssl genrsa -out "${fname}.key"
        openssl req -subj "/CN=${fqdn}" -new -key "${fname}.key" -out "${fname}.csr"
        CN="${fqdn}" SAN="DNS:${fqdn}, DNS:${fqdn%%.*}, DNS:puppet, DNS:puppetmaster" \
          openssl ca -config "${B}/${ca}/openssl.conf" -in "${fname}.csr" -notext \
          -out "${fname}.crt" -batch $exts
    )
    show_cert "${dir}/${fname}.crt"
}

# Note, we can parameterize SubjectAltNames using environment variables.
create_leaf_certs() {
    create_leaf_cert master1.example.org master-ca master_ssl_exts
    create_leaf_cert master2.example.org master-ca master_ssl_exts

    create_leaf_cert agent1.example.org agent-ca
    create_leaf_cert agent2.example.org agent-ca
    create_leaf_cert agent3.example.org agent-ca

    create_leaf_cert master1.example.org agent-ca master_ssl_exts # rogue
    # create_leaf_cert master1.example.org root master_ssl_exts # rogue

    create_leaf_cert agent1.example.org master-ca # rogue
    # create_leaf_cert agent1.example.org root # rogue
}

# create a "leaf" certificate for the given fqdn, signed by the given ca name,
# with an email address in the subject.
# $fqdn.issued_by.${ca}.{key,crt} will be placed in "${B}/leaves"
create_leaf_email_cert() {
    local fqdn="$1" ca="$2" exts="$3"
    local masterdir="${B}/${ca}"
    local dir="${B}/leaves"
    local fname="${fqdn}.issued_by.${ca}"

    mkdir -p "${dir}"
    (   cd "${dir}"

        openssl genrsa -out "${fname}.key"
        openssl req -subj "/CN=${fqdn}/emailAddress=test@example.com" -new -key "${fname}.key" -out "${fname}.csr"

        openssl ca -config "${B}/${ca}/openssl.conf" -name master_ca_email_config \
          -in "${fname}.csr" -notext -out "${fname}.crt" -batch $exts_arg
    )
    show_cert "${dir}/${fname}.crt"
}

create_leaf_email_certs() {
    create_leaf_email_cert master-email1.example.org master-ca master_self_ca_exts
    create_leaf_email_cert master-email2.example.org master-ca master_self_ca_exts
    create_leaf_email_cert agent-email1.example.org agent-ca
    create_leaf_email_cert agent-email2.example.org agent-ca
    create_leaf_email_cert agent-email3.example.org agent-ca
}

set_up_apache() {
    local apachedir="${B}/apache"
    mkdir -p "${apachedir}/puppetmaster/public"

    echo 'passed'> "${apachedir}/puppetmaster/public/test.txt"
    dedent > "${apachedir}/httpd.conf" <<HTTPD_CONF
        LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
        LoadModule unixd_module modules/mod_unixd.so
        LoadModule authn_core_module modules/mod_authn_core.so
        LoadModule authz_core_module modules/mod_authz_core.so
        LoadModule ssl_module modules/mod_ssl.so
        LoadModule headers_module modules/mod_headers.so
        LoadModule passenger_module modules/mod_passenger.so

        # NOTE: these may be "fun" to make portable..
        PassengerRoot /usr/share/gems/gems/passenger-3.0.17
        PassengerRuby /usr/bin/ruby

        PidFile "${apachedir}/httpd.pid"
        ErrorLog "${apachedir}/error_log"
        LogLevel debug

        Listen ${HTTPS_PORT} https
        SSLRandomSeed startup file:/dev/urandom  256
        SSLRandomSeed connect builtin
        SSLEngine on
        SSLProtocol all -SSLv2
        SSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5

        # puppet-relevant SSL config:

        SSLCertificateFile "${B}/leaves/master1.example.org.crt"
        SSLCertificateKeyFile "${B}/leaves/master1.example.org.key"
        # chain in the intermediate cert for this master
        SSLCertificateChainFile "${B}/master1/ca-master1.crt"
        SSLCACertificatePath "${B}/certdir"
        SSLCARevocationPath "${B}/certdir"
        SSLCARevocationCheck chain
        SSLVerifyClient optional
        SSLVerifyDepth 2
        SSLOptions +StdEnvVars
        RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
        RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
        RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e

        ServerName master1.example.org
        DocumentRoot "${apachedir}/puppetmaster/public"

        # NOTE: this is httpd-2.4 syntax
        <Directory "${apachedir}/puppetmaster/public">
            Require all granted
        </Directory>

        RackAutoDetect On
        RackBaseURI /
HTTPD_CONF
}

set_up_puppetmaster() {
    local apachedir="${B}/apache"
    local masterdir="${B}/puppetmaster"
    mkdir -p "${masterdir}/conf" "${masterdir}/var" "${masterdir}/manifests" 
    dedent > "${apachedir}/puppetmaster/config.ru" <<CONFIG_RU
        \$0 = "master"
        ARGV << "--rack"
        ARGV << "--debug"
        ARGV << "--confdir=${masterdir}/conf"
        ARGV << "--vardir=${masterdir}/var"
        require 'puppet/application/master'
        run Puppet::Application[:master].run
CONFIG_RU

    dedent > "${masterdir}/conf/puppet.conf" <<PUPPET_CONF
        [main]
        node_name = cert
        strict_hostname_checking = true

        [master]
        ca = false
        ssl_client_header = SSL_CLIENT_S_DN
        ssl_client_verify_header = SSL_CLIENT_VERIFY
        manifestdir = ${masterdir}/manifests
PUPPET_CONF
    dedent > "${masterdir}/manifests/site.pp" <<SITE_PP
        node /client.*.example.org/ {
            file { "${B}/i_was_here":
                content => "yes I was"
            }
        }
SITE_PP
}

start_apache() {
    local apachedir="${B}/apache"
    if ! httpd -f "${apachedir}/httpd.conf"; then
        [ -f "${apachedir}/error_log" ] && tail "${apachedir}/error_log"
        false
    fi
}

check_apache() {
    # verify the SSL config with openssl.  Note that s_client exits with 0
    # no matter what, so this greps the output for an OK status.  Also note
    # that this only checks that the validation of the server certs is OK, since
    # client validation is optional in the httpd config.
    echo $'GET /test.txt HTTP/1.0\n' | \
        openssl s_client -connect "127.0.0.1:${HTTPS_PORT}" -verify 2 \
                -cert "${B}/leaves/client2a.example.org.crt" \
                -key "${B}/leaves/client2a.example.org.key" \
                -CAfile "${B}/root/ca-root.crt" \
            | tee "${B}/verify.out"
    cat "${B}/apache/error_log"
    grep -q "Verify return code: 0 (ok)" "${B}/verify.out"
}

check_puppetmaster() {
    # this is insecure, because otherwise curl will check that 127.0.0.1 ==
    # master1.example.org and fail; validation of the server certs is done
    # above in check_apache, so this is fine.
    curl -vks --fail \
            --header 'Accept: yaml' \
            --cert "${B}/leaves/client2a.example.org.crt" \
            --key "${B}/leaves/client2a.example.org.key" \
        "https://127.0.0.1:${HTTPS_PORT}/production/catalog/client2a.example.org" >/dev/null
    echo
}

# set up the agent with the given fqdn
set_up_agent() {
    local fqdn="$1"
    local agentdir="${B}/agent"
    mkdir -p "${agentdir}/conf" "${agentdir}/var"
    mkdir -p "${agentdir}/conf/ssl/private_keys" "${agentdir}/conf/ssl/certs"

    dedent > "${agentdir}/conf/puppet.conf" <<PUPPET_CONF
        [agent]
        server = master1.example.org
        # agent can't verify CRLs for a chain
        certificate_revocation = false
        masterport = ${HTTPS_PORT}
        ca_port = ${HTTPS_PORT}
        report = false
PUPPET_CONF
    # the client needs its own leaf cert/key and the root CA cert
    cp "${B}/leaves/${fqdn}.key" "${agentdir}/conf/ssl/private_keys/${fqdn}.pem" 
    cp "${B}/leaves/${fqdn}.crt" "${agentdir}/conf/ssl/certs/${fqdn}.pem" 
    cp "${B}/root/ca-root.crt" "${agentdir}/conf/ssl/certs/ca.pem" 
}

# run the agent with the given fqdn; with -f, expect it to fail
run_agent() {
    local fqdn="$1"
    local expfail=false
    local agentdir="${B}/agent"
    if [ "$2" = "-f" ]; then
        expfail=true
    fi

    # the manifest will create this file
    rm -f "${B}/i_was_here"

    if puppet agent --test --debug \
            --confdir=/tmp/certchain/agent/conf/ --vardir=/tmp/certchain/agent/var/ \
            --fqdn "${fqdn}"; then
        if ${expfail}; then
            false
        fi
        # This appears not to work in 3.1.x
        #test -f "${B}/i_was_here"
    else
        echo "expected failure"
        if ! ${expfail}; then
            false
        fi
        # This appears not to work in 3.1.x
        #test ! -f "${B}/i_was_here"
    fi
}

call() {
    echo "==== $1 ===="
    "${@}"
}

main() {
    call clean_up
    call set_up
    call create_ca_certs
    call create_leaf_certs
    call create_leaf_email_certs

    # Revoke the second agent and see it fail.
    call revoke_leaf_cert agent2.example.org
    call revoke_leaf_cert master2.example.org master-ca

    exit 0
    call set_up_apache
    call set_up_puppetmaster
    call start_apache
    call check_apache
    call check_puppetmaster

    # set up the client to run normally, then revoke the client's cert and see it fail
    call set_up_agent client2a.example.org
    call run_agent client2a.example.org
    call revoke_leaf_cert client2a.example.org master2
    call run_agent client2a.example.org -f

    # set up the client to run another host, then revoke master2's CA cert
    call set_up_agent client2b.example.org
    call run_agent client2b.example.org
    call revoke_ca_cert master2
    call run_agent client2b.example.org -f

    call clean_up
}

set -x
set -e
main
