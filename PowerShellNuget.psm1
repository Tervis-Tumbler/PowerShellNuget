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

    $Lower_Version = Invoke-RestMethod -Method Get -Uri "$PackageConentService$Name/index.json" |
    Select-Object -ExpandProperty Versions |
    Sort-Object -Descending |
    Select-Object -First 1
    
    Invoke-RestMethod -Method Get -Uri $PackageConentService$Lower_ID/$Lower_Version/$Lower_ID.$Lower_Version.nupkg -OutFile 
}