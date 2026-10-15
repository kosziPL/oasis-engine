package;

import flixel.FlxG;
import sys.thread.Thread;


class DynamicStreamLoader
{
	public static var isStreaming:Bool = false;
	private static var notesTotal:Array<Dynamic> = []; 
	
	private static var currentSectionIndex:Int = 0;
	private static var songSpeed:Float = 1;
	
	private static var targetState:PlayState;
	
	public static var streamChunkSize:Int = 2;
	
	public static function init(state:PlayState, songData:Dynamic, speed:Float):Void
	{
		targetState = state;
		isStreaming = true;
		songSpeed = speed;
		
		notesTotal = [];
		if (songData != null && songData.notes != null) {
			for (sec in (songData.notes : Array<Dynamic>)) {
				notesTotal.push(sec);
			}
		}
		
		currentSectionIndex = 0;
		
		if (PlayState.startOnTime > 0)
		{
			// Skip sections that are before the skip time to prevent them from streaming in late
			var skipSec = Math.floor(PlayState.startOnTime / (Conductor.stepCrochet * 16));
			if (skipSec > 2)
			{
				currentSectionIndex = skipSec - 2;
			}
		}
		
		var initialPreloadAmount:Int = currentSectionIndex + 8;
		if (initialPreloadAmount > notesTotal.length) initialPreloadAmount = notesTotal.length;
		
		trace('DynamicStreamLoader: Initial Preload from ' + currentSectionIndex + ' to ' + initialPreloadAmount);
		
		var startIndex = currentSectionIndex;
		for (i in startIndex...initialPreloadAmount) {
			processSectionOnMain(notesTotal[i]);
			currentSectionIndex++;
		}
		
		if (targetState != null && targetState.unspawnNotes != null) {
			targetState.unspawnNotes.sort(sortByShit);
		}
		
		if (currentSectionIndex < notesTotal.length) {
			Thread.create(backgroundStreamingProcess);
		} else {
			isStreaming = false;
		}
	}
	
	private static function backgroundStreamingProcess():Void
	{
		while (isStreaming && currentSectionIndex < notesTotal.length)
		{
			var curSec = (targetState != null) ? targetState.curSection : Math.floor(Conductor.songPosition / (Conductor.stepCrochet * 16));
			var targetSectionLimit = curSec + 15;
			
			if (currentSectionIndex < targetSectionLimit && currentSectionIndex < notesTotal.length)
			{
				var chunksToProcess = streamChunkSize;
				if (currentSectionIndex + chunksToProcess > notesTotal.length) {
					chunksToProcess = notesTotal.length - currentSectionIndex;
				}
				
				var chunkData:Array<Dynamic> = [];
				for (i in 0...chunksToProcess) {
					chunkData.push(notesTotal[currentSectionIndex + i]);
				}
				
				MainThreadDispatcher.runOnMain(function() {
					if (targetState == null || targetState.unspawnNotes == null) return;
					
					for (sec in chunkData) {
						processSectionOnMain(sec);
					}
					
					targetState.unspawnNotes.sort(sortByShit);
				});
				
				currentSectionIndex += chunksToProcess;
			}
			else
			{
				Sys.sleep(0.1); 
			}
		}
		
		isStreaming = false;
		trace('DynamicStreamLoader: Finished streaming all chart notes.');
	}
	
	public static function kill():Void 
	{
		isStreaming = false;
		targetState = null;
		notesTotal = [];
	}
	
	static function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return flixel.util.FlxSort.byValues(flixel.util.FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}
	
	
	private static function processSectionOnMain(section:Dynamic):Void
	{
		if (targetState == null) return;
		if (section.sectionNotes == null) return;
		
		for (songNotes in (section.sectionNotes : Array<Dynamic>))
		{
			var daStrumTime:Float = songNotes[0];
			var daNoteData:Int = Std.int(songNotes[1] % 4);
			var noteCharID:Int = Std.int(songNotes[1] / 4);

			var gottaHitNote:Bool = false;
			if (noteCharID == 1) gottaHitNote = true;
			else if (noteCharID < targetState.extraChars.length) {
				gottaHitNote = targetState.extraChars[noteCharID].isPlayer;
			}

			var oldNote:Note;
			if (targetState.unspawnNotes.length > 0)
				oldNote = targetState.unspawnNotes[Std.int(targetState.unspawnNotes.length - 1)];
			else
				oldNote = null;
				
			var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
			swagNote.charNoteID = noteCharID;
			swagNote.mustPress = gottaHitNote;
			swagNote.sustainLength = songNotes[2];
			swagNote.gfNote = (section.gfSection && (songNotes[1] < 4));
			swagNote.noteType = songNotes[3];
			
			if (!Std.isOfType(songNotes[3], String))
				swagNote.noteType = editors.ChartingState.noteTypeList[songNotes[3]]; 
				
			swagNote.scrollFactor.set();
			var susLength:Float = swagNote.sustainLength;

			susLength = susLength / Conductor.stepCrochet;
			targetState.unspawnNotes.push(swagNote);
			var floorSus:Int = Math.floor(susLength);

			if (floorSus > 0)
			{
				for (susNote in 0...floorSus + 1)
				{
					oldNote = targetState.unspawnNotes[Std.int(targetState.unspawnNotes.length - 1)];
					var sustainNote:Note = new Note(daStrumTime
						+ (Conductor.stepCrochet * susNote)
						+ (Conductor.stepCrochet / flixel.math.FlxMath.roundDecimal(songSpeed, 2)), daNoteData, oldNote, true);
						
					sustainNote.charNoteID = noteCharID;
					sustainNote.mustPress = gottaHitNote;
					sustainNote.gfNote = (section.gfSection && (songNotes[1] < 4));
					sustainNote.noteType = swagNote.noteType;
					sustainNote.scrollFactor.set();
					swagNote.tail.push(sustainNote);
					sustainNote.parent = swagNote;
					targetState.unspawnNotes.push(sustainNote);
					if (sustainNote.mustPress)
					{
						sustainNote.x += FlxG.width / 2; // general offset
					}
					else if (ClientPrefs.middleScroll)
					{
						sustainNote.x += 310;
						if (daNoteData > 1) // Up and Right
						{
							sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}
			}
			if (swagNote.mustPress)
			{
				swagNote.x += FlxG.width / 2; // general offset
			}
			else if (ClientPrefs.middleScroll)
			{
				swagNote.x += 310;
				if (daNoteData > 1) // Up and Right
				{
					swagNote.x += FlxG.width / 2 + 25;
				}
			}
		}
	}
}
