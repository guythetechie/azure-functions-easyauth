using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Primitives;
using System.Linq;
using System.Text.Json.Nodes;
using System;
using System.Text.Json;

namespace function;

public class HelloWorld(ILogger<HelloWorld> logger)
{
    private static readonly JsonSerializerOptions serializerOptions = new() { WriteIndented = true };

    [Function("HelloWorld")]
    public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest request)
    {
        logger.LogInformation("C# HTTP trigger function processed a request.");

        var headerJson = SerializeHeaders(request.Headers);
        LogHeaderJson(headerJson);

        return new JsonResult(headerJson);
    }

    private static JsonObject SerializeHeaders(IHeaderDictionary headers) =>
        headers.Aggregate(new JsonObject(),
                          (json, header) => json.SetProperty(header.Key,
                                                             header.Value.ToJsonNode()));
                                                             
    private void LogHeaderJson(JsonObject json)
    {
        var jsonString = JsonSerializer.Serialize(json, serializerOptions);
        logger.LogInformation("Headers: {Headers}", jsonString);
        Console.WriteLine(jsonString);
    }
}

file static class Extensions
{
    public static JsonObject SetProperty(this JsonObject json, string key, JsonNode? value)
    {
        json[key] = value;

        return json;
    }

    public static JsonNode? ToJsonNode(this StringValues source) =>
        source switch
        {
            [var value] => value,
            var values => new JsonArray([.. values])
        };
}

