$sitesCSVPath = "$PSScriptRoot\..\WXTOFLY\CONFIG\sites.csv"
$sitesJSONPath = "$PSScriptRoot\..\WXTOFLY\CONFIG\sites.json"

if (-not (Test-Path $sitesCSVPath))
{
    Write-Error "$sitesCSVPath not found"
    exit
}

if (Test-Path $sitesJSONPath)
{
    Remove-Item -Path $sitesJSONPath -Force
}

Import-Csv $sitesCSVPath | ConvertTo-Json | Add-Content -Path $sitesJSONPath

Write-Host "JSON data saved to $sitesJSONPath"