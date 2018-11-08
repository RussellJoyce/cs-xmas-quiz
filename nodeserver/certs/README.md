SSL Certificates
============

**Put SSL certificate and key files in this folder.**

To get a certificate from [Let's Encrypt](https://letsencrypt.org), install `certbot` and use something like the following.

```
certbot certonly --manual --logs-dir ./logs --config-dir ./config --work-dir ./work --preferred-challenges dns
```
