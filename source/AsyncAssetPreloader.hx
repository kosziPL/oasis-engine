package;

#if sys
import sys.thread.Thread;
import sys.thread.Mutex;
import sys.io.File;
import sys.FileSystem;
#end

import openfl.Lib;
import haxe.io.Bytes;
import flixel.FlxG;

typedef PreloadJob = {
	var key:String;
	var folder:String;
	var library:String;
	var type:String; // 'sound', 'graphic'
	var priority:Int;
}

class AsyncAssetPreloader
{
	public static var isReady(get, never):Bool;
	
	private static var jobs:Array<PreloadJob> = [];
	private static var activeThreads:Int = 0;
	private static var maxThreads:Int = 4;
	private static var totalJobs:Int = 0;
	private static var completedJobs:Int = 0;
	
	private static var gcRetention:Array<Dynamic> = [];
	
	#if sys
	private static var mutex:Mutex;
	#end
	
	private static var startTime:Int = 0;
	private static var isRunning:Bool = false;

	static function get_isReady():Bool {
		if (totalJobs == 0) return true;
		return completedJobs >= totalJobs;
	}

	public static function kill():Void
	{
		isRunning = false;
		jobs = [];
		totalJobs = 0;
		completedJobs = 0;
		activeThreads = 0;
	}

	public static function addSoundJob(key:String, folder:String = 'sounds', priority:Int = 0) {
		jobs.push({key: key, folder: folder, library: null, type: 'sound', priority: priority});
		totalJobs++;
	}

	public static function addGraphicJob(key:String, library:String = null, priority:Int = 1) {
		jobs.push({key: key, folder: 'images', library: library, type: 'graphic', priority: priority});
		totalJobs++;
	}

	public static function init(songName:String, characters:Array<String>)
	{
		kill();
		isRunning = true;
		startTime = Lib.getTimer();
		
		#if sys
		if (mutex == null) mutex = new Mutex();
		#end

		// 1. Queue Inst and Vocals
		var songFormat = Paths.formatToSongPath(songName);
		addSoundJob(songFormat + '/Inst', 'songs', 0);
		addSoundJob(songFormat + '/Voices', 'songs', 0);

		// 2. Queue Characters (Extract image path from json)
		for (char in characters) {
			if (char != null && char.length > 0) {
				var charImage = getCharacterImage(char);
				if (charImage != null && charImage.length > 0) {
					addGraphicJob(charImage, null, 1);
				}
			}
		}

		// Sort jobs by priority
		jobs.sort(function(a, b) {
			if (a.priority < b.priority) return -1;
			if (a.priority > b.priority) return 1;
			return 0;
		});

		trace('AsyncAssetPreloader: Initialized with ' + totalJobs + ' jobs.');

		#if sys
		startThreads();
		#else
		// Fallback for HTML5 / non-sys platforms (synchronous)
		for (job in jobs) {
			processJobSync(job);
		}
		#end
	}

	private static function getCharacterImage(charName:String):String
	{
		var characterPath:String = 'characters/' + charName + '.json';
		
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!sys.FileSystem.exists(path)) {
			path = Paths.getPreloadPath(characterPath);
		}
		if (!sys.FileSystem.exists(path)) return null;
		
		try {
			var rawJson = sys.io.File.getContent(path);
			var json = haxe.Json.parse(rawJson);
			return Reflect.field(json, "image");
		} catch(e:Dynamic) {}
		#end
		
