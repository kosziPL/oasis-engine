package;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;
import haxe.format.JsonParser;

using StringTools;

typedef WeekFile =
{
	// JSON variables
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var freeplayColor:Array<Int>;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
	var freeplayCategory:Int;
}

class WeekData {
	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];
	public var folder:String = '';
	
	// JSON variables
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var freeplayColor:Array<Int>;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;
	public var freeplayCategory:Int;

	public var fileName:String;

	public static function createWeekFile():WeekFile {
		var weekFile:WeekFile = {
			songs: [["Bopeebo", "dad", [146, 113, 253]], ["Fresh", "dad", [146, 113, 253]], ["Dad Battle", "dad", [146, 113, 253]]],
			weekCharacters: ['dad', 'bf', 'gf'],
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			freeplayColor: [146, 113, 253],
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: '',
			freeplayCategory: 0
		};
		return weekFile;
	}

	// HELP: Is there any way to convert a WeekFile to WeekData without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekFile:WeekFile, fileName:String) {
		songs = weekFile.songs;
		weekCharacters = weekFile.weekCharacters;
		weekBackground = weekFile.weekBackground;
		weekBefore = weekFile.weekBefore;
		storyName = weekFile.storyName;
		weekName = weekFile.weekName;
		freeplayColor = weekFile.freeplayColor;
		startUnlocked = weekFile.startUnlocked;
		hiddenUntilUnlocked = weekFile.hiddenUntilUnlocked;
		hideStoryMode = weekFile.hideStoryMode;
		hideFreeplay = weekFile.hideFreeplay;
		difficulties = weekFile.difficulties;
		freeplayCategory = weekFile.freeplayCategory;

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		
		#if MODS_ALLOWED
		var disabledMods:Array<String> = [];
		var modsListPath:String = 'customList.txt';
		var directories:Array<String> = [Paths.getPreloadPath(), Paths.mods()];
		var originalLength:Int = directories.length;

		if(FileSystem.exists(modsListPath))
		{
			var stuff:Array<String> = CoolUtil.coolTextFile(modsListPath);
			for (i in 0...stuff.length)
			{
				var splitName:Array<String> = stuff[i].trim().split('|');
				if(splitName[1] == '0') {
					disabledMods.push(splitName[0]);
				}
				else {
					var path = haxe.io.Path.join([Paths.mods(), splitName[0]]);
					if (sys.FileSystem.isDirectory(path) && !Paths.ignoreModFolders.contains(splitName[0]) && !disabledMods.contains(splitName[0]) && !directories.contains(path + '/')) {
						directories.push(path + '/');
					}
				}
			}
		}

		var modsDirectories:Array<String> = Paths.getModDirectories();
		var baseGameDisabled:Bool = false;
		for (folder in modsDirectories)
		{
			var pathThing:String = haxe.io.Path.join([Paths.mods(), folder]) + '/';
			if (!disabledMods.contains(folder) && !directories.contains(pathThing)) {
				directories.push(pathThing);
				
				var packJsonPath:String = haxe.io.Path.join([Paths.mods(), folder, 'pack.json']);
				if (sys.FileSystem.exists(packJsonPath)) {
					try {
						var packData:Dynamic = haxe.Json.parse(sys.io.File.getContent(packJsonPath));
						if (packData != null && Reflect.hasField(packData, "disable_base_game") && packData.disable_base_game == true) {
							baseGameDisabled = true;
						}
					} catch(e:Dynamic) {}
				}
			}
		}
		#else
		var directories:Array<String> = [Paths.getPreloadPath()];
		var originalLength:Int = directories.length;
		var baseGameDisabled:Bool = false;
		#end

		if (CustomPrefs.ignoreModWeekBlocks) {
			baseGameDisabled = false;
		}

		for (i in 0...directories.length) 
		{
			if (baseGameDisabled && i < originalLength) continue;

			var directory:String = directories[i] + 'weeks/';
			if(!sys.FileSystem.exists(directory)) continue;

			var loadedFromList:Array<String> = [];
			var weekListPath = directory + 'weekList.txt';
			if(sys.FileSystem.exists(weekListPath)) {
				var sexList:Array<String> = CoolUtil.coolTextFile(weekListPath);
				for (daWeek in sexList) {
					var path:String = directory + daWeek + '.json';
					if(sys.FileSystem.exists(path)) {
						addWeek(daWeek, path, directories[i], i, originalLength, isStoryMode);
						loadedFromList.push(daWeek);
					}
				}
			}

			for (file in sys.FileSystem.readDirectory(directory)) {
				var path = haxe.io.Path.join([directory, file]);
				if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json')) {
					var weekName = file.substr(0, file.length - 5);
					if(!loadedFromList.contains(weekName)) {
						addWeek(weekName, path, directories[i], i, originalLength, isStoryMode);
					}
				}
			}
		}
	}

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int, isStoryMode:Null<Bool>)
	{
		if (!CustomPrefs.load_tutorial && weekToCheck == 'tutorial') return;
		if (!CustomPrefs.load_weeks && directory == Paths.getPreloadPath() && weekToCheck != 'tutorial') return;
		
		var week:WeekFile = getWeekFile(path);
		if(week != null)
		{
			var weekFile:WeekData = new WeekData(week, weekToCheck);
			if(i >= originalLength)
			{
				#if MODS_ALLOWED
				weekFile.folder = directory.substring(Paths.mods().length, directory.length-1);
				#end
			}
			
			if((isStoryMode == null) || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))
			{
				var key = weekToCheck;
				if (weeksLoaded.exists(key) && weeksLoaded.get(key).folder != weekFile.folder) {
					key = weekToCheck + "_" + weekFile.folder;
				}
				if (!weeksLoaded.exists(key)) {
					weeksList.push(key);
				}
				weeksLoaded.set(key, weekFile);
			}
		}
	}

	private static function getWeekFile(path:String):WeekFile {
		var rawJson:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end

		if(rawJson != null && rawJson.length > 0) {
			return cast Json.parse(rawJson);
		}
		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	public static function getWeekFileName():String {
		return weeksList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():WeekData {
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromWeek(?data:WeekData = null) {
		Paths.currentModDirectory = '';
		if(data != null && data.folder != null && data.folder.length > 0) {
			Paths.currentModDirectory = data.folder;
		}
	}

	public static function loadTheFirstEnabledMod()
	{
		Paths.currentModDirectory = '';
		
		#if MODS_ALLOWED
		if (FileSystem.exists("customList.txt"))
		{
			var list:Array<String> = CoolUtil.listFromString(File.getContent("customList.txt"));
			var foundTheTop = false;
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1" && !foundTheTop)
				{
					foundTheTop = true;
					Paths.currentModDirectory = dat[0];
				}
			}
		}
		#end
	}
}