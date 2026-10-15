package;

import sys.FileSystem;
import sys.io.File;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;
import openfl.display.BitmapData;
import flash.media.Sound;
import haxe.Json;

using StringTools;

/**
 * A central handler for resolving all asset paths properly.
 * Supports a fallback system: priority.json > current mod > global mods > base fnf files > openfl library.
 */
class AssetHandler
{
	public static var priorityAssets:Map<String, String> = null;

	public static function init()
	{
		loadPriorityJson();
	}

	public static function loadPriorityJson()
	{
		if (priorityAssets != null) return;
		priorityAssets = new Map<String, String>();
		
		var path = 'assets/custom/priority.json';
		if (FileSystem.exists(path))
		{
			try
			{
				var data = Json.parse(File.getContent(path));
				var fields = Reflect.fields(data);
				for (f in fields)
				{
					priorityAssets.set(f, Reflect.field(data, f));
				}
			}
			catch (e:Dynamic)
			{
				trace('Error parsing priority.json: ' + e);
			}
		}
	}

	/**
	 * Main resolver for finding the correct file path.
	 * `key` is the relative path inside the folder, e.g. "BOYFRIEND.png"
	 * `folder` is the category folder, e.g. "images" or "sounds"
	 * `library` is the OpenFL library, e.g. "shared"
	 */
	public static function getPath(key:String, folder:String = '', library:String = null):String
	{
		var fullKey = (folder != '' && folder != null ? folder + '/' : '') + key;

		#if MODS_ALLOWED
		init(); // ensure priority json is loaded

		// 0. Base FNF (File System) ONLY if we are in FNF week (currentModDirectory empty)
		if (Paths.currentModDirectory == null || Paths.currentModDirectory == '')
		{
			var basePath = 'assets/fnf/$fullKey';
			if (FileSystem.exists(basePath)) return basePath;
		}

		// 1. Priority JSON
		if (priorityAssets != null && priorityAssets.exists(fullKey))
		{
			var mod = priorityAssets.get(fullKey);
			var path = 'assets/custom/$mod/$fullKey';
			if (FileSystem.exists(path)) return path;
		}

		// 2. Current Mod
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
		{
			var path = 'assets/custom/${Paths.currentModDirectory}/$fullKey';
			if (FileSystem.exists(path)) return path;
		}

		// 4. Global Mods
		for (mod in Paths.getGlobalMods())
		{
			var path = 'assets/custom/$mod/$fullKey';
			if (FileSystem.exists(path)) return path;
		}

		#end

		// 5. Base FNF (File System) as a final fallback for global mods or other mods
		var basePath = 'assets/fnf/$fullKey';
		if (FileSystem.exists(basePath)) return basePath;

		// 5. OpenFL Asset Path
		if (library != null && library != "preload" && library != "default")
		{
			return '$library:assets/fnf/$library/$fullKey';
		}
		if (Paths.currentLevel != null && Paths.currentLevel != "shared")
		{
			var levelID = '${Paths.currentLevel}:assets/fnf/${Paths.currentLevel}/$fullKey';
			if (OpenFlAssets.exists(levelID)) return levelID;
		}
		var sharedID = 'shared:assets/fnf/shared/$fullKey';
		if (OpenFlAssets.exists(sharedID)) return sharedID;
		
		return basePath;
	}

	public static function getGraphic(key:String, library:String = null):FlxGraphic
	{
		var path = getPath(key + '.png', 'images', library);
		
		if (Paths.currentTrackedAssets.exists(path))
		{
			if (!Paths.localTrackedAssets.contains(path))
			{
				Paths.localTrackedAssets.push(path);
			}
			return Paths.currentTrackedAssets.get(path);
		}

		var newGraphic:FlxGraphic = null;
		
		// If it exists natively on the filesystem (not an OpenFL prefixed string)
		if (FileSystem.exists(path))
		{
			var bitmap = BitmapData.fromFile(path);
			if (bitmap != null)
			{
				newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path);
			}
		}
		else if (OpenFlAssets.exists(path, IMAGE))
		{
			// Fallback to OpenFL cache (which understands 'shared:' etc.)
			newGraphic = FlxG.bitmap.add(path, false, path);
		}

