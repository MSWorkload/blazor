# BlazorEnvDemo

A standalone Blazor WebAssembly application on **.NET 10** that proves the findings documented in
[review.md](../review.md) for Blazor WASM publish-time environment selection.

---

## What This Proves

| Finding | Evidence in This App |
|---------|----------------------|
| Client env is set at **publish time** via `WasmApplicationEnvironmentName` | Banner color, `EnvironmentLabel`, and `ApiBaseUrl` all change without any source edits |
| `ASPNETCORE_ENVIRONMENT` on App Service has **no effect** on the client bundle | Explained on the /proof page with live value |
| `launchSettings.json` is **ignored** during publish | Trap #3 on the /traps page |
| `dotnet run` defaults to **Development**, `dotnet publish` defaults to **Production** | Proof page comparison table |
| Separate publish artifacts are needed per environment | Demonstrated by the `publish-demo.ps1` script |
| `appsettings.UAT.json` must be in `wwwroot/` and explicitly published | Trap #4 on /traps, csproj `<None Include>` block |

---

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- Optional for serving publish output locally: `dotnet tool install -g dotnet-serve`

---

## Quick Start

### Run in Development mode

```powershell
cd BlazorEnvDemo
dotnet run
```

- Opens at `https://localhost:7001`
- Banner: **Blue** — `Development`
- `EnvironmentLabel`: `DEVELOPMENT — appsettings.Development.json loaded ✅`
- `EnableDebugPanel`: `true`

---

### Publish and compare environments side-by-side

```powershell
.\publish-demo.ps1
```

This publishes all three environments to `./publish/{Env}/`:

```text
publish/
├── Development/
├── UAT/
└── Production/
```

Serve them on different ports and compare:

```powershell
# Terminal 1 — UAT (orange banner)
dotnet-serve -d publish\UAT\wwwroot -p 8080 -o

# Terminal 2 — Production (green banner, no debug panel)
dotnet-serve -d publish\Production\wwwroot -p 8081 -o
```

---

## Manual Local Demo (No Script)

Use this when you want a repeatable local demo without `publish-demo.ps1`.

### 1) Open Terminal A in project folder

```powershell
cd C:\temp\Blazor\BlazorEnvDemo
```

### 2) Install/Update local static server tool once

```powershell
dotnet tool update -g dotnet-serve
```

If update fails (first-time install):

```powershell
dotnet tool install -g dotnet-serve
```

### 3) Stop stale local servers (optional but recommended)

```powershell
Get-Process dotnet-serve -ErrorAction SilentlyContinue | Stop-Process -Force
```

### 4) Publish UAT artifact

```powershell
dotnet publish -c Release /p:WasmApplicationEnvironmentName=UAT -o publish\UAT
```

### 5) Publish Production artifact

```powershell
dotnet publish -c Release /p:WasmApplicationEnvironmentName=Production -o publish\Production
```

### 6) Optional proof check (environment baked in)

```powershell
Select-String -Path publish\UAT\wwwroot\_framework\dotnet.js -Pattern '"applicationEnvironment"\s*:\s*"UAT"'
Select-String -Path publish\Production\wwwroot\_framework\dotnet.js -Pattern '"applicationEnvironment"\s*:\s*"Production"'
```

### 7) Run UAT in Terminal B

```powershell
dotnet-serve -d C:\temp\Blazor\BlazorEnvDemo\publish\UAT\wwwroot -p 8080
```

### 8) Run Production in Terminal C

```powershell
dotnet-serve -d C:\temp\Blazor\BlazorEnvDemo\publish\Production\wwwroot -p 8081
```

### 9) Open both URLs

```text
http://localhost:8080
http://localhost:8081
```

Expected:

- UAT: orange-style environment with UAT config values
- Production: green-style environment with Production config values

If one server fails to start:

- Try ports `8090` and `8091`.
- Re-run the stale-process cleanup command from step 3.

---

