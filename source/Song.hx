package;

import Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	@:optional var extraChars:Array<CustomPissers>; 	// As an optional value (integration with null or older charts)

	var arrowSkin:String;
	var splashSkin:String;
	var validScore:Bool;

	var authors:Null<String>; // Required for JSON parsing/saving support
	@:optional var gameOverChar:Null<String>;
	@:optional var useCameraEditor:Null<Bool>;
}


// Stuff for Native Custom Characters

typedef CustomPissers = {
	var name:String;
	@:optional var isPlayer:Bool;
	@:optional var charID:Int;
	@:optional var isBelow:Bool;
	@:optional var noteSkin:String;
	@:optional var x:Float;
	@:optional var y:Float;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var isPlayer:Bool = false;
	public var charID:Int = 1;

	private static function onLoadJson(songJson:Dynamic) // Convert old charts to newest format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			songJson.player3 = null;
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}
	}

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static var chartCache:Map<String, String> = new Map();

	public static function clearChartCache():Void
	{
		chartCache.clear();
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		
		var path = Paths.json(formattedFolder + '/' + formattedSong);
		
		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson(formattedFolder + '/' + formattedSong);
		if(sys.FileSystem.exists(moddyFile)) {
			path = moddyFile;
		}
		#end

		var songData:Dynamic = null;
		
		#if sys
		songData = ChartBSONHandler.loadChart(path);
		#else
		var rawJson = openfl.utils.Assets.getText(path).trim();
		while (!rawJson.endsWith("}")) {
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}
		songData = haxe.Json.parse(rawJson);
		#end

		if(songData == null) {
			trace('FAILED TO LOAD SONG DATA FOR ' + path);
			return null;
		}

		var songJson:SwagSong = cast songData.song;
		songJson.validScore = true;
		
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		return swagShit;
	}
}
