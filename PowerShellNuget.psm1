function Install-PowerShellNugetPackage {
    param (
        $Name,
        $Destination,
        $RequiredVersion,
        [Switch]$SkipDependencies
    )
    begin {
        Register-PackageSource -Location https://www.nuget.org/api/v2 -name TemporaryNuget.org -Trusted -ProviderName NuGet | Out-Null
    } 
    process {            
        Install-Package -Source TemporaryNuget.org @PSBoundParameters | Out-Null
    }
    end {
        UnRegister-PackageSource -Source TemporaryNuget.org | Out-Null
    }
}


function Get-PowerShellNugetPackageCachePath {
    "$Home\.nuget\packages"
}

function Get-PowerShellNugetPackage {
    param (
        $Name,
        $Path
    )
    #https://docs.microsoft.com/en-us/nuget/api/package-base-address-resource
    $ServiceIndex = Invoke-RestMethod -Method Get -Uri https://api.nuget.org/v3/index.json
    $SearchQueryServiceURI = $ServiceIndex.resources |
    Where-Object "@Type" -eq "SearchQueryService" |
    Select-Object -First 1 -ExpandProperty "@ID"

    $Result = Invoke-RestMethod -Method Get -Uri "$($SearchQueryServiceURI)?q=PackageID:$Name"
    $Lower_ID = $Result.data.ID

    $PackageConentService = $ServiceIndex.resources |
    Where-Object "@Type" -eq "PackageBaseAddress/3.0.0" |
    Select-Object -First 1 -ExpandProperty "@ID"

    $Lower_Versions = Invoke-RestMethod -Method Get -Uri "$PackageConentService$Name/index.json" |
    Select-Object -ExpandProperty Versions
    
    $Lower_Version = [system.version[]]($Lower_Versions) |
    Sort-Object -Descending |
    Select-Object -First 1 |
    ForEach-Object { $_.ToString() }

    $NugetPackageCachePath = Get-PowerShellNugetPackageCachePath
    $PackageCachePath = "$NugetPackageCachePath\$Lower_ID\$Lower_Version"
    
    if (-not (Test-Path -Path $PackageCachePath)) {
        Invoke-RestMethod -Method Get -Uri $PackageConentService$Lower_ID/$Lower_Version/$Lower_ID.$Lower_Version.nupkg -OutFile "$Env:TMP\$Lower_ID.$Lower_Version.nupkg"
        Get-Item -Path "$Env:TMP\$Lower_ID.$Lower_Version.nupkg" |
        Rename-Item -NewName "$Lower_ID.$Lower_Version.zip"
        Expand-Archive -Path $Env:TMP\$Lower_ID.$Lower_Version.zip -DestinationPath $PackageCachePath
        Remove-Item -Force -Recurse -LiteralPath $PackageCachePath\_rels -ErrorAction SilentlyContinue
        Remove-Item -Force -Recurse -LiteralPath $PackageCachePath\package -ErrorAction SilentlyContinue
        Remove-Item -Force -LiteralPath "$PackageCachePath\[Content_Types].xml"
        Move-Item -Path "$Env:TMP\$Lower_ID.$Lower_Version.zip" -Destination $PackageCachePath\$Lower_ID.$Lower_Version.nupkg
    }

    Copy-Item -LiteralPath $PackageCachePath\ -Destination $Path -Recurse -PassThru | 
    Select-Object -First 1 -Wait |
    Rename-Item -NewName $Lower_ID
}