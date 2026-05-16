# This is command-line application is ATOTP-server
# It generates OTP (ATOTP) codes for autentification

ATOTP is Address-based Time-based One-Time Password algorithm, that add address in secret key.
Its done as method of security from AiTM atacks and generate OTP codes that passed only for currect service.

Members are:
* ATOTP autentificator (user)
* (optional) ATOTP client (make delivery address easy)
* and ATOTP server (service)

ATOTP server works on:
* Windows
* Linux
* MacOS

====

There 2 methods (routes):

1. Registration (route /register)
    - Client send username (it will in URL in field "label")
    - Server send username, secret, otpauthUrl and note "'Server does not store secret. Client must save it securely."
2. Verify (route verify)
    - Client send username, secret and code (from autentificator)
    - Server send username, valid (true or false) and remaining (in seconds)

U can check health of server on route /health