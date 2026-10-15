package;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

typedef CustomPrefsData = {
	var load_tutorial:Null<Bool>;
	var load_weeks:Null<Bool>;
	var ignoreModWeekBlocks:Null<Bool>;
	var default_note_asset_name:Null<String>;
	var title_tempo:Null<Int>;
}

class CustomPrefs
{
	public static var load_tutorial:Bool = true;
	public static var load_weeks:Bool = true;
	public static var ignoreModWeekBlocks:Bool = false;
	public static var default_note_asset_name:String = "NOTE_assets";
	public static var title_tempo:Int = 102;

	public static function loadPrefs()
	{
		load_tutorial = true;
		load_weeks = true;
		ignoreModWeekBlocks = false;
		default_note_asset_name = "NOTE_assets";
		title_tempo = 102;

		var path = Paths.json("customPrefs");
		if (path == null || !FileSystem.exists(path)) {
			path = "assets/fnf/data/customPrefs.json";
		}
		
		if (FileSystem.exists(path))
		{
			try {
				var data:CustomPrefsData = cast Json.parse(File.getContent(path));
				if (data.load_tutorial != null) load_tutorial = data.load_tutorial;
				if (data.load_weeks != null) load_weeks = data.load_weeks;
				if (data.ignoreModWeekBlocks != null) ignoreModWeekBlocks = data.ignoreModWeekBlocks;
				if (data.default_note_asset_name != null) default_note_asset_name = data.default_note_asset_name;
				if (data.title_tempo != null) title_tempo = data.title_tempo;
			} catch(e:Dynamic) {
				trace("Error parsing customPrefs.json: " + e);
			}
		}
	}
}
