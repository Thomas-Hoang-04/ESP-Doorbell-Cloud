#!/bin/bash
set -e

CERT_DIR="$(dirname "$0")/../certs"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "🔐 Generating CA..."
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.pem \
  -subj "/CN=Doorbell-CA"

echo "🔐 Generating Server certificate..."
cat > server_san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = emqx

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = emqx
DNS.2 = localhost
DNS.3 = mqtt-broker
DNS.4 = doorbell-broker
DNS.5 = doorbell-thomas.site
IP.1 = 127.0.0.1
EOF

openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr -config server_san.cnf
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out server.pem -days 3650 -extensions v3_req -extfile server_san.cnf

echo "🔐 Generating ESP32 Client certificate..."
openssl genrsa -out esp32_client.key 2048
openssl req -new -key esp32_client.key -out esp32_client.csr -subj "/CN=esp32-doorbell"
openssl x509 -req -in esp32_client.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out esp32_client.pem -days 3650

rm -f server.csr esp32_client.csr server_san.cnf ca.srl

echo "✅ Certificates generated in $CERT_DIR:"
ls -la "$CERT_DIR"
