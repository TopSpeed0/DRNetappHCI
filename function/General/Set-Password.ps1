function Set-EncryptedPswd {
    param (
        $keyFile,
        $pswdFile,
        $config
    )
    # File locations
    if (!$keyFile) {$keyFile = 'c:\Users\ybohadana\OneDrive - COGNYTE\Documents\code\Cognyte\VMware\aes.key'}
    if (!$pswdFile) {$pswdFile = 'c:\\Users\ybohadana\\OneDrive - COGNYTE\\Documents\\code\\Cognyte\VMware\pswd.txt'}
    if (!$config) {
        $config = 'C:\Users\ybohadana\OneDrive - COGNYTE\Documents\WindowsPowerShell\Modules\HciVMwareDR\Config-p.json'
    }
    Write-host "Please remember to change this config:$config, keyFile:$keyFile, pswdFile:$pswdFile predefined location on the script !" -ForegroundColor Yellow

    # Step 1 - Create key file
    $key = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
    $key | Out-File -FilePath $keyFile

    # Step 2 - Create password file with key encryption
    # $user = Read-Host -Prompt "Enter User Name"
    $pswd = Read-Host -Prompt "Enter password"
    $secPswd = $pswd | ConvertTo-SecureString -AsPlainText -Force
    $secPswd | ConvertFrom-SecureString -Key (Get-Content -Path $keyFile) |
    Set-Content -Path $pswdFile

    # Step 3 - Retrieve password
    # $encryptedPswd = Get-Content -Path $pswdFile | ConvertTo-SecureString -Key (Get-Content -Path $keyFile)
    # $cred = New-Object System.Management.Automation.PSCredential($user,$encryptedPswd)
    $config = Get-Content $config  | ConvertFrom-Json
}