### Publish a single environment (no csproj change)

```powershell
# UAT
dotnet publish -c Release -p:WasmApplicationEnvironmentName=UAT -o ./publish/UAT

# Production
dotnet publish -c Release -p:WasmApplicationEnvironmentName=Production -o ./publish/Production
```

---

## How to Verify the Findings

### Visual check (no code)

| Environment | Banner color | `EnvironmentLabel` | `EnableDebugPanel` |
|-------------|-------------|-------------------|-------------------|
| Development | 🔵 Blue | `DEVELOPMENT — appsettings.Development.json loaded ✅` | `true` |
| UAT | 🟠 Orange | `UAT — appsettings.UAT.json loaded ✅` | `true` |
| Production | 🟢 Green | `PRODUCTION — appsettings.Production.json loaded ✅` | `false` |

### Console check (DevTools)

Open browser DevTools → Console after loading the published app:

```
╔══════════════════════════════════════════════════╗
║ Client Environment : UAT                         ║
║ API Base URL       : https://uat-api.example.com ║
║ Environment Label  : UAT — appsettings.UAT.json  ║
╚══════════════════════════════════════════════════╝
```

This log is written in `Program.cs` using `builder.HostEnvironment.Environment`.

---

## Project Structure

```text
BlazorEnvDemo/
├── BlazorEnvDemo.csproj          # No WasmApplicationEnvironmentName set — driven from pipeline
├── Program.cs                    # Logs environment + config to browser console (PROOF #1)
├── App.razor
├── _Imports.razor
├── Models/
│   └── AppConfig.cs              # Typed config bound from AppConfig section
├── Layout/
│   ├── MainLayout.razor          # Environment banner (color from appsettings)
│   └── MainLayout.razor.css
├── Pages/
│   ├── Home.razor                # 4 proof cards showing live evidence
│   ├── Proof.razor               # Detailed finding-by-finding walkthrough
│   └── Traps.razor               # 6 common mistakes with explanations
├── wwwroot/
│   ├── index.html
│   ├── appsettings.json                # Base (BannerColor grey)
│   ├── appsettings.Development.json    # Blue,  EnableDebugPanel true
│   ├── appsettings.UAT.json            # Orange, EnableDebugPanel true
│   └── appsettings.Production.json     # Green,  EnableDebugPanel false
├── Properties/
│   └── launchSettings.json       # Dev server only — ignored at publish
├── pipelines/
│   ├── azure-devops.yml          # ADO pipeline with per-stage WasmEnv variable
│   └── github-actions.yml        # GitHub Actions with per-job env variable
└── publish-demo.ps1              # Local script to publish all three envs
```

---

## How .NET 10 Bakes the Environment

When you run `dotnet publish /p:WasmApplicationEnvironmentName=UAT`, the SDK embeds this in
`wwwroot/_framework/dotnet.js` inside the published output:

```json
"applicationEnvironment": "UAT"
```

The WASM runtime reads this value at startup and sets `IWebAssemblyHostEnvironment.Environment`.
It then fetches `appsettings.UAT.json` as a static asset from the server.
**No server-side environment variable or runtime header is involved for standalone WASM.**

This was verified locally:
- `publish/UAT/_framework/dotnet.js` → `"applicationEnvironment": "UAT"`
- `publish/Production/_framework/dotnet.js` → `"applicationEnvironment": "Production"`

---

## Key Rule (TL;DR)

> For Blazor WASM on .NET 10, the client environment is a **publish-time concern**.  
> Use `-p:WasmApplicationEnvironmentName=<Env>` per pipeline stage.  
> Do **not** rely on `ASPNETCORE_ENVIRONMENT`, `launchSettings.json`, or the publish profile name.

---

## Pages

| Route | Purpose |
|-------|---------|
| `/` | Home — 4 live proof cards |
| `/proof` | Detailed finding-by-finding walkthrough |
| `/traps` | 6 common traps with explanations and fixes |
