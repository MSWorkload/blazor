using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using BlazorEnvDemo;
using BlazorEnvDemo.Models;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

builder.Services.AddScoped(sp =>
    new HttpClient { BaseAddress = new Uri(builder.HostEnvironment.BaseAddress) });

// Bind AppConfig section from whichever appsettings.<Env>.json was loaded at publish time.
builder.Services.Configure<AppConfig>(
    builder.Configuration.GetSection("AppConfig"));

// -----------------------------------------------------------------------
// PROOF #1 — Log the client environment to browser DevTools console.
//
// The value here is determined solely by WasmApplicationEnvironmentName
// passed at publish time, e.g.:
//   dotnet publish -p:WasmApplicationEnvironmentName=UAT
//
// ASPNETCORE_ENVIRONMENT on the server has NO effect on this value.
// launchSettings.json has NO effect on this value.
// -----------------------------------------------------------------------
Console.WriteLine("╔══════════════════════════════════════════════════╗");
Console.WriteLine($"║ Client Environment : {builder.HostEnvironment.Environment,-28}║");
Console.WriteLine($"║ API Base URL       : {builder.Configuration["AppConfig:ApiBaseUrl"],-28}║");
Console.WriteLine($"║ Environment Label  : {builder.Configuration["AppConfig:EnvironmentLabel"],-28}║");
Console.WriteLine("╚══════════════════════════════════════════════════╝");

await builder.Build().RunAsync();
