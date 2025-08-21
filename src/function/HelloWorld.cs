using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Linq;
using System.Text.Json.Nodes;
using System;
using System.Text.Json;

namespace function;

public class HelloWorld(ILogger<HelloWorld> logger)
{
    [Function("HelloWorld")]
    public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest request)
    {
        logger.LogInformation("C# HTTP trigger function processed a request.");

        var json = request.Headers.Aggregate(new JsonObject(),
                                             (json, header) =>
                                             {
                                                 json[header.Key] = header.Value switch
                                                 {
                                                     [var value] => value,
                                                     var values => new JsonArray([.. values])
                                                 };

                                                 return json;
                                             });

        var serializerOptions = new JsonSerializerOptions { WriteIndented = true };
        var jsonString = json.ToJsonString(serializerOptions);
        logger.LogInformation("Headers: {Headers}", jsonString);
        Console.WriteLine(jsonString);

        return new JsonResult(json);
    }
}