		return null;
	}

	#if sys
	private static function startThreads()
	{
		while (activeThreads < maxThreads && jobs.length > 0) {
			activeThreads++;
			Thread.create(workerLoop);
		}
	}

	private static function workerLoop()
	{
		while (isRunning)
		{
			var job:PreloadJob = null;
			
			mutex.acquire();
			if (jobs.length > 0) {
				job = jobs.shift();
			}
			mutex.release();

			if (job == null) {
				break; // No more jobs
			}

			// Process job
			var path:String = "";
			if (job.type == 'sound') {
				path = AssetHandler.getPath(job.key + '.' + Paths.SOUND_EXT, job.folder, job.library);
			} else if (job.type == 'graphic') {
				path = AssetHandler.getPath(job.key + '.png', job.folder, job.library);
			}

			var bytes:Bytes = null;
			var audioBuffer:lime.media.AudioBuffer = null;
			var bitmapData:openfl.display.BitmapData = null;
			
			if (sys.FileSystem.exists(path)) {
				try {
					var t0 = Lib.getTimer();
					bytes = sys.io.File.getBytes(path);
					var t1 = Lib.getTimer();
					trace('Job ' + job.key + ': File.getBytes took ' + (t1 - t0) + 'ms, size=' + (bytes != null ? Std.string(bytes.length) : 'NULL'));
					
					// Decode on worker thread
					var t2 = Lib.getTimer();
					if (job.type == 'sound' && bytes != null) {
						audioBuffer = lime.media.AudioBuffer.fromBytes(bytes);
						if (audioBuffer != null) gcRetention.push(audioBuffer);
						var t3 = Lib.getTimer();
						trace('Job ' + job.key + ': AudioBuffer.fromBytes took ' + (t3 - t2) + 'ms, buffer=' + (audioBuffer != null ? 'OK' : 'NULL'));
					} else if (job.type == 'graphic' && bytes != null) {
						var byteArray = openfl.utils.ByteArray.fromBytes(bytes);
						bitmapData = openfl.display.BitmapData.fromBytes(byteArray);
						if (bitmapData != null) gcRetention.push(bitmapData);
						var t3 = Lib.getTimer();
						trace('Job ' + job.key + ': BitmapData.fromBytes took ' + (t3 - t2) + 'ms, bitmapData=' + (bitmapData != null ? 'OK' : 'NULL'));
					}
					
				} catch(e:Dynamic) {
					trace('Job ' + job.key + ' (AsyncAssetPreloader): Failed to process ' + path + ' | Error: ' + e);
				}
			}

			// Pass to main thread
			MainThreadDispatcher.runOnMain(function() {
				if (!isRunning) return;

				var main_t0 = Lib.getTimer();
				if (job.type == 'sound') {
					if (audioBuffer != null) {
						gcRetention.remove(audioBuffer);
						AssetHandler.getSoundFromAudioBuffer(audioBuffer, path);
					}
				} else if (job.type == 'graphic') {
					if (bitmapData != null) {
						gcRetention.remove(bitmapData);
						AssetHandler.getGraphicFromBitmapData(bitmapData, path);
					}
				}
				var main_t1 = Lib.getTimer();
				trace('Job ' + job.key + ' main thread instantiation took ' + (main_t1 - main_t0) + 'ms');
				
				completedJobs++;
				
				if (completedJobs >= totalJobs) {
					var time = Lib.getTimer() - startTime;
					trace('AsyncAssetPreloader: Finished loading all assets in ' + time + 'ms.');
					
					// Check how many actually made it into the cache
					var soundCacheCount = 0;
					for (k in Paths.currentTrackedSounds.keys()) soundCacheCount++;
					var graphicCacheCount = 0;
					for (k in Paths.currentTrackedAssets.keys()) graphicCacheCount++;
					trace('AsyncAssetPreloader: Final cache count -> Sounds: ' + soundCacheCount + ' | Graphics: ' + graphicCacheCount);
					
					isRunning = false;
				}
			});
		}

		mutex.acquire();
		activeThreads--;
		mutex.release();
	}
	#end

	private static function processJobSync(job:PreloadJob)
	{
		if (job.type == 'sound') {
			AssetHandler.getSound(job.key, job.folder, job.library);
		} else if (job.type == 'graphic') {
			AssetHandler.getGraphic(job.key, job.library);
		}
		completedJobs++;
		if (completedJobs >= totalJobs) {
			var time = Lib.getTimer() - startTime;
			trace('AsyncAssetPreloader: Finished loading all assets synchronously in ' + time + 'ms.');
			isRunning = false;
		}
	}
}
