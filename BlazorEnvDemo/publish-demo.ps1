# Publish Blazor WASM outputs and optionally run UAT + Production side-by-side locally.
#
# Examples:
#   .\publish-demo.ps1
#   .\publish-demo.ps1 -Environment all -RunSideBySide
#   .\publish-demo.ps1 -Environment UAT -NoServe
#   .\publish-demo.ps1 -UatPort 8080 -ProdPort 8081

param (
    [ValidateSet("Development", "UAT", "Production", "all")]
    [string]$Environment = "all",

    [int]$UatPort = 8080,
    [int]$ProdPort = 8081,

    [switch]$SkipPublish,
    [switch]$RunSideBySide,
    [switch]$NoServe,
    [switch]$OpenBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "BlazorEnvDemo.csproj"
$publishRoot = Join-Path $PSScriptRoot "publish"

function Publish-Env([string]$env) {
    $output = Join-Path $publishRoot $env
    Write-Host "`n--- Publishing: $env ---" -ForegroundColor Cyan
    dotnet publish $project -c Release "-p:WasmApplicationEnvironmentName=$env" -o $output
    if ($LASTEXITCODE -ne 0) { throw "Publish failed for $env" }
    Write-Host "Output: $output" -ForegroundColor Green
}

function Get-ServeCandidates {
    $candidates = New-Object System.Collections.Generic.List[string]

    $cmd = Get-Command dotnet-serve -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        $candidates.Add($cmd.Source)
    }

    $exeCandidate = Join-Path $env:USERPROFILE ".dotnet\tools\dotnet-serve.exe"
    $nativeCandidate = Join-Path $env:USERPROFILE ".dotnet\tools\dotnet-serve"

    if (Test-Path $exeCandidate) {
        $candidates.Add($exeCandidate)
    }
    if (Test-Path $nativeCandidate) {
        $candidates.Add($nativeCandidate)
    }

    # Last-resort command name (can still work if PATH resolves it).
    $candidates.Add("dotnet-serve")

    return $candidates | Select-Object -Unique
}

function Ensure-ServeTool {
    $initial = @(Get-ServeCandidates)
    if ($initial.Count -gt 0 -and (@($initial | Where-Object { $_ -ne "dotnet-serve" })).Count -gt 0) {
        return
    }

    Write-Host "dotnet-serve not detected reliably. Updating/Installing global tool..." -ForegroundColor Yellow
    dotnet tool update -g dotnet-serve | Out-Null
    if ($LASTEXITCODE -ne 0) {
        dotnet tool install -g dotnet-serve | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not install dotnet-serve. Run manually: dotnet tool install -g dotnet-serve"
        }
    }
}

function Show-EnvEvidence([string]$env) {
    $dotnetJs = Join-Path $publishRoot "$env\wwwroot\_framework\dotnet.js"
    $settingsPath = Join-Path $publishRoot "$env\wwwroot\appsettings.$env.json"
    if ($env -eq "Development") {
        $settingsPath = Join-Path $publishRoot "Development\wwwroot\appsettings.Development.json"
    }

    $envPattern = '"applicationEnvironment"\s*:\s*"' + [Regex]::Escape($env) + '"'
    $embedded = Select-String -Path $dotnetJs -Pattern $envPattern -Quiet
    $config = Get-Content $settingsPath -Raw | ConvertFrom-Json

    Write-Host "`n[$env] evidence" -ForegroundColor Magenta
    Write-Host "  applicationEnvironment embedded: $embedded"
    Write-Host "  EnvironmentLabel: $($config.AppConfig.EnvironmentLabel)"
    Write-Host "  ApiBaseUrl:       $($config.AppConfig.ApiBaseUrl)"
    Write-Host "  EnableDebugPanel: $($config.AppConfig.EnableDebugPanel)"
}

function Start-EnvServer([string]$env, [int]$port, [string[]]$serveCandidates) {
    $sitePath = Join-Path $publishRoot "$env\wwwroot"
    if (-not (Test-Path $sitePath)) {
        throw "Missing publish output for $env at $sitePath"
    }

    $args = @("-d", $sitePath, "-p", $port, "--quiet")

    foreach ($candidate in $serveCandidates) {
        try {
            $proc = Start-Process -FilePath $candidate -ArgumentList $args -PassThru
            Start-Sleep -Milliseconds 600
            if (-not $proc.HasExited) {
                Write-Host "Started $env on http://localhost:$port (PID $($proc.Id)) via $candidate" -ForegroundColor Green
                return $proc
            }
        }
        catch {
            # Try next candidate.
        }
    }

    throw "Unable to start dotnet-serve for $env. Try manually: dotnet-serve -d $sitePath -p $port"
}

if (-not $SkipPublish) {
    if ($Environment -eq "all" -or $Environment -eq "Development") { Publish-Env "Development" }
    if ($Environment -eq "all" -or $Environment -eq "UAT")         { Publish-Env "UAT" }
    if ($Environment -eq "all" -or $Environment -eq "Production")  { Publish-Env "Production" }
}
else {
    Write-Host "`nSkipping publish and using existing artifacts under: $publishRoot" -ForegroundColor Yellow
}

if ($Environment -eq "Development" -or $Environment -eq "all") { Show-EnvEvidence "Development" }
if ($Environment -eq "UAT" -or $Environment -eq "all")         { Show-EnvEvidence "UAT" }
if ($Environment -eq "Production" -or $Environment -eq "all")  { Show-EnvEvidence "Production" }

$shouldRunSideBySide = $RunSideBySide.IsPresent -or ($Environment -eq "all")

if (-not $NoServe -and $shouldRunSideBySide) {
    Ensure-ServeTool
    $serveCandidates = Get-ServeCandidates

    Write-Host "`n--- Starting side-by-side demo servers ---" -ForegroundColor Cyan
    $uatProc = Start-EnvServer "UAT" $UatPort $serveCandidates
    $prodProc = Start-EnvServer "Production" $ProdPort $serveCandidates

    Write-Host "`nSide-by-side demo is live:" -ForegroundColor Yellow
    Write-Host "  UAT        => http://localhost:$UatPort"
    Write-Host "  Production => http://localhost:$ProdPort"
    Write-Host "`nPress Ctrl+C in this terminal when done, then stop servers with:" -ForegroundColor Yellow
    Write-Host "  Stop-Process -Id $($uatProc.Id),$($prodProc.Id)"

    if ($OpenBrowser) {
        Start-Process "http://localhost:$UatPort"
        Start-Process "http://localhost:$ProdPort"
    }
}
elseif (-not $NoServe) {
    Write-Host "`nSingle-environment publish completed. Use -RunSideBySide to auto-host UAT + Production." -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Published artifacts: $publishRoot" -ForegroundColor Yellow
Write-Host "Quick manual serve commands:" -ForegroundColor Yellow
Write-Host "  dotnet-serve -d publish\UAT\wwwroot -p $UatPort"
Write-Host "  dotnet-serve -d publish\Production\wwwroot -p $ProdPort"
Write-Host "========================================`n" -ForegroundColor Yellow
