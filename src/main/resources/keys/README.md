# Dev RSA Keys

These keys are for **local development only**. Never use in production.

## Regenerate keys

```bash
# Generate private key
openssl genrsa -out dev-private.pem 2048

# Extract public key
openssl rsa -in dev-private.pem -pubout -out dev-public.pem

# Convert to PKCS#8 format (required by Java)
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in dev-private.pem -out dev-private-pkcs8.pem
mv dev-private-pkcs8.pem dev-private.pem
```
