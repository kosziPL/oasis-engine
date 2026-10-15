package;

import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import bson.Bson;

using StringTools;

/**
 * Handle caching of parsed JSON charts as lightweight BSON binary files
 * for extreme file loading optimization.
 */
class ChartBSONHandler
{
	public static function loadChart(jsonPath:String):Dynamic
	{
		var bsonPath = jsonPath.substring(0, jsonPath.lastIndexOf('.')) + '.bson';
        
		if (!FileSystem.exists(jsonPath))
		{
			if (FileSystem.exists(bsonPath)) {
				trace('ChartBSONHandler: Fast-loading binary chart (JSON missing) from ' + bsonPath);
				var bytes = File.getBytes(bsonPath);
				return Bson.decode(bytes);
			}
			
			// Fallback: If it's an OpenFL asset (e.g. shared:assets/...) that isn't on the physical disk
			if (openfl.utils.Assets.exists(jsonPath))
			{
				trace('ChartBSONHandler: Falling back to OpenFL asset for ' + jsonPath);
				var rawJson = openfl.utils.Assets.getText(jsonPath).trim();
				var lastBraceIndex = rawJson.lastIndexOf("}");
				if (lastBraceIndex != -1 && lastBraceIndex < rawJson.length - 1)
				{
					rawJson = rawJson.substr(0, lastBraceIndex + 1);
				}
				return Json.parse(rawJson);
			}
			
			trace('ChartBSONHandler: Missing both files ' + jsonPath);
			return null;
		}
		
		var jsonTime = FileSystem.stat(jsonPath).mtime.getTime();
		
		if (!FileSystem.exists(bsonPath) || FileSystem.stat(bsonPath).mtime.getTime() <= jsonTime)
		{
			trace('ChartBSONHandler: BSON cache miss or JSON modified. Rebuilding ' + bsonPath);
			
			// Load standard JSON
			var rawJson = File.getContent(jsonPath).trim();
			
			// Some FNF charts have garbage data at the very end after the last brace.
			// We strip it here safely without causing an infinite loop if the brace is missing.
			var lastBraceIndex = rawJson.lastIndexOf("}");
			if (lastBraceIndex != -1 && lastBraceIndex < rawJson.length - 1)
			{
				rawJson = rawJson.substr(0, lastBraceIndex + 1);
			}
			
			var data:Dynamic = Json.parse(rawJson);
			
			// Save to BSON
			try {
				var bytes = Bson.encode(data);
				File.saveBytes(bsonPath, bytes);
			} catch (e:Dynamic) {
				trace('ChartBSONHandler: Failed to save BSON cache: ' + e);
			}
			
			return data;
		}
		else
		{
			trace('ChartBSONHandler: Fast-loading binary chart from ' + bsonPath);
			var bytes = File.getBytes(bsonPath);
			return Bson.decode(bytes);
		}
	}
}
