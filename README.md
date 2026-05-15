# This comand-like application is ATOTP-server
# It generate OTP (ATOTP) codes for autentification

ATOTP is Address-based Time-based One-Time Password algorithm, that add address in secret key.
Its done as method of security from AiTM atacks and generate OTP codes that passed only for currect service.

Members are:
* ATOTP autentificator (user)
* (optional) ATOTP client (make delivery address easy)
* and ATOTP server (service)

ATOTP server works on:
* Windows
* Linux
* Maybe MacOS (I'll test it)