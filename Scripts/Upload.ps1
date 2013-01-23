param(
    [Parameter(Mandatory=$false)][string]$Subscription = "NuGet Gallery Preview",
	[Parameter(Mandatory=$false)][string]$StorageAccountName = "nugetgallerydev",
	[Parameter(Mandatory=$false)][string]$PackageFile = $null,
    [Parameter(Mandatory=$false)][string]$AzureSdkPath = $null
)

Select-AzureSubscription $Subscription

# Import common stuff
$ScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition)
. $ScriptRoot\_Common.ps1

$items = @(dir "$ScriptRoot\..\_AzurePackage\NuGetGallery_*.cspkg");
if($items.Length -eq 0) {
    throw "No packages found in _AzurePackage folder"
}

if($items.Length -eq 1) {
    $PackageFilePath = $items[0]
}
else {
    $PackageFilePath = SelectOrUseProvided $PackageFile $items  { $true } "Package" { 
        $parsed = ParsePackageName $_.Name
        if(!$parsed) {
            $_.Name
        } else {
            "$($parsed.Hash) on $($parsed.Branch) - ($($parsed.Name))"
        }
    }
}
Write-Host "Pushing $PackageFilePath to $StorageAccountName"

$AzureSdkPath = Get-AzureSdkPath $AzureSdkPath

[System.Reflection.Assembly]::LoadFrom("$AzureSdkPath\bin\Microsoft.WindowsAzure.StorageClient.dll") | Out-Null

$StorageConnectionString = Get-StorageAccountConnectionString $StorageAccountName
$Account = [Microsoft.WindowsAzure.CloudStorageAccount]::Parse($StorageConnectionString)
$BlobClient = [Microsoft.WindowsAzure.StorageClient.CloudStorageAccountStorageClientExtensions]::CreateCloudBlobClient($Account)
$ContainerRef = $BlobClient.GetContainerReference("deployment-packages");
$ContainerRef.CreateIfNotExist() | Out-Null
$Blob = $ContainerRef.GetBlockBlobReference($PackageFilePath.Name)
Write-Host "** Uploading Blob" -ForegroundColor Black -BackgroundColor Green
$Blob.UploadFile($PackageFilePath.FullName)