--[[
My MQTT certificate authority. Won't be much use to you.

Something like this might get you started:

    $ openssl ecparam -genkey -name secp384r1 -noout -out ca.key
    $ openssl req -verbose -nodes -new -x509 -days 3650 -subj '/CN=skrewzca/emailAddress=skrewz+tls@skrewz.net/' -extensions mycaext -config <(printf "\n[req]\ndistinguished_name=dn_sect\n[dn_sect]\n[mycaext]\nbasicConstraints=critical,CA:true\nkeyUsage=critical,cRLSign,digitalSignature,keyCertSign\nsubjectKeyIdentifier=hash") -key ca.key -out ca.crt

Also see my writeup on https://gist.github.com/skrewz/9855f780189d81bb06750e96fc45979b

--]]

tls.cert.verify([[
-----BEGIN CERTIFICATE-----
MIICATCCAYagAwIBAgIUAKCz6gZlr4wEXMigG081Oov0SPowCgYIKoZIzj0EAwIw
NzEPMA0GA1UEAwwGbXF0dGNhMSQwIgYJKoZIhvcNAQkBFhVza3Jld3ordGxzQHNr
cmV3ei5uZXQwHhcNMTkxMTA4MTkzOTE4WhcNMjkxMTA1MTkzOTE4WjA3MQ8wDQYD
VQQDDAZtcXR0Y2ExJDAiBgkqhkiG9w0BCQEWFXNrcmV3eit0bHNAc2tyZXd6Lm5l
dDB2MBAGByqGSM49AgEGBSuBBAAiA2IABIILagbZoMm66zIq6g5S1sfxhIXjBgoy
ewvXJvmfHpnBIPcjtno8qc42oREc2JX1Pg+ASsFLAwZ51RVtUGC+CRkR9KOXvo8V
MWfRpSHbq2IsBI6xBnW7vf5f23aerQ1x2qNTMFEwHQYDVR0OBBYEFB7CeBJ0sSAk
d+dQJofudALSc4eEMB8GA1UdIwQYMBaAFB7CeBJ0sSAkd+dQJofudALSc4eEMA8G
A1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDaQAwZgIxAOWpGLPvYwa6wQeE6d9I
XfsRsvhfoZ1PgnC6rQOUWh0MitVjk2xdywSSGfMr2uxDGAIxAO6BCXsGNOafpFEl
ADMIONAz46BAx43cj3Dxg3Q5jCG5kZpoEopcWYkpNPiZ8x6HjQ==
-----END CERTIFICATE-----
]])

