param(
    [string]$ImageTag = "do-product-service:local",
    [string]$ReportPath = "reports\\trivy-product-service.txt"
)

$repoRoot = (Get-Location).Path
$reportDir = Split-Path $ReportPath
if ($reportDir -and -not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Force $reportDir | Out-Null
}

$safeTag = ($ImageTag -replace "[:/]", "_")
$tarPath = Join-Path $repoRoot "reports\\$safeTag.tar"
docker save $ImageTag -o $tarPath

docker run --rm `
  -v "${repoRoot}:/work" `
  aquasec/trivy:0.50.2 `
  image --exit-code 0 --format table --input "/work/reports/$safeTag.tar" `
  | Out-File -FilePath $ReportPath -Encoding utf8

Remove-Item $tarPath -ErrorAction SilentlyContinue
