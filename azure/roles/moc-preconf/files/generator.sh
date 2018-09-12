#!/bin/bash

CERTPATH="/home/${ANSIBLE_USER}/${NETWORK_NAME}"
KEYGENPATH="/home/${ANSIBLE_USER}/deployment-terraform/helper-scripts/key-generator"
BYTEGENPATH="/home/${ANSIBLE_USER}/poa-network-consensus-contracts/scripts"
MOC_SECRET_FILE="moc_secret"
NETSTAT_SECRET_FILE="netstat_secret"
CERT_SECRET_FILE="cert_secret"
GWDOMAIN="*.cloudapp.net"
GWCERTNAME="gwcert"
SRCERTNAME="server"

# Generate cert with or without password function
function gencert {

    DOMAIN="$1"
    PRIVNAME="$2"
    PASSPHRASE="$3"

# Certificate details;
subj="
C=US
ST=OR
O=POA
localityName=Portland
commonName=$DOMAIN
organizationalUnitName=POA
emailAddress=admin@example.com
"

# Generate the private key
openssl genrsa  ${PASSPHRASE:+-aes256 -passout pass:$PASSPHRASE} -out $PRIVNAME.key 4096
# Generate the CSR
openssl req  -new -batch -subj "$(echo -n "$subj" | tr "\n" "/")" -key $PRIVNAME.key -out $PRIVNAME.csr ${PASSPHRASE:+-passin pass:$PASSPHRASE}
# Generate the cert (good for 1 year)
openssl x509 -req -days 365 -in $PRIVNAME.csr -signkey $PRIVNAME.key -out $PRIVNAME.crt  ${PASSPHRASE:+-passin pass:$PASSPHRASE}
}

# Convert crt to pfx function
function crttopfx {
    PRIVNAME="$1"
    PASSPHRASE="$2"
    openssl pkcs12 -export -inkey $PRIVNAME.key -in $PRIVNAME.crt -out $PRIVNAME.pfx -passin pass:$PASSPHRASE -passout pass:$PASSPHRASE
}

# Autogenerate/read secret function
function gensecret {

    SECRET_FILE="$1"
    SECRET_LENGTH="$2"
    SECRET="$3"
    FILEPATH="${CERTPATH}/${SECRET_FILE}"

    if [[ ! -e $FILEPATH ]]
    then
        if [[ -z "$SECRET" ]]
        then
            head /dev/urandom | tr -dc A-Za-z0-9 | head -c ${SECRET_LENGTH} > $FILEPATH
            cat $FILEPATH
        else
            echo $SECRET > $FILEPATH
            cat $FILEPATH
        fi
    else
        cat $FILEPATH
    fi
}

# Genenrat moc_address function
function genmocaddress {

    if [ ! -e "${CERTPATH}/moc"  ]
    then
        cd $KEYGENPATH
        node script.js $MOC_SECRET $CERTPATH
        cat "${CERTPATH}/moc"
    else
        cat "${CERTPATH}/moc"
    fi
}

# Generate bytecode function
function genbytecode {

    if [ ! -e "$CERTPATH/bytecode" ]
    then
        cd $BYTEGENPATH
        MASTER_OF_CEREMONY=$MOC_ADDRESS node poa-bytecode.js | tail -n +4 > "$CERTPATH/bytecode"
        cat "$CERTPATH/bytecode"
    else
        cat "$CERTPATH/bytecode"
    fi
}

# Generate/getting secret
MOC_SECRET=$(gensecret $MOC_SECRET_FILE $MOC_SECRET_LENGTH $MOC_SECRET)
NETSTAT_SECRET=$(gensecret $NETSTAT_SECRET_FILE $NETSTAT_SECRET_LENGTH $NETSTAT_SECRET)
CERT_SECRET=$(gensecret $CERT_SECRET_FILE $CERT_SECRET_LENGTH $CERT_SECRET)

# Create certificates if not exist
# Check if file with extension .crt exsits in folder
count=$(find "$CERTPATH" -type f -name "*.crt" 2>/dev/null | wc -l)
if [ $count -eq 0  ] && [ $BOOTNODE_BALANCED_COUNT -gt 0 ]
then
    cd $CERTPATH
    # Generate cert for gw
    gencert $GWDOMAIN $GWCERTNAME $MOC_SECRET
    # Convert gw crt to pfx
    crttopfx $GWCERTNAME $MOC_SECRET
    # Generate cert for srv
    gencert $SRDOMAIN $SRCERTNAME
fi

# Generate MOC keypair
MOC_ADDRESS=$(genmocaddress)

# Generate bytecode
BYTECODE=$(genbytecode)

# Return secrets
echo "${MOC_SECRET}"
echo "${NETSTAT_SECRET}"
echo "${CERT_SECRET}"
echo "${MOC_ADDRESS}"
echo "${BYTECODE}"
