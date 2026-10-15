package;

import animateatlas.AtlasFrameMaker;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.geom.Rectangle;
import flixel.math.FlxRect;
import haxe.xml.Access;
import openfl.system.System;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import flixel.FlxSprite;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import haxe.Json;
import flash.media.Sound;

using StringTools;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'events',
		'notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];
	#end

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function preloadCoreAssets():Void
	{
		#if sys
		sys.thread.Thread.create(function() {
			trace('--- CORE ASSETS PRELOAD: Started background preloading ---');
			var loadedCount = 0;
			for (coreKey in coreAssetsToKeep) {
				var isSound = coreKey.indexOf('intro') != -1 || coreKey.indexOf('missnote') != -1 || coreKey == 'hitsound' || coreKey == 'freakyMenu';
				var folder = isSound ? (coreKey == 'freakyMenu' ? 'music' : 'sounds') : 'images';
				var ext = isSound ? SOUND_EXT : 'png';
				var path = AssetHandler.getPath(coreKey + '.' + ext, folder, null);
				
				if (sys.FileSystem.exists(path)) {
					var bytes = sys.io.File.getBytes(path);
					if (bytes != null) {
						loadedCount++;
						if (isSound) {
							var audioBuffer = lime.media.AudioBuffer.fromBytes(bytes);
							MainThreadDispatcher.runOnMain(function() {
								AssetHandler.getSoundFromAudioBuffer(audioBuffer, path);
							});
						} else {
							var byteArray = openfl.utils.ByteArray.fromBytes(bytes);
							var bitmapData = openfl.display.BitmapData.fromBytes(byteArray);
							MainThreadDispatcher.runOnMain(function() {
								AssetHandler.getGraphicFromBitmapData(bitmapData, path);
							});
						}
					}
				}
			}
			trace('--- CORE ASSETS PRELOAD: Finished preloading ' + loadedCount + ' assets ---');
		});
		#end
	}

	public static var coreAssetsToKeep:Array<String> = [
		// UI and Ratings
		'sick', 'good', 'bad', 'shit', 'combo',
		'num0', 'num1', 'num2', 'num3', 'num4', 'num5', 'num6', 'num7', 'num8', 'num9',
		'healthBar', 'timeBar', 'noteSplashes', 'ready', 'set', 'go', 'oasis_arrows',
		
		// SFX and Music
		'intro1', 'intro2', 'intro3', 'introGo',
		'missnote1', 'missnote2', 'missnote3',
		'hitsound', 'freakyMenu'
	];

	public static var dumpExclusions:Array<String> = [
		'assets/fnf/music/freakyMenu.$SOUND_EXT',
		'assets/fnf/music/breakfast.$SOUND_EXT',
		'assets/fnf/music/tea-time.$SOUND_EXT',
		'assets/fnf/music/e.o.a.b..$SOUND_EXT' // Question for Jkb - Did your Ai know that you need to add eoab right here?
	];

	public static function clearUnusedMemory()
	{
		var keysToRemove:Array<String> = [];
		for (key in currentTrackedAssets.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				keysToRemove.push(key);
			}
		}

		for (key in keysToRemove)
		{
			var obj = currentTrackedAssets.get(key);
			@:privateAccess
			if (obj != null)
			{
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
				currentTrackedAssets.remove(key);
			}
		}

		#if cpp
		cpp.NativeGc.compact();
		cpp.NativeGc.run(true);
		#end
	}

	public static var localTrackedAssets:Array<String> = [];

	public static function clearStoredMemory(?cleanUnused:Bool = false)
	{
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key))
			{
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		var keysToRemove:Array<String> = [];
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
			{
				keysToRemove.push(key);
			}
		}

		for (key in keysToRemove)
		{
			Assets.cache.clear(key);
			currentTrackedSounds.remove(key);
		}
		
		localTrackedAssets = [];
		openfl.Assets.cache.clear("songs");

		#if cpp
		cpp.NativeGc.compact();
		cpp.NativeGc.run(true);
		#end
	}

	static public var currentModDirectory(default, set):String = '';

	static function set_currentModDirectory(value:String):String {
		currentModDirectory = value;
		CustomPrefs.loadPrefs();
		return currentModDirectory;
	}

	static public var currentLevel:String;

	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null)
	{
		return AssetHandler.getPath(file, '', library);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return AssetHandler.getPath(file, '', library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		return AssetHandler.getPath(file, '', library);
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/fnf/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return AssetHandler.getPath(file, '', library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return AssetHandler.getPath(key + '.txt', 'data', library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return AssetHandler.getPath(key + '.xml', 'data', library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return AssetHandler.getPath(key + '.json', 'data', library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return AssetHandler.getPath(key + '.frag', 'shaders', library);
	}

	inline static public function shaderVertex(key:String, ?library:String)
	{
		return AssetHandler.getPath(key + '.vert', 'shaders', library);
	}

	inline static public function lua(key:String, ?library:String)
	{
		return AssetHandler.getPath(key + '.lua', '', library);
	}

	static public function video(key:String)
	{
		return AssetHandler.getPath(key + '.' + VIDEO_EXT, 'videos', null);
	}

	static public function sound(key:String, ?library:String):Sound
	{
		return AssetHandler.getSound(key, 'sounds', library);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Sound
	{
		return AssetHandler.getSound(key, 'music', library);
	}

	inline static public function voices(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		return AssetHandler.getSound(songKey, 'songs');
	}

	inline static public function inst(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Inst';
		return AssetHandler.getSound(songKey, 'songs');
	}

	inline static public function image(key:String, ?library:String):FlxGraphic
	{
		return AssetHandler.getGraphic(key, library);
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		return AssetHandler.getText(key, '', null);
	}

	inline static public function font(key:String)
	{
		return AssetHandler.getPath(key, 'fonts');
	}

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		return AssetHandler.fileExists(key, '', type, library);
	}

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		return AssetHandler.getSparrowAtlas(key, library);
	}

	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		return AssetHandler.getPackerAtlas(key, library);
	}

	inline static public function formatToSongPath(path:String)
	{
		var invalidChars = ~/[~&\\;:<>#]/g;
		var hideChars = ~/[.,'"%?!]/g;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	public static function returnGraphic(key:String, ?library:String)
	{
		return AssetHandler.getGraphic(key, library);
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];

	public static function returnSound(path:String, key:String, ?library:String)
	{
		return AssetHandler.getSound(key, path, library);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
	{
		return 'assets/custom/' + key;
	}

	inline static public function modsFont(key:String)
	{
		return modFolders('fonts/' + key);
	}

	inline static public function modsJson(key:String)
	{
		return modFolders('data/' + key + '.json');
	}

	inline static public function modsVideo(key:String)
	{
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}

	inline static public function modsSounds(path:String, key:String)
	{
		return modFolders(path + '/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsImages(key:String)
	{
		return modFolders('images/' + key + '.png');
	}

	inline static public function modsXml(key:String)
	{
		return modFolders('images/' + key + '.xml');
	}

	inline static public function modsTxt(key:String)
	{
		return modFolders('images/' + key + '.txt');
	}

	static public function modFolders(key:String)
	{
		return AssetHandler.getPath(key, '');
	}

	public static var globalMods:Array<String> = [];

	public static function loadPriorityJson()
	{
		AssetHandler.init();
	}

	static public function getGlobalMods()
		return globalMods;

	static public function pushGlobalMods()
	{
		globalMods = [];
		var path:String = 'customList.txt';
		if (FileSystem.exists(path))
		{
			var list:Array<String> = CoolUtil.coolTextFile(path);
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1")
				{
					var folder = dat[0];
					var path = Paths.mods(folder + '/pack.json');
					if (FileSystem.exists(path))
					{
						try
						{
							var rawJson:String = File.getContent(path);
							if (rawJson != null && rawJson.length > 0)
							{
								var stuff:Dynamic = Json.parse(rawJson);
								var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
								if (global)
									globalMods.push(dat[0]);
							}
						}
						catch (e:Dynamic)
						{
							trace(e);
						}
					}
				}
			}
		}
		return globalMods;
	}

	static public function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		var modsFolder:String = 'assets/custom';
		if (FileSystem.exists(modsFolder))
		{
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (sys.FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder))
				{
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
