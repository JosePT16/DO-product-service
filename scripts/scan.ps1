param(
    [string]$ImageTag = "do-product-service:local",
    [string]$ReportPath = "reports\\trivy-product-service.txt"
)

$reportDir = Split-Path $ReportPath
if ($reportDir -and -not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Force $reportDir | Out-Null
}

docker run --rm `
  -v //./pipe/docker_engine://./pipe/docker_engine `
  aquasec/trivy:0.50.2 `
  image --exit-code 0 --format table $ImageTag | Out-File -FilePath $ReportPath -Encoding utf8
