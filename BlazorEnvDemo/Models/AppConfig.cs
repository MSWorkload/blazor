namespace BlazorEnvDemo.Models;

/// <summary>
/// Bound from the "AppConfig" section in whichever appsettings.{Environment}.json
/// is loaded at runtime. The values change per environment to prove that the correct
/// file was selected at publish time via WasmApplicationEnvironmentName.
/// </summary>
public class AppConfig
{
    /// <summary>
    /// A human-readable label that is unique per environment.
    /// Proving it shows the right value confirms the correct appsettings file was loaded.
    /// </summary>
    public string EnvironmentLabel { get; set; } = "Not Set — base appsettings.json only";

    /// <summary>
    /// Per-environment API endpoint. Changes between Development / UAT / Production.
    /// </summary>
    public string ApiBaseUrl { get; set; } = "https://api.example.com";

    /// <summary>
    /// A feature toggle that is on in Development and UAT but off in Production.
    /// Demonstrates that configuration values differ correctly per environment.
    /// </summary>
    public bool EnableDebugPanel { get; set; }

    /// <summary>
    /// Visible banner color for this environment (proves visual distinction at a glance).
    /// </summary>
    public string BannerColor { get; set; } = "#6c757d";
}
