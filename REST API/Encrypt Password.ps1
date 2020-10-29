# Encrypt password
# Run on the machine and user that you are going to use in the other scripts!
#
# Ivanti
# @pkaak
# oct 2020

$password = "$[PlainTextPassword]"
$securepw = ConvertTo-SecureString -AsPlainText -Force -String $password
convertfrom-securestring -SecureString $securepw