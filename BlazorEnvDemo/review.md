# BlazorEnvDemo — Environment Switching Review

## Root Cause Finding

In **Blazor WebAssembly (.NET 10)**, the environment is a **build-time / publish-time concern**.  
It is controlled by the MSBuild property `WasmApplicationEnvironmentName`, NOT by:

| ❌ Does NOT work for WASM client | Why |
|---|---|
| `ASPNETCORE_ENVIRONMENT` in `launchSettings.json` | Server-side only, WASM client ignores it |
| `WasmApplicationEnvironmentName` as an env var in `launchSettings.json` | It is an MSBuild property, not a runtime env var |
| Publish profile name | Has no effect on the client environment |

At publish time, the SDK embeds the environment name directly into `wwwroot/_framework/dotnet.js`:
```json
"applicationEnvironment": "UAT"
```
The WASM runtime reads this at startup, sets `IWebAssemblyHostEnvironment.Environment`,
and fetches the matching `appsettings.<Env>.json` from the server as a static asset.

---

## Running Locally with PowerShell (dotnet run)

Use `-p:WasmApplicationEnvironmentName=<Env>` to pass the MSBuild property at run time.

### Development
```powershell
cd C:\temp\Blazor\BlazorEnvDemo
dotnet run -p:WasmApplicationEnvironmentName=Development --launch-profile "BlazorEnvDemo"
```
- Loads `wwwroot/appsettings.Development.json`
- Banner: 🔵 Blue (`#0d6efd`)
- URL: `https://localhost:7001`

### UAT
```powershell
cd C:\temp\Blazor\BlazorEnvDemo
dotnet run -p:WasmApplicationEnvironmentName=UAT --launch-profile "BlazorEnvDemo-UAT"
```
- Loads `wwwroot/appsettings.UAT.json`
- Banner: 🟠 Orange (`#fd7e14`)
- URL: `https://localhost:7002`

### Production
```powershell
cd C:\temp\Blazor\BlazorEnvDemo
dotnet run -p:WasmApplicationEnvironmentName=Production --launch-profile "BlazorEnvDemo"
```
- Loads `wwwroot/appsettings.Production.json`
- Banner:  Red
- URL: `https://localhost:7001`

---

## Publishing per Environment (dotnet publish)

```powershell
# Development
dotnet publish -c Release -p:WasmApplicationEnvironmentName=Development -o ./publish/Development

# UAT
dotnet publish -c Release -p:WasmApplicationEnvironmentName=UAT -o ./publish/UAT

# Production
dotnet publish -c Release -p:WasmApplicationEnvironmentName=Production -o ./publish/Production
```

---

## Running Published Output Locally

After publishing, serve each folder on a different port to compare side-by-side:

```powershell
# Development — port 8080
Start-Process pwsh -ArgumentList '-NoExit', '-Command', 'dotnet serve -p 8080 -d ./publish/Development/wwwroot'

# UAT — port 8081
Start-Process pwsh -ArgumentList '-NoExit', '-Command', 'dotnet serve -p 8081 -d ./publish/UAT/wwwroot'

# Production — port 8082
Start-Process pwsh -ArgumentList '-NoExit', '-Command', 'dotnet serve -p 8082 -d ./publish/Production/wwwroot'
```

> **Note:** If `dotnet serve` is not installed, run: `dotnet tool install -g dotnet-serve`

---

## Visual Studio — How to Run UAT from the Run Dropdown

1. Open `Properties/launchSettings.json` — a `BlazorEnvDemo-UAT` profile is already configured with:
   ```json
   "dotnetRunAdditionalArgs": "-p:WasmApplicationEnvironmentName=UAT"
   ```
2. Click the dropdown next to ▶ Run button
3. Select **BlazorEnvDemo-UAT**
4. Press **F5** or click ▶

> This works because `dotnetRunAdditionalArgs` passes the MSBuild property
> through `dotnet run` at build time — the only way it takes effect in VS.

---

## Verify the Correct Environment Loaded

### 1. Visual check
| Environment | Banner Color | Label in UI |
|---|---|---|
| Development | 🔵 Blue | `DEVELOPMENT — appsettings.Development.json loaded ✅` |
| UAT | 🟠 Orange | `UAT — appsettings.UAT.json loaded ✅` |
| Production | 🟢 Green | `PRODUCTION — appsettings.Production.json loaded ✅` |

### 2. Browser DevTools Console
Open DevTools (`F12`) → Console tab. You should see:
```
╔══════════════════════════════════════════════════╗
║ Client Environment : UAT                         ║
║ API Base URL       : https://uat-api.example.com ║
║ Environment Label  : UAT — appsettings.UAT.json  ║
╚══════════════════════════════════════════════════╝
```

### 3. Inspect the published JS asset
```powershell
Select-String -Path ".\publish\UAT\wwwroot\_framework\dotnet.js" -Pattern "applicationEnvironment"
```
Expected output: `"applicationEnvironment": "UAT"`

---

## Key Rule (TL;DR)

> For Blazor WASM on .NET 10, the environment is **baked in at build/publish time**.  
> Always pass `-p:WasmApplicationEnvironmentName=<Env>` via `dotnet run` or `dotnet publish`.  
> The `ASPNETCORE_ENVIRONMENT` env var has **zero effect** on the WASM client.
