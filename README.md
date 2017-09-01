# Certificate hierarchy

This is the file layout I use to build certificates for my websites. The underlying rules in the Makefiles are based in GnuTLS. For this application there's really not much of a difference with OpenSSL. My choice was based on how easy is to configure the resulting CSRs.

Each domain name should have a directory containing a template file and a symlink to `Makefile.sub`. Do something like this:

```bash
$ mkdir my.domain
$ rsync -avP ./lem.click/ ./my-domain/
   ⋮
```

Then, edit the file `my.domain/template.conf` to customize the parameters of your certificate. Finally, use `make`:

```bash
$ make
make -C my-domain
/usr/local/bin/gnutls-certtool --generate-privkey --outfile cert-0.key
Generating a 3072 bit RSA private key...
/usr/local/bin/gnutls-certtool --load-privkey cert-0.key --pubkey-info --outfile cert-0.pub
/usr/local/bin/gnutls-certtool --generate-request --load-privkey cert-0.key --template template.conf --outfile cert-0.csr
Generating a PKCS #10 certificate request...
/usr/local/bin/gnutls-certtool --generate-privkey --outfile cert-1.key
Generating a 3072 bit RSA private key...
/usr/local/bin/gnutls-certtool --load-privkey cert-1.key --pubkey-info --outfile cert-1.pub
/usr/local/bin/gnutls-certtool --generate-request --load-privkey cert-1.key --template template.conf --outfile cert-1.csr
   ⋮
```

After a few seconds, you should have 4 groups of CSRs, public and private keys suitable for use with any SSL / TLS application.

Key parameters can be tweaked in the `Makefile.sub` file. You can have multiple directory names representing multiple domains. This is useful to keep all your keys on a single location.

With a suitable SSH configuration, you can easily upload the required material to your server as follows:

```bash
make HOST=my.server.name upload
   ⋮
/usr/bin/rsync -avPR               \
		./lem.click/cert-0.* ⋯   \
		./lem.click/cert-?.pub ⋯ \
		root@background:/etc/letsencrypt/seed/
building file list ...
   ⋮
lem.click/
lem.click/cert-0.csr
        4372 100%    4.17MB/s    0:00:00 (xfer#7, to-check=33/45)
lem.click/cert-0.key
        8399 100%    8.01MB/s    0:00:00 (xfer#8, to-check=32/45)
lem.click/cert-0.pub
        2237 100%    2.13MB/s    0:00:00 (xfer#9, to-check=31/45)
lem.click/cert-1.pub
        2237 100%    2.13MB/s    0:00:00 (xfer#10, to-check=29/45)
lem.click/cert-2.pub
        2237 100%    2.13MB/s    0:00:00 (xfer#11, to-check=28/45)
lem.click/cert-3.pub
        2237 100%    1.07MB/s    0:00:00 (xfer#12, to-check=27/45)
```