		return __finalizeGraphic(newGraphic, path);
	}

	public static function getGraphicFromBitmapData(bitmap:BitmapData, path:String):FlxGraphic
	{
		if (Paths.currentTrackedAssets.exists(path))
		{
			if (!Paths.localTrackedAssets.contains(path)) Paths.localTrackedAssets.push(path);
			return Paths.currentTrackedAssets.get(path);
		}

		var newGraphic:FlxGraphic = null;
		if (bitmap != null)
		{
			try {
				newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path);
			} catch (e:Dynamic) {
				trace('getGraphicFromBitmapData: FlxGraphic.fromBitmapData THREW: ' + e);
			}
		}
		return __finalizeGraphic(newGraphic, path);
	}

	private static function __finalizeGraphic(newGraphic:FlxGraphic, path:String):FlxGraphic
	{
		if (newGraphic != null)
		{
			// ---- GPU CACHING ----
			if (ClientPrefs.gpuCaching) {
				// Upload tekstury do VRAM
				newGraphic.bitmap.getTexture(openfl.Lib.current.stage.context3D);
				newGraphic.bitmap.disposeImage();
			}

			newGraphic.persist = true;
			
			for (coreKey in Paths.coreAssetsToKeep) {
				if (path.endsWith('/' + coreKey + '.png') || path.endsWith('\\' + coreKey + '.png')) {
					Paths.excludeAsset(path);
					break;
				}
			}

			Paths.currentTrackedAssets.set(path, newGraphic);
			Paths.localTrackedAssets.push(path);
		}
		else
		{
			trace('AssetHandler could not load graphic: ' + path);
		}
		return newGraphic;
	}

	public static function getSparrowAtlas(key:String, library:String = null):FlxAtlasFrames
	{
		var graphic = getGraphic(key, library);
		if (graphic == null) return null;

		var xmlPath = getPath(key + '.xml', 'images', library);
		var xmlData:String = "";

		if (FileSystem.exists(xmlPath))
		{
			xmlData = File.getContent(xmlPath);
		}
		else if (OpenFlAssets.exists(xmlPath, TEXT))
		{
			xmlData = OpenFlAssets.getText(xmlPath);
		}

		if (xmlData == null || xmlData.length == 0) return null;
		
		return FlxAtlasFrames.fromSparrow(graphic, xmlData);
	}

	public static function getPackerAtlas(key:String, library:String = null):FlxAtlasFrames
	{
		var graphic = getGraphic(key, library);
		if (graphic == null) return null;

		var txtPath = getPath(key + '.txt', 'images', library);
		var txtData:String = "";

		if (FileSystem.exists(txtPath))
		{
			txtData = File.getContent(txtPath);
		}
		else if (OpenFlAssets.exists(txtPath, TEXT))
		{
			txtData = OpenFlAssets.getText(txtPath);
		}

		if (txtData == null || txtData.length == 0) return null;
		
		return FlxAtlasFrames.fromSpriteSheetPacker(graphic, txtData);
	}

	public static function getSound(key:String, folder:String = 'sounds', library:String = null):Sound
	{
		var path = getPath(key + '.' + Paths.SOUND_EXT, folder, library);
		
		if (Paths.currentTrackedSounds.exists(path))
		{
			if (!Paths.localTrackedAssets.contains(path))
			{
				Paths.localTrackedAssets.push(path);
			}
			return Paths.currentTrackedSounds.get(path);
		}
		
		var sound:Sound = null;
		if (FileSystem.exists(path))
		{
			sound = Sound.fromFile(path);
		}
		else
		{
			// Try OpenFL Sound Cache
			// Note: OpenFL expects sounds to sometimes not have the 'assets/' prefix if they are cached peculiarly,
			// but we will pass the exact path.
			if (OpenFlAssets.exists(path, SOUND) || OpenFlAssets.exists(path, MUSIC)) {
				sound = OpenFlAssets.getSound(path);
			}
		}

		return __finalizeSound(sound, path);
	}

	public static function getSoundFromAudioBuffer(buffer:lime.media.AudioBuffer, path:String):Sound
	{
		if (Paths.currentTrackedSounds.exists(path))
		{
			if (!Paths.localTrackedAssets.contains(path)) Paths.localTrackedAssets.push(path);
			return Paths.currentTrackedSounds.get(path);
		}

		var sound:Sound = null;
		if (buffer != null) {
			try {
				sound = Sound.fromAudioBuffer(buffer);
			} catch (e:Dynamic) {
				trace('getSoundFromAudioBuffer: Sound.fromAudioBuffer THREW: ' + e);
			}
		}
		return __finalizeSound(sound, path);
	}

	private static function __finalizeSound(sound:Sound, path:String):Sound
	{
		if (sound != null) {
			Paths.currentTrackedSounds.set(path, sound);
			Paths.localTrackedAssets.push(path);
			
			for (coreKey in Paths.coreAssetsToKeep) {
				if (path.endsWith('/' + coreKey + '.ogg') || path.endsWith('\\' + coreKey + '.ogg')) {
					Paths.excludeAsset(path);
					break;
				}
			}
		}
		return sound;
	}

	public static function getText(key:String, folder:String = 'data', library:String = null):String
	{
		var path = getPath(key, folder, library);

		if (FileSystem.exists(path))
		{
			return File.getContent(path);
		}
		else if (OpenFlAssets.exists(path, TEXT))
		{
			return OpenFlAssets.getText(path);
		}
		
		return null;
	}

	public static function fileExists(key:String, folder:String = '', type:AssetType = TEXT, library:String = null):Bool
	{
		var path = getPath(key, folder, library);
		if (FileSystem.exists(path)) return true;
		return OpenFlAssets.exists(path, type);
	}
}
