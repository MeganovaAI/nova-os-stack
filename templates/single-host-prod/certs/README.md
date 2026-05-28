# TLS certs go here

Place your real cert files in this directory:

- `fullchain.pem` — server cert + intermediate chain
- `privkey.pem`   — server private key

Obtain via Let's Encrypt:
```bash
sudo certbot certonly --standalone -d nova.your-domain.com
sudo cp /etc/letsencrypt/live/nova.your-domain.com/fullchain.pem certs/
sudo cp /etc/letsencrypt/live/nova.your-domain.com/privkey.pem certs/
```

This directory is gitignored — actual certs never go into version control.
