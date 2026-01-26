# decrypt-env.ps1 - Decrypt environment variables
# PowerShell version for Windows support
# This script is dot-sourced by ralph.ps1 and notify.ps1 to decrypt sensitive values

# Decrypt value (if it's encrypted)
# Args: $Value - The value to decrypt, $VarName - Variable name for error messages
# Returns: Decrypted value or original if not encrypted
function Decrypt-Value {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,

        [Parameter(Mandatory=$false)]
        [string]$VarName = "variable"
    )

    # Check if encrypted
    if (-not $Value.StartsWith("ENC:")) {
        return $Value
    }

    # Extract encrypted portion
    $encrypted = $Value.Substring(4)

    # Generate key material (Windows equivalent)
    # On Windows, we use: ComputerName + Username + MachineGuid
    try {
        $machineGuid = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid").MachineGuid
    }
    catch {
        Write-Error "Error: Cannot decrypt $VarName - Machine GUID not accessible"
        Write-Error "Decryption requires system Machine GUID for key derivation"
        return ""
    }

    $keyMaterial = "${env:COMPUTERNAME}:${env:USERNAME}:${machineGuid}"

    try {
        # Decode from base64
        $encryptedBytes = [Convert]::FromBase64String($encrypted)

        # Use .NET encryption for cross-platform AES-256-CBC with PBKDF2
        # This matches the openssl command: openssl enc -aes-256-cbc -pbkdf2
        $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($keyMaterial)

        # PBKDF2 with default iterations (openssl default is 10000)
        $iterations = 10000
        $saltSize = 8
        $keySize = 32  # 256 bits
        $ivSize = 16   # 128 bits for AES

        # OpenSSL format: Salted__<salt><encrypted_data>
        if ($encryptedBytes.Length -lt 16 -or
            [System.Text.Encoding]::ASCII.GetString($encryptedBytes, 0, 8) -ne "Salted__") {
            throw "Invalid encrypted format"
        }

        # Extract salt
        $salt = $encryptedBytes[8..15]
        $ciphertext = $encryptedBytes[16..($encryptedBytes.Length - 1)]

        # Derive key and IV using PBKDF2 (matching OpenSSL's EVP_BytesToKey)
        $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($passwordBytes, $salt, $iterations)
        $key = $pbkdf2.GetBytes($keySize)
        $iv = $pbkdf2.GetBytes($ivSize)

        # Decrypt using AES-256-CBC
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.KeySize = 256
        $aes.Key = $key
        $aes.IV = $iv

        $decryptor = $aes.CreateDecryptor()
        $decryptedBytes = $decryptor.TransformFinalBlock($ciphertext, 0, $ciphertext.Length)
        $decrypted = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)

        $aes.Dispose()
        $pbkdf2.Dispose()

        return $decrypted
    }
    catch {
        Write-Error "Error: Failed to decrypt $VarName"
        Write-Error "The encrypted value may be corrupted or was encrypted on a different machine"
        Write-Error "Please re-run: .\ralph.ps1 notify setup"
        Write-Error "Error details: $_"
        return ""
    }
}

# Decrypt all Ralph environment variables if they're encrypted
function Decrypt-RalphEnv {
    $decryptFailed = $false

    # Decrypt webhook URLs
    if ($env:RALPH_SLACK_WEBHOOK_URL) {
        $decrypted = Decrypt-Value -Value $env:RALPH_SLACK_WEBHOOK_URL -VarName "RALPH_SLACK_WEBHOOK_URL"
        if ($decrypted) {
            $env:RALPH_SLACK_WEBHOOK_URL = $decrypted
        } else {
            $decryptFailed = $true
        }
    }

    if ($env:RALPH_DISCORD_WEBHOOK_URL) {
        $decrypted = Decrypt-Value -Value $env:RALPH_DISCORD_WEBHOOK_URL -VarName "RALPH_DISCORD_WEBHOOK_URL"
        if ($decrypted) {
            $env:RALPH_DISCORD_WEBHOOK_URL = $decrypted
        } else {
            $decryptFailed = $true
        }
    }

    # Decrypt Telegram credentials
    if ($env:RALPH_TELEGRAM_BOT_TOKEN) {
        $decrypted = Decrypt-Value -Value $env:RALPH_TELEGRAM_BOT_TOKEN -VarName "RALPH_TELEGRAM_BOT_TOKEN"
        if ($decrypted) {
            $env:RALPH_TELEGRAM_BOT_TOKEN = $decrypted
        } else {
            $decryptFailed = $true
        }
    }

    if ($env:RALPH_TELEGRAM_CHAT_ID) {
        $decrypted = Decrypt-Value -Value $env:RALPH_TELEGRAM_CHAT_ID -VarName "RALPH_TELEGRAM_CHAT_ID"
        if ($decrypted) {
            $env:RALPH_TELEGRAM_CHAT_ID = $decrypted
        } else {
            $decryptFailed = $true
        }
    }

    # Decrypt email credentials
    if ($env:RALPH_SMTP_PASSWORD) {
        $decrypted = Decrypt-Value -Value $env:RALPH_SMTP_PASSWORD -VarName "RALPH_SMTP_PASSWORD"
        if ($decrypted) {
            $env:RALPH_SMTP_PASSWORD = $decrypted
        } else {
            $decryptFailed = $true
        }
    }

    if ($env:RALPH_SENDGRID_API_KEY) {
        $decrypted = Decrypt-Value -Value $env:RALPH_SENDGRID_API_KEY -VarName "RALPH_SENDGRID_API_KEY"
        if ($decrypted) {
            $env:RALPH_SENDGRID_API_KEY = $decrypted
        } else {
            $decryptFailed = $true
        }
    }

    if ($env:RALPH_AWS_SECRET_KEY) {
        $decrypted = Decrypt-Value -Value $env:RALPH_AWS_SECRET_KEY -VarName "RALPH_AWS_SECRET_KEY"
        if ($decrypted) {
            $env:RALPH_AWS_SECRET_KEY = $decrypted
        } else {
            $decryptFailed = $true
        }
    }

    # Note: Custom script paths are not encrypted

    return -not $decryptFailed
}

# Export functions for use in other scripts
Export-ModuleMember -Function Decrypt-Value, Decrypt-RalphEnv
