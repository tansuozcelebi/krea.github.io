# KREA Version Manager
# PowerShell script for version management

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("patch", "minor", "major")]
    [string]$Type = "patch",
    
    [Parameter(Mandatory=$false)]
    [string]$Message = "Version update",
    
    [Parameter(Mandatory=$false)]
    [switch]$Show,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

function Show-Help {
    Write-Host "KREA Version Manager" -ForegroundColor Green
    Write-Host "===================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Kullanım:"
    Write-Host "  .\version.ps1 -Type [patch|minor|major] -Message 'Açıklama'"
    Write-Host "  .\version.ps1 -Show                    # Mevcut versiyon bilgisi"
    Write-Host "  .\version.ps1 -Help                    # Bu yardım"
    Write-Host ""
    Write-Host "Örnekler:"
    Write-Host "  .\version.ps1 -Type patch -Message 'Bug fix'"
    Write-Host "  .\version.ps1 -Type minor -Message 'New feature'"
    Write-Host "  .\version.ps1 -Type major -Message 'Breaking changes'"
    Write-Host ""
    Write-Host "Version Types:"
    Write-Host "  patch  - 1.0.0 -> 1.0.1 (Bug fixes)"
    Write-Host "  minor  - 1.0.0 -> 1.1.0 (New features)"
    Write-Host "  major  - 1.0.0 -> 2.0.0 (Breaking changes)"
}

function Get-CurrentVersion {
    if (Test-Path "version.json") {
        $versionData = Get-Content "version.json" | ConvertFrom-Json
        return $versionData
    } else {
        Write-Error "version.json dosyası bulunamadı!"
        return $null
    }
}

function Update-Version {
    param($CurrentData, $VersionType, $UpdateMessage)
    
    $version = $CurrentData.version
    $parts = $version.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($VersionType) {
        "major" {
            $major++
            $minor = 0
            $patch = 0
        }
        "minor" {
            $minor++
            $patch = 0
        }
        "patch" {
            $patch++
        }
    }
    
    $newVersion = "$major.$minor.$patch"
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    
    # Version.json güncelle
    $CurrentData.version = $newVersion
    $CurrentData.releaseDate = $currentDate
    $CurrentData.buildNumber = $CurrentData.buildNumber + 1
    
    # Changelog'e yeni giriş ekle
    $newEntry = @{
        version = $newVersion
        date = $currentDate
        type = $VersionType
        changes = @($UpdateMessage)
    }
    
    # Changelog array'in başına ekle
    $CurrentData.changelog = @($newEntry) + $CurrentData.changelog
    
    return $CurrentData
}

function Save-Version {
    param($VersionData)
    
    $json = $VersionData | ConvertTo-Json -Depth 10 -Compress:$false
    $json | Set-Content "version.json" -Encoding UTF8
}

# Ana işlem
if ($Help) {
    Show-Help
    exit 0
}

$currentData = Get-CurrentVersion
if (-not $currentData) {
    exit 1
}

if ($Show) {
    Write-Host "KREA Version Info" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host "Current Version: $($currentData.version)" -ForegroundColor Green
    Write-Host "Release Date: $($currentData.releaseDate)" -ForegroundColor Yellow
    Write-Host "Build Number: $($currentData.buildNumber)" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Recent Changes:" -ForegroundColor Magenta
    $currentData.changelog | Select-Object -First 3 | ForEach-Object {
        Write-Host "  v$($_.version) ($($_.date)): $($_.changes -join ', ')" -ForegroundColor Gray
    }
    exit 0
}

# Version güncelle
Write-Host "Updating version ($Type): $Message" -ForegroundColor Yellow

$updatedData = Update-Version -CurrentData $currentData -VersionType $Type -UpdateMessage $Message
Save-Version -VersionData $updatedData

Write-Host "Version updated successfully!" -ForegroundColor Green
Write-Host "New version: $($updatedData.version)" -ForegroundColor Cyan
Write-Host "Build: $($updatedData.buildNumber)" -ForegroundColor Blue

# Git'e commit yap (opsiyonel)
$commitChoice = Read-Host "Git commit yapmak istiyor musunuz? (y/n)"
if ($commitChoice -eq "y" -or $commitChoice -eq "Y") {
    git add .
    git commit -m "Bump version to $($updatedData.version): $Message"
    Write-Host "Git commit completed!" -ForegroundColor Green
    
    $pushChoice = Read-Host "Git push yapmak istiyor musunuz? (y/n)"
    if ($pushChoice -eq "y" -or $pushChoice -eq "Y") {
        git push origin master
        Write-Host "Git push completed!" -ForegroundColor Green
    }
}