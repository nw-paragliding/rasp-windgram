[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [Parameter(Mandatory=$true)]
    [string]$RelativeURL,
    [Parameter(Mandatory=$true)]
    [string]$User,
    [Parameter(Mandatory=$true)]
    [securestring]$Password
)

$filename = [System.IO.Path]::GetFileName($Path)

$urlString = "ftp://wxtofly.net/$RelativeURL/$filename"
Write-Host -Object "ftp url: $urlString";

$webclient = New-Object -TypeName System.Net.WebClient;
$webclient.Credentials = New-Object System.Net.NetworkCredential($User, $Password)
$uri = New-Object -TypeName System.Uri -ArgumentList $urlString;

Write-Host -Object "Uploading $Path...";

$webclient.UploadFile($uri, $Path);
$webclient.Dispose();