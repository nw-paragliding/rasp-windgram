[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [Parameter(Mandatory=$true)]
    [string]$RelativeURL
)

$filename = [System.IO.Path]::GetFileName($Path)

$urlString = "ftp://wxtofly.net/$RelativeURL/$filename"
Write-Host -Object "ftp url: $urlString";

$webclient = New-Object -TypeName System.Net.WebClient;
$webclient.Credentials = New-Object System.Net.NetworkCredential("olneytj","***REMOVED***")
$uri = New-Object -TypeName System.Uri -ArgumentList $urlString;

Write-Host -Object "Uploading $Path...";

$webclient.UploadFile($uri, $Path);