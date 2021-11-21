SSL Certificates
============

**Put SSL certificate and key files in this folder.**

To get a certificate from [Let's Encrypt](https://letsencrypt.org), install `certbot` and use something like the following.

```
certbot certonly --manual --register-unsafely-without-email --logs-dir . --config-dir . --work-dir . --preferred-challenges dns -d christmasquiz.pro
```
