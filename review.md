# .NET 10 Publish Profile Environment Notes
 [2601200010001622]
> [!summary]
> For Blazor WebAssembly on .NET 10, client environment is selected at build or publish time. You can avoid csproj commits by setting the environment in the pipeline with `/p:WasmApplicationEnvironmentName=...` per stage.

https://learn.microsoft.com/en-us/aspnet/core/migration/90-to-100?view=aspnetcore-10.0&tabs=visual-studio#blazor-release-notes

---

## Usage Commands

```powershell
# Publish all 3 environments and start side-by-side servers
.\publish-demo.ps1

# Reuse existing artifacts (faster, no rebuild)
.\publish-demo.ps1 -SkipPublish -RunSideBySide

# Single environment only
.\publish-demo.ps1 -Environment UAT -NoServe

# Custom ports
.\publish-demo.ps1 -UatPort 8090 -ProdPort 8091

# Open browsers automatically
.\publish-demo.ps1 -OpenBrowser

# Stop running servers
Stop-Process -Id <PID1>,<PID2>  # Use the PIDs shown in output
```

---

## Customer Question

Can we deploy UAT or PROD without changing csproj or committing env-specific changes each time?

Yes. If the pipeline can pass MSBuild properties at publish time, no repo commit is required for environment switching.

---

## What Changed in .NET 10

### Publish Defaults to Production

For Blazor WebAssembly in .NET 10:

- The client environment defaults to `Development` for build and `Production` for publish.
- The environment must be set explicitly for publish outputs that target `UAT`, `Staging`, or custom values.
- `ASPNETCORE_ENVIRONMENT` on Azure App Service affects server-side runtime, not the WASM client bundle.
- `launchSettings.json` is debug-only and ignored by publish.

That means the app will load:

```text
appsettings.json
appsettings.Production.json
```

instead of:

```text
appsettings.UAT.json
```

---

## Root Cause for the Symptom

One or more of these is usually true:

| Cause | Result |
|---|---|
| Publish does not set `WasmApplicationEnvironmentName` | Client publish falls back to `Production` |
| Relying on `launchSettings.json` | Ignored during publish |
| App Service `ASPNETCORE_ENVIRONMENT=UAT` only | Server uses UAT, client bundle still built as Production |
| Expecting one published output to serve all environments | No longer reliable for standalone WASM |

---

## Recommended Fixes

### Fix 1: Pipeline-Driven Publish (No Additional Repo Commit)

Preferred when customer wants zero csproj changes.

Use this publish argument in each stage:

```bash
dotnet publish -c Release -p:WasmApplicationEnvironmentName=UAT
```

For PROD:

```bash
dotnet publish -c Release -p:WasmApplicationEnvironmentName=Production
```

Azure DevOps example:

```yaml
- task: DotNetCoreCLI@2
  displayName: Publish Blazor WASM
  inputs:
    command: publish
    projects: '**/Client.csproj'
    arguments: >
      -c Release
      -p:WasmApplicationEnvironmentName=$(WasmEnv)
      -o $(Build.ArtifactStagingDirectory)/$(WasmEnv)
```

GitHub Actions example:

```yaml
- name: Publish Blazor WASM
  run: |
    dotnet publish Client/Client.csproj \
      -c Release \
      -p:WasmApplicationEnvironmentName=${{ env.WASM_ENV }} \
      -o ./publish/${{ env.WASM_ENV }}
```

### Fix 2: Publish Profile or csproj Binding (Repo Change Required)

Use this only if pipeline arguments cannot be controlled.

In `Properties/PublishProfiles/UAT.pubxml` or project file:

```xml
<PropertyGroup>
  <WasmApplicationEnvironmentName>UAT</WasmApplicationEnvironmentName>
</PropertyGroup>
```

during publish.

---

## How to Verify

### Verify Client Environment (Authoritative)

In client `Program.cs`, temporarily log:

```csharp
Console.WriteLine($"Client Hosting Environment: {builder.HostEnvironment.Environment}");
```

Expected output should match `WasmApplicationEnvironmentName` used during publish.

### IIS or App Service Checks (Server-Side Only)

These are still valid for server behavior, but they don't choose WASM client environment:

After publish, `web.config` may include:

```xml
<environmentVariables>
  <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="UAT" />
</environmentVariables>
```

### Azure App Service

Check:

```text
Configuration -> Application settings
ASPNETCORE_ENVIRONMENT = UAT
```

Environment variables override `appsettings` files at runtime.

For WASM, this statement applies to the server process, not to already-published client static assets.

---

## Which Property to Use

| Scenario | Property |
|---|---|
| Standalone Blazor WebAssembly client publish | `WasmApplicationEnvironmentName` |
| ASP.NET Core server runtime (IIS/App Service process) | `ASPNETCORE_ENVIRONMENT` / `EnvironmentName` |

If the issue is client `appsettings.*.json` selection in WASM, use `WasmApplicationEnvironmentName`.

---

## Make Sure the Environment File Is Published

If needed, add this to the project file:

```xml
<ItemGroup>
  <None Include="appsettings.UAT.json"
        CopyToOutputDirectory="PreserveNewest"
        CopyToPublishDirectory="PreserveNewest" />
</ItemGroup>
```

---

## Common Traps

| Attempt | Why It Fails |
|---|---|
| `launchSettings.json` | Debug-only, not used for publish |
| Naming a profile `UAT` without setting WASM property | Cosmetic only |
| Having `appsettings.UAT.json` in the repo | Ignored unless the environment is set |
| Setting only App Service `ASPNETCORE_ENVIRONMENT` | Doesn't change static client bundle environment |
| Assuming pre-.NET 10 behavior | Not reliable or supported |

---

## Quick Checklist

- Pipeline passes `/p:WasmApplicationEnvironmentName=<TargetEnv>` per stage
- `appsettings.<TargetEnv>.json` is included in publish output
- Client logs show `builder.HostEnvironment.Environment == <TargetEnv>`
- Hosting `ASPNETCORE_ENVIRONMENT` is set correctly for server concerns
- No conflicting `Production` setting exists in Azure or IIS

---

## TL;DR

Customer can avoid extra commits by driving environment from pipeline publish arguments.

For Blazor WASM on .NET 10, use:

```bash
dotnet publish -p:WasmApplicationEnvironmentName=UAT
```

Use stage-specific values for UAT and PROD, and publish separate artifacts per environment.

Possible next steps:

- Add stage variables `WasmEnv=UAT` and `WasmEnv=Production` in pipeline
- Add a one-time client startup log check to validate selected environment
- Keep server `ASPNETCORE_ENVIRONMENT` for server-side behavior only
