#!/bin/sh

certbot certonly --manual --register-unsafely-without-email --logs-dir . --config-dir . --work-dir . --preferred-challenges dns -d christmasquiz.pro

