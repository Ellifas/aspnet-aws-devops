var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks();

var app = builder.Build();

app.MapGet("/", () =>
{
    return Results.Ok(new
    {
        service = "nextfit-challenge",
        status = "running",
        environment = app.Environment.EnvironmentName,
        timestampUtc = DateTime.UtcNow
    });
});

app.MapGet("/version", () =>
{
    return Results.Ok(new
    {
        application = "NextFit.App",
        framework = ".NET 8",
        version = "0.1.0"
    });
});

app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

app.Run();