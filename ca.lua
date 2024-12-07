--[[
My certificate authority. Won't be much use to you.

Something like this might get you started:

    $ openssl ecparam -genkey -name secp384r1 -noout -out ca.key
    $ openssl req -verbose -nodes -new -x509 -days 3650 -subj '/CN=skrewzca/emailAddress=skrewz+tls@skrewz.net/' -extensions mycaext -config <(printf "\n[req]\ndistinguished_name=dn_sect\n[dn_sect]\n[mycaext]\nbasicConstraints=critical,CA:true\nkeyUsage=critical,cRLSign,digitalSignature,keyCertSign\nsubjectKeyIdentifier=hash") -key ca.key -out ca.crt

Also see my writeup on https://gist.github.com/skrewz/9855f780189d81bb06750e96fc45979b

--]]

tls.cert.verify([[
-----BEGIN CERTIFICATE-----
MIIB8zCCAXmgAwIBAgIUEJRjGZuz+0ragxvpfXVdMpj8oVwwCgYIKoZIzj0EAwIw
OTERMA8GA1UEAwwIc2tyZXd6Y2ExJDAiBgkqhkiG9w0BCQEWFXNrcmV3eit0bHNA
c2tyZXd6Lm5ldDAeFw0yMDAxMDcxMTE0MDFaFw0zMDAxMDQxMTE0MDFaMDkxETAP
BgNVBAMMCHNrcmV3emNhMSQwIgYJKoZIhvcNAQkBFhVza3Jld3ordGxzQHNrcmV3
ei5uZXQwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAATx9YRxNYg8YrBiDCf2v8eQauZM
bE+JR34O/JnNMpLHLrVEOhuduwA1Ay1hh9YtQcBesRkURdJSb1H5cOP0f5RYYkvj
XmBb+LsklOibjBP86qDTunIiDgJ+r9/tFxy3Lg6jQjBAMA8GA1UdEwEB/wQFMAMB
Af8wDgYDVR0PAQH/BAQDAgGGMB0GA1UdDgQWBBRh3YLaB5RbH8p2xHnUhClz4gS/
gjAKBggqhkjOPQQDAgNoADBlAjAR8wykhJx3/rUppVBh4jilcDxnU3rVN6U/v1I/
FOSDAFvKNQAun02ZKkahEcFun+0CMQCBUJV7SxSz8vo/oR9lGzzPYsUqYzZOL0DV
D8Y5WukrCNiHA9RVbemasDSV42i7nUI=
-----END CERTIFICATE-----
]])

