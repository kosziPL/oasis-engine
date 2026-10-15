package;

import flixel.graphics.FlxGraphic;
#if desktop
import Discord.DiscordClient;
#end
import Section.SwagSection;
import Song.SwagSong;
import WiggleEffect.WiggleEffectType;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.utils.Assets;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.display.StageQuality;
import openfl.display.Sprite;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets as OpenFlAssets;
import editors.ChartingState;
import editors.CharacterEditorState;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import Note.EventNote;
import openfl.events.KeyboardEvent;
import flixel.effects.particles.FlxEmitter;
import flixel.effects.particles.FlxParticle;
import flixel.util.FlxSave;
import flixel.animation.FlxAnimationController;
import animateatlas.AtlasFrameMaker;
import Achievements;
import StageData;
import FunkinLua;
import DialogueBoxPsych;
import Conductor.Rating;
import StickersFadeTransition;
#if !flash
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if VIDEOS_ALLOWED
import vlc.MP4Handler;
#end

using StringTools;

// Yes, New camera system. V-Slice immersion is comming baby!!!

typedef CameraEvent = {
	var step:Float;
	var target_type:String;
	var target_id:Int;
	var is_relative:Bool;
	var x:Float;
	var y:Float;
	var zoom:Float;
	var ease:String;
	var duration:Float;
	var standalone:Bool;
	var lock_note_movement:Bool;
}

typedef CameraData = {
	var camera_events:Array<CameraEvent>;
}

class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	var _song:SwagSong;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], // From 0% to 19%
		['Shit', 0.4], // From 20% to 39%
		['Bad', 0.5], // From 40% to 49%
		['Bruh', 0.6], // From 50% to 59%
		['Meh', 0.69], // From 60% to 68%
		['Nice', 0.7], // 69%
		['Good', 0.8], // From 70% to 79%
		['Great', 0.9], // From 80% to 89%
		['Sick!', 1], // From 90% to 99%
		['Perfect!!', 1] // The value on this one isn't used actually, since Perfect is always "1"
	];

	// Split Screen Event Stuff
	public var camDad:FlxCamera;
	public var camBF:FlxCamera;
	public var isSplitScreen:Bool = false;
	var camDadPoint:FlxObject;
	var camBFPoint:FlxObject;
	var splitTweenDad:FlxTween;
	var splitTweenBF:FlxTween;

	// event variables
	private var isCameraOnForcedPos:Bool = false;

	#if (haxe >= "4.0.0") // Some backwards compatibility map support for chart editor
	public var boyfriendMap:Map<String, Boyfriend> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();

	public var variables:Map<String, Dynamic> = new Map();
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	#else
	public var boyfriendMap:Map<String, Boyfriend> = new Map<String, Boyfriend>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();
	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var modchartTweens:Map<String, FlxTween> = new Map();
	public var modchartSprites:Map<String, ModchartSprite> = new Map();
	public var modchartTimers:Map<String, FlxTimer> = new Map();
	public var modchartSounds:Map<String, FlxSound> = new Map();
	public var modchartTexts:Map<String, ModchartText> = new Map();
	public var modchartSaves:Map<String, FlxSave> = new Map();
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public var extraCharsGroupTop:flixel.group.FlxSpriteGroup;
	public var extraCharsGroupBottom:flixel.group.FlxSpriteGroup;

	public static var curStage:String = '';
	public var vanillaHandler:VanillaWeekHandler;
	public static var isPixelStage:Bool = false;
	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 2000;

	public var vocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Boyfriend = null;
	// Custom Characters
	// public var extraOpponents:Array<Character> = [];
	// public var extraPlayers:Array<Character> = [];
	public var extraChars:Array<Character> = [];
	public var cameraEvents:Array<CameraEvent> = [];
	public var activePosEvent:CameraEvent = null;
	public var activeZoomEvent:CameraEvent = null;
	public var isCameraEditor:Bool = false;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	private var strumLine:FlxSprite;

	// Handles the new epic mega sexy cam code that i've done
	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;

	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var comboX:Null<Float> = 0;
	public var comboY:Null<Float> = 0;
	public var rateX:Null<Float> = 0;
	public var rateY:Null<Float> = 0;

	public var camZooming:Bool = true;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;

	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health:Float = 1;
	public var visualHealth:Float = 1;
	public var combo:Int = 0;

	private var healthBarBG:AttachedSprite;

	public var healthBar:FlxBar;

	var songPercent:Float = 0;

	private var timeBarBG:AttachedSprite;

	public var timeBar:FlxBar;

	public var ratingsData:Array<Rating> = [];
	public var marvelouss:Int = 0;
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;
	public var misses:Int = 0;

	var ratingsText:FlxText;

	private var generatedMusic:Bool = false;

	public var endingSong:Bool = false;
	public var startingSong:Bool = false;

	private var updateTime:Bool = true;

	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;
	public static var editorPlaybackRate:Null<Float> = null;

	// Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var playerIcons:Array<HealthIcon> = [];
	public var opponentIcons:Array<HealthIcon> = [];
	public var charIconMap:Map<Character, HealthIcon> = new Map<Character, HealthIcon>();
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	var dialogue:Array<String> = ['blah blah blah', 'coolswag'];
	var dialogueJson:DialogueFile = null;

	var dadbattleBlack:BGSprite;
	var dadbattleLight:BGSprite;
	var dadbattleSmokes:FlxSpriteGroup;

	var halloweenBG:BGSprite;
	var halloweenWhite:BGSprite;


	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	public var newScoreTxt:FlxText; // NOWE!!! (Tworzenie textu pod score i rating z lewej)
	public var coolRates:FlxText; // Dla tekstu dla SS!!!, S!, A itp.

	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;
	var newScoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;
	public var smartCamera:Bool = true;
	public var smartCamZoomMult:Float = 1.0;


	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if desktop
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	// Achievement shit
	var keysPressed:Array<Bool> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Lua shit
	public static var instance:PlayState;

	public var luaArray:Array<FunkinLua> = [];
	public var charLuaArray:Array<FunkinLua> = [];

	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;

	public var introSoundsSuffix:String = '';

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;
	private var controlArray:Array<String>;

	public var precacheList:Map<String, String> = new Map<String, String>();

	// stores the last judgement object
	public static var lastRating:FlxSprite;
	// stores the last combo sprite object
	public static var lastCombo:FlxSprite;
	// stores the last combo score objects in an array
	public static var lastScore:Array<FlxSprite> = [];

	public function getCurBeat():Int { return curBeat; }
	override public function create()
	{
		trace('--- PLAYSTATE TIMING: Entered create() at ' + flixel.FlxG.game.ticks + 'ms ---');
		
		var initSoundCount = 0;
		for (k in Paths.currentTrackedSounds.keys()) initSoundCount++;
		var initGraphicCount = 0;
		for (k in Paths.currentTrackedAssets.keys()) initGraphicCount++;
		trace('--- PLAYSTATE CACHE: Initial state -> Sounds in RAM: ' + initSoundCount + ' | Graphics in RAM: ' + initGraphicCount + ' ---');
		
		try
		{
			// Reset judgements counter values to 0
		marvelouss = 0;
		sicks = 0;
		goods = 0;
		bads = 0;
		shits = 0;
		misses = 0;

		// trace('Playback Rate: ' + playbackRate)
		// (Memory cleared on destroy, not on create — lazy clearing for faster load)

		// for lua
		instance = this;

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		PauseSubState.songName = null; // Reset to default
		if (editorPlaybackRate != null) {
			playbackRate = editorPlaybackRate;
			editorPlaybackRate = null; // Reset for next times
		} else {
			playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);
		}

		// Initialize AsyncAssetPreloader
		var preloaderGf = SONG.gfVersion != null ? SONG.gfVersion : 'gf';
		AsyncAssetPreloader.init(SONG.song, [SONG.player1, SONG.player2, preloaderGf]);

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		controlArray = ['NOTE_LEFT', 'NOTE_DOWN', 'NOTE_UP', 'NOTE_RIGHT'];

		// Ratings
		var rating:Rating = new Rating('marvelous');
		rating.ratingMod = 1;
		rating.score = 500;
		rating.noteSplash = true;
		rating.hitWindow = 20;
		ratingsData.push(rating);

		var rating:Rating = new Rating('sick');
		rating.ratingMod = 1;
		rating.score = 300;
		rating.noteSplash = true;
		rating.hitWindow = 45;
		ratingsData.push(rating);

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		rating.hitWindow = 90;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.noteSplash = false;
		rating.hitWindow = 135;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		rating.hitWindow = 100000000;
		ratingsData.push(rating);

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);

		// Initialization of cameras
		camGame = new SmartCamera();
		camDad = new SmartCamera(0, 0, Math.floor(FlxG.width / 2), FlxG.height);
		cast(camDad, SmartCamera).smartClipping = false;
		camBF = new SmartCamera(Math.floor(FlxG.width / 2), 0, Math.floor(FlxG.width / 2), FlxG.height);
		cast(camBF, SmartCamera).smartClipping = false;
		camHUD = new SmartCamera();
		camOther = new SmartCamera();
		camDad.bgColor.alpha = 0;
		camBF.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		// Set initial camera visibility
		camDad.visible = false;
		camBF.visible = false;

		camDadPoint = new FlxObject(0, 0, 1, 1);
		camBFPoint = new FlxObject(0, 0, 1, 1);
		add(camDadPoint);
		add(camBFPoint);

		// CAMERA LAYER ORDERING IS KEY:
		FlxG.cameras.reset(camGame); // Bottom: Main gameplay camera
		FlxG.cameras.add(camDad, false); // Middle-Left: Left side split camera
		FlxG.cameras.add(camBF, false); // Middle-Right: Right side split camera
		FlxG.cameras.add(camHUD, false); // Top: Strums, UI HUD, Judgements
		FlxG.cameras.add(camOther, false); // Overlay: Pause, Transitions
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

		camDad.visible = false;
		camBF.visible = false;

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		CustomFadeTransition.nextCamera = camOther;

		if (FlxG.game != null)
		{
			FlxG.game.scrollRect = new openfl.geom.Rectangle(0, 0, FlxG.scaleMode.gameSize.x, FlxG.scaleMode.gameSize.y);
		}

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('tutorial', 'tutorial');

		normalizeOasisChart();

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		#if desktop
		storyDifficultyText = CoolUtil.difficulties[storyDifficulty];

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
		{
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		}
		else
		{
			detailsText = "Freeplay";
		}

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		var songName:String = Paths.formatToSongPath(SONG.song);

		curStage = SONG.stage;
		if (vanillaHandler == null) vanillaHandler = new VanillaWeekHandler(this);
		curStage = vanillaHandler.setVanillaStage(songName, SONG.stage);
		SONG.stage = curStage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		if (stageData == null)
		{ // Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = {
				directory: "",
				defaultZoom: 0.9,
				isPixelStage: false,

				boyfriend: [770, 100],
				girlfriend: [400, 130],
				opponent: [100, 100],
				hide_girlfriend: false,

				camera_boyfriend: [0, 0],
				camera_opponent: [0, 0],
				camera_girlfriend: [0, 0],
				camera_speed: 1,
				comboX: 0,
				comboY: 0,
				rateX: 0,
				rateY: 0 // Combo and rates have their position what's tied to BF's position, this is an offset for background
			};
		}

		defaultCamZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;
		comboX = (stageData.comboX != null) ? stageData.comboX : 0.0;
		comboY = (stageData.comboY != null) ? stageData.comboY : 0.0;
		rateX = (stageData.rateX != null) ? stageData.rateX : 0.0;
		rateY = (stageData.rateY != null) ? stageData.rateY : 0.0;
		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null) // Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		vanillaHandler.initStage(curStage);

		switch (Paths.formatToSongPath(SONG.song))
		{
			case 'stress':
				GameOverSubstate.characterName = 'bf-holding-gf-dead';
		}

		if (isPixelStage)
		{
			introSoundsSuffix = '-pixel';
		}

		add(gfGroup); // Needed for blammed lights

		extraCharsGroupBottom = new flixel.group.FlxSpriteGroup();
		add(extraCharsGroupBottom);

		// Shitty layering but whatev it works LOL
		if (curStage == 'limo')
			add(vanillaHandler.limo);

		add(dadGroup);
		add(boyfriendGroup);

		extraCharsGroupTop = new flixel.group.FlxSpriteGroup();
		add(extraCharsGroupTop);

		switch (curStage)
		{
			case 'spooky':
				add(halloweenWhite);
			case 'tank':
				add(vanillaHandler.foregroundSprites);
		}

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		// "GLOBAL" SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('scripts/'));
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/scripts/'));

		// Global mods should not inject their generic scripts into all songs
		// (Events are handled separately and still work globally)
		#end

		for (folder in foldersToCheck)
		{
			if (FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if (file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end

		// STAGE SCRIPTS
		#if (MODS_ALLOWED && LUA_ALLOWED)
		var doPush:Bool = false;
		var luaFile:String = 'stages/' + curStage + '.lua';
		if (FileSystem.exists(Paths.modFolders(luaFile)))
		{
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		}
		else
		{
			luaFile = Paths.getPreloadPath(luaFile);
			if (FileSystem.exists(luaFile))
			{
				doPush = true;
			}
		}

		if (doPush)
			luaArray.push(new FunkinLua(luaFile));
		#end

		var gfVersion = vanillaHandler.setVanillaGFVersion(curStage, SONG.song, SONG.gfVersion);
		SONG.gfVersion = gfVersion;


		if (!stageData.hide_girlfriend)
		{
			gf = new Character(0, 0, gfVersion);
			startCharacterPos(gf);
			gf.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
			startCharacterLua(gf);

			vanillaHandler.setupGF(gfVersion);

		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterLua(dad);
		extraChars.push(dad);

		boyfriend = new Boyfriend(0, 0, SONG.player1);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterLua(boyfriend);
		extraChars.push(boyfriend);

		if (SONG.extraChars != null) {
		    for (charData in cast(SONG.extraChars, Array<Dynamic>)) {
		    	if (charData == null || charData.name == null) continue;
		        var charX:Float = charData.x != null ? charData.x : 0;
		        var charY:Float = charData.y != null ? charData.y : 0;
		        var charIsPlayer:Bool = charData.isPlayer == true;
		        var newChar:Character = new Character(0, 0, charData.name);
		        newChar.isPlayer = charIsPlayer;
				setOnLuas(charData.name, newChar);
			
		        var isCharBelow:Bool = charData.isBelow == true;
		        if (newChar.isPlayer) {
					newChar.flipX = true;
		            newChar.x = boyfriend.x + charX;
		            newChar.y = boyfriend.y + charY;
		            startCharacterPos(newChar, false);
		        } else {
		            newChar.x = dad.x + charX;
		            newChar.y = dad.y + charY;
		            startCharacterPos(newChar, true); 
		        }
		        startCharacterLua(newChar);
		        extraChars.push(newChar);

		        if (isCharBelow) {
		            extraCharsGroupBottom.add(newChar);
		        } else {
		            extraCharsGroupTop.add(newChar);
		        }
		    }
		}

		var camPos:FlxPoint = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if (dad.curCharacter.startsWith('gf'))
		{
			dad.setPosition(GF_X, GF_Y);
			if (gf != null)
				gf.visible = false;
		}

		switch (curStage)
		{
			case 'limo':
				vanillaHandler.resetFastCar();
				addBehindGF(vanillaHandler.fastCar);

			case 'schoolEvil':
				var evilTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069); // nice
				addBehindDad(evilTrail);
		}

		var file:String = Paths.json(songName + '/dialogue'); // Checks for json/Psych Engine dialogue
		if (OpenFlAssets.exists(file))
		{
			dialogueJson = DialogueBoxPsych.parseDialogue(file);
		}

		var file:String = Paths.txt(songName + '/' + songName + 'Dialogue'); // Checks for vanilla/Senpai dialogue
		if (OpenFlAssets.exists(file))
		{
			dialogue = CoolUtil.coolTextFile(file);
		}
		var doof:DialogueBox = new DialogueBox(false, dialogue);
		// doof.x += 70;
		// doof.y = FlxG.height * 0.5;
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = startNextDialogue;
		doof.skipDialogueThing = skipDialogue;

		Conductor.songPosition = -5000;

		strumLine = new FlxSprite(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if (ClientPrefs.downScroll)
			strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();

		var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = showTime;
		if (ClientPrefs.downScroll)
			timeTxt.y = FlxG.height - 44;

		if (ClientPrefs.timeBarType == 'Song Name')
		{
			if (SONG.authors != null && SONG.authors != "")
			{
				timeTxt.text = SONG.authors + " - " + SONG.song;
			}
			else // Inaczej cipa bez chuja noway
			{
				timeTxt.text = SONG.song;
			}
		}
		updateTime = showTime;

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height / 4);
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = showTime;
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -4;
		timeBarBG.yAdd = -4;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; // How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);
		add(grpNoteSplashes);

		if (ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		// startCountdown();

		generateSong(SONG.song);

		// After all characters being loaded, it makes then invisible 0.01s later so that the player won't freeze when you change characters
		// add(strumLine);

		camFollow = new FlxPoint();
		camFollowPos = new FlxObject(0, 0, 1, 1);

		snapCamFollowToPos(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null)
		{
			camFollowPos = prevCamFollowPos;
			prevCamFollowPos = null;
		}
		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		// FlxG.camera.setScrollBounds(0, FlxG.width, 0, FlxG.height);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		FlxG.fixedTimestep = false;
		moveCameraSection();

		healthBarBG = new AttachedSprite(ClientPrefs.legacyUILayout ? 'healthBar' : 'healthBarLegacy');
		healthBarBG.y = FlxG.height * 0.89;
		if (ClientPrefs.legacyUILayout)
			healthBarBG.x = 150;
		else
			healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.visible = !ClientPrefs.hideHud;
		healthBarBG.xAdd = -4;
		healthBarBG.yAdd = -4;
		add(healthBarBG);
		if (ClientPrefs.downScroll)
			healthBarBG.y = 0.11 * FlxG.height;

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'visualHealth', 0, 2);
		healthBar.scrollFactor.set();
		// healthBar
		healthBar.visible = !ClientPrefs.hideHud;
		healthBar.alpha = ClientPrefs.healthBarAlpha;
		add(healthBar);
		healthBarBG.sprTracker = healthBar;

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.hideHud;
		iconP1.alpha = ClientPrefs.healthBarAlpha;
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.hideHud;
		iconP2.alpha = ClientPrefs.healthBarAlpha;
		add(iconP2);

		playerIcons = [iconP1];
		opponentIcons = [iconP2];

		charIconMap.set(boyfriend, iconP1);
		charIconMap.set(dad, iconP2);

		if (SONG.extraChars != null) {
			for (i in 2...extraChars.length) {
				var char:Character = extraChars[i];
				if (char != null) {
					var icon:HealthIcon = new HealthIcon(char.healthIcon, char.isPlayer);
					icon.y = healthBar.y - 75;
					icon.visible = !ClientPrefs.hideHud;
					icon.alpha = ClientPrefs.healthBarAlpha;
					add(icon);
					
					charIconMap.set(char, icon);
					
					if (char.isPlayer) {
						playerIcons.push(icon);
					} else {
						opponentIcons.push(icon);
					}
				}
			}
		}
		reloadHealthBarColors();

		scoreTxt = new FlxText(0, healthBarBG.y + 36, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud && !ClientPrefs.legacyUILayout;
		add(scoreTxt);

		// New stats info text cause old sucks

		newScoreTxt = new FlxText(20, 340, FlxG.width, "", 20);
		newScoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		newScoreTxt.scrollFactor.set();
		newScoreTxt.borderSize = 1.25;
		newScoreTxt.visible = !ClientPrefs.hideHud && ClientPrefs.legacyUILayout;
		add(newScoreTxt);

		// Rating

		coolRates = new FlxText(-150, 660, FlxG.width, "", 20);
		coolRates.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		coolRates.scrollFactor.set();
		coolRates.borderSize = 1.25;
		coolRates.visible = !ClientPrefs.hideHud && ClientPrefs.legacyUILayout;
		add(coolRates);
		if (ClientPrefs.downScroll)
		{
			coolRates.y = 30;
		}

		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		add(botplayTxt);
		ratingsText = new FlxText(FlxG.width - 220, 150, 200, "", 20);
		ratingsText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		ratingsText.y = 300;
		ratingsText.scrollFactor.set();
		ratingsText.visible = ClientPrefs.showingCounter && !ClientPrefs.hideHud && ClientPrefs.legacyUILayout;
		add(ratingsText);
		updateRatingsText();
		if (ClientPrefs.downScroll)
		{
			botplayTxt.y = timeBarBG.y - 78;
		}

		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		for (icon in playerIcons) {
			icon.cameras = [camHUD];
		}
		for (icon in opponentIcons) {
			icon.cameras = [camHUD];
		}
		scoreTxt.cameras = [camHUD];
		newScoreTxt.cameras = [camHUD];
		coolRates.cameras = [camHUD];
		ratingsText.cameras = [camHUD];
		botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		timeBarBG.cameras = [camHUD];
		timeTxt.cameras = [camHUD];
		doof.cameras = [camHUD];

		// if (SONG.song == 'South')
		// FlxG.camera.alpha = 0.7;
		// UI_camera.zoom = 1;

		// cameras = [FlxG.cameras.list[1]];
		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypeMap.keys())
		{
			#if MODS_ALLOWED
			var luaToLoad:String = Paths.modFolders('notetypes/' + notetype + '.lua');
			if (FileSystem.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('notetypes/' + notetype + '.lua');
				if (FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
			#elseif sys
			var luaToLoad:String = Paths.getPreloadPath('notetypes/' + notetype + '.lua');
			if (OpenFlAssets.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			#end
		}
		for (event in eventPushedMap.keys())
		{
			#if MODS_ALLOWED
			var luaToLoad:String = Paths.modFolders('events/' + event + '.lua');
			if (FileSystem.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('events/' + event + '.lua');
				if (FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
			#elseif sys
			var luaToLoad:String = Paths.getPreloadPath('events/' + event + '.lua');
			if (OpenFlAssets.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			#end
		}
		#end
		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		// SONG SPECIFIC SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/' + Paths.formatToSongPath(SONG.song) + '/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('data/' + Paths.formatToSongPath(SONG.song) + '/'));
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/data/' + Paths.formatToSongPath(SONG.song) + '/'));

		for (mod in Paths.getGlobalMods())
			foldersToCheck.insert(0,
				Paths.mods(mod + '/data/' + Paths.formatToSongPath(SONG.song) +
					'/')); // using push instead of insert because these should run after everything else
		#end

		for (folder in foldersToCheck)
		{
			if (FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if (file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		characterScripts();
		#end

		var daSong:String = Paths.formatToSongPath(curSong);
		if (isStoryMode && !seenCutscene)
		{
			if (!vanillaHandler.checkCutscene(daSong, doof))
				startCountdown();
			seenCutscene = true;
		}
		else
		{
			startCountdown();
		}
		RecalculateRating();

		// PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if (ClientPrefs.hitsoundVolume > 0)
			precacheList.set('hitsound', 'sound');
		precacheList.set('missnote1', 'sound');
		precacheList.set('missnote2', 'sound');
		precacheList.set('missnote3', 'sound');

		if (PauseSubState.songName != null)
		{
			precacheList.set(PauseSubState.songName, 'music');
		}
		else if (ClientPrefs.pauseMusic != 'None')
		{
			precacheList.set(Paths.formatToSongPath(ClientPrefs.pauseMusic), 'music');
		}

		precacheList.set('alphabet', 'image');

		#if desktop
		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end

		if (!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		callOnLuas('onCreatePost', []);

		super.create();

		cacheCountdown();
		cachePopUpScore();
		for (key => type in precacheList)
		{
			// trace('Key $key is type $type');
			switch (type)
			{
				case 'image':
					Paths.image(key);
				case 'sound':
					Paths.sound(key);
				case 'music':
					Paths.music(key);
			}
		}
		Paths.clearUnusedMemory();

		CustomFadeTransition.nextCamera = camOther;
		}
		catch (e:Dynamic)
		{
			try {
				if (FlxG.sound.music != null) FlxG.sound.music.stop();
			} catch (_) {}
			trace("CRASH IN PLAYSTATE CREATE: " + e);
			MusicBeatState.switchState(new GameCrashState(Std.string(e)));
		}
	}

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if (!ClientPrefs.shaders)
			return new FlxRuntimeShader();

		#if (!flash && MODS_ALLOWED && sys)
		if (!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if (!ClientPrefs.shaders)
			return false;

		if (runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));

		for (mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));

		for (folder in foldersToCheck)
		{
			if (FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if (FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else
					frag = null;

				if (FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else
					vert = null;

				if (found)
				{
					runtimeShaders.set(name, [frag, vert]);
					// trace('Found shader $name!');
					return true;
				}
			}
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
	}
	#end

	function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
		{
			var ratio:Float = value / songSpeed; // funny word huh
			for (note in notes)
				note.resizeByRatio(ratio);
			for (note in unspawnNotes)
				note.resizeByRatio(ratio);
		}
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		if (generatedMusic)
		{
			if (vocals != null)
				vocals.pitch = value;
			FlxG.sound.music.pitch = value;
		}
		playbackRate = value;
		FlxAnimationController.globalSpeed = value;
		trace('Anim speed: ' + FlxAnimationController.globalSpeed);
		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000 * value;
		setOnLuas('playbackRate', playbackRate);
		return value;
	}

	public function addTextToDebug(text:String, color:FlxColor)
	{
		#if LUA_ALLOWED
		luaDebugGroup.forEachAlive(function(spr:DebugLuaText)
		{
			spr.y += 20;
		});

		if (luaDebugGroup.members.length > 34)
		{
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup, color));
		#end
	}

	public function reloadHealthBarColors()
	{
		healthBar.createFilledBar(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));

		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int)
	{
		var characterPath:String = 'characters/' + newCharacter + '.json';
		var exists:Bool = false;
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (FileSystem.exists(path)) {
			exists = true;
		} else {
			path = Paths.getPreloadPath(characterPath);
			if (FileSystem.exists(path)) {
				exists = true;
			}
		}
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (OpenFlAssets.exists(path)) {
			exists = true;
		}
		#end

		if (!exists)
		{
			trace('Character JSON not found: ' + newCharacter);
			return;
		}

		switch (type)
		{
			case 0:
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterLua(newBoyfriend);
				}

			case 1:
				if (!dadMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterLua(newDad);
				}

			case 2:
				if (gf != null && !gfMap.exists(newCharacter))
				{
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterLua(newGf);
				}
		}
	}

	function startCharacterLua(char:Character)
	{
		if (char == null) return;
		var name:String = char.curCharacter;
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/' + name + '.lua';
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders(luaFile)))
		{
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		}
		else
		{
			luaFile = Paths.getPreloadPath(luaFile);
			if (FileSystem.exists(luaFile))
			{
				doPush = true;
			}
		}
		#else
		luaFile = Paths.getPreloadPath(luaFile);
		if (Assets.exists(luaFile))
		{
			doPush = true;
		}
		#end

		if (doPush)
		{
			for (script in luaArray)
			{
				if (script.scriptName == luaFile) {
					script.character = char;
					return;
				}
			}
			var newLua = new FunkinLua(luaFile);
			newLua.character = char;
			luaArray.push(newLua);
		}
		#end
	}

	public function getLuaObject(tag:String, text:Bool = true):FlxSprite
	{
		if (modchartSprites.exists(tag))
			return modchartSprites.get(tag);
		if (text && modchartTexts.exists(tag))
			return modchartTexts.get(tag);
		if (variables.exists(tag))
			return variables.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false)
	{
		if (gfCheck && char.curCharacter.startsWith('gf'))
		{ // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function startVideo(name:String)
	{
		#if VIDEOS_ALLOWED
		inCutscene = true;

		var filepath:String = Paths.video(name);
		#if sys
		if (!FileSystem.exists(filepath))
		#else
		if (!OpenFlAssets.exists(filepath))
		#end
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			startAndEnd();
			return;
		}

		var video:MP4Handler = new MP4Handler();
		video.playVideo(filepath);
		video.finishCallback = function()
		{
			startAndEnd();
			return;
		}
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		return;
		#end
	}

	function startAndEnd()
	{
		if (endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;

	public var psychDialogue:DialogueBoxPsych;

	// You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if (psychDialogue != null)
			return;

		if (dialogueFile.dialogue.length > 0)
		{
			inCutscene = true;
			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if (endingSong)
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					endSong();
				}
			}
			else
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		}
		else
		{
			FlxG.log.warn('Your dialogue file is badly formatted!');
			if (endingSong)
			{
				endSong();
			}
			else
			{
				startCountdown();
			}
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		introAssets.set('default', ['ready', 'set', 'go']);
		introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

		var introAlts:Array<String> = introAssets.get('default');
		if (isPixelStage)
			introAlts = introAssets.get('pixel');

		for (asset in introAlts)
			Paths.image(asset);

		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function eventShouldRunEarly(eventName:String):Bool
	{
		// Built-in hardcoded events that must always run early
		if (eventName == 'Change Character' || eventName == 'Change Icon')
		{
			return true;
		}

		// Custom Lua events: check if they have "runEarly" global variable set to true
		#if LUA_ALLOWED
		if (luaArray != null && luaArray.length > 0)
		{
			var ending:String = '/' + eventName + '.lua';
			var endingAlt:String = '\\' + eventName + '.lua';
			for (luaInstance in luaArray)
			{
				if (luaInstance != null && (luaInstance.scriptName.endsWith(ending) || luaInstance.scriptName.endsWith(endingAlt)))
				{
					llua.Lua.getglobal(luaInstance.lua, 'runEarly');
					var isTrue:Bool = llua.Lua.toboolean(luaInstance.lua, -1);
					llua.Lua.pop(luaInstance.lua, 1);
					if (isTrue) return true;
				}
			}
		}
		#end

		return false;
	}

	var startCountdownWaitLoops:Int = 0;
	public function startCountdown():Void
	{
		if (!AsyncAssetPreloader.isReady) {
			startCountdownWaitLoops++;
			if (startCountdownWaitLoops == 1) trace('--- PLAYSTATE TIMING: startCountdown() waiting for Preloader at ' + flixel.FlxG.game.ticks + 'ms ---');
			new flixel.util.FlxTimer().start(0.1, function(tmr:flixel.util.FlxTimer) {
				startCountdown();
			});
			return;
		}
		if (startCountdownWaitLoops > 0) trace('--- PLAYSTATE TIMING: Preloader ready! Waited ' + startCountdownWaitLoops + ' times. Continuing at ' + flixel.FlxG.game.ticks + 'ms ---');
		startCountdownWaitLoops = -1; // so it doesn't trigger again

		if (startedCountdown)
		{
			callOnLuas('onStartCountdown', []);
			return;
		}

		inCutscene = false;

		// Execute early events (placed at strumTime <= 0) before the countdown starts if they opt-in
		var i:Int = 0;
		while (i < eventNotes.length)
		{
			if (eventNotes[i].strumTime > 0)
				break;

			if (eventShouldRunEarly(eventNotes[i].event))
			{
				var value1:String = '';
				if (eventNotes[i].value1 != null)
					value1 = eventNotes[i].value1;

				var value2:String = '';
				if (eventNotes[i].value2 != null)
					value2 = eventNotes[i].value2;

				triggerEventNote(eventNotes[i].event, value1, value2);
				eventNotes.splice(i, 1);
			}
			else
			{
				i++;
			}
		}

		var ret:Dynamic = callOnLuas('onStartCountdown', [], false);
		if (ret != FunkinLua.Function_Stop)
		{
			if (skipCountdown || startOnTime > 0)
				skipArrowStartTween = true;

			generateStaticArrows(0, 0, 0);
			generateStaticArrows(1, 1, 0);
			for (i in 0...playerStrums.length)
			{
				setOnLuas('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnLuas('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length)
			{
				setOnLuas('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnLuas('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				// if(ClientPrefs.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;
			setOnLuas('startedCountdown', true);
			callOnLuas('onCountdownStarted', []);

			var swagCounter:Int = 0;

			if (startOnTime < 0)
				startOnTime = 0;

			if (startOnTime > 0)
			{
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return;
			}

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				if (gf != null
					&& tmr.loopsLeft % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0
					&& gf.animation.curAnim != null
					&& !gf.animation.curAnim.name.startsWith("sing")
					&& !gf.stunned)
				{
					gf.dance();
				}
				if (tmr.loopsLeft % boyfriend.danceEveryNumBeats == 0
					&& boyfriend.animation.curAnim != null
					&& !boyfriend.animation.curAnim.name.startsWith('sing')
					&& !boyfriend.stunned)
				{
					boyfriend.dance();
				}
				if (tmr.loopsLeft % dad.danceEveryNumBeats == 0
					&& dad.animation.curAnim != null
					&& !dad.animation.curAnim.name.startsWith('sing')
					&& !dad.stunned)
				{
					dad.dance();
				}

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				introAssets.set('default', ['ready', 'set', 'go']);
				introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

				var introAlts:Array<String> = introAssets.get('default');
				var antialias:Bool = ClientPrefs.globalAntialiasing;
				if (isPixelStage)
				{
					introAlts = introAssets.get('pixel');
					antialias = false;
				}

				// head bopping for bg characters on Mall
				if (curStage == 'mall')
				{
					if (!ClientPrefs.lowQuality)
						vanillaHandler.upperBoppers.dance(true);

					vanillaHandler.bottomBoppers.dance(true);
					vanillaHandler.santa.dance(true);
				}

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
					case 1:
						countdownReady = new FlxSprite().loadGraphic(Paths.image(introAlts[0]));
						countdownReady.cameras = [camHUD];
						countdownReady.scrollFactor.set();
						countdownReady.updateHitbox();

						if (PlayState.isPixelStage)
							countdownReady.setGraphicSize(Std.int(countdownReady.width * daPixelZoom));

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						insert(members.indexOf(notes), countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownReady);
								countdownReady.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
					case 2:
						countdownSet = new FlxSprite().loadGraphic(Paths.image(introAlts[1]));
						countdownSet.cameras = [camHUD];
						countdownSet.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownSet.setGraphicSize(Std.int(countdownSet.width * daPixelZoom));

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						insert(members.indexOf(notes), countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownSet);
								countdownSet.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
					case 3:
						countdownGo = new FlxSprite().loadGraphic(Paths.image(introAlts[2]));
						countdownGo.cameras = [camHUD];
						countdownGo.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownGo.setGraphicSize(Std.int(countdownGo.width * daPixelZoom));

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						insert(members.indexOf(notes), countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownGo);
								countdownGo.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
					case 4:
				}

				notes.forEachAlive(function(note:Note)
				{
					if (ClientPrefs.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if (ClientPrefs.middleScroll && !note.mustPress)
						{
							note.alpha *= 0.35;
						}
					}
				});
				callOnLuas('onCountdownTick', [swagCounter]);

				swagCounter += 1;
				// generateSong('fresh');
			}, 5);
		}
	}

	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}

	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}

	public function addBehindDad(obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = unspawnNotes[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = notes.members[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}

		while (eventNotes.length > 0)
		{
			if (eventNotes[0].strumTime < time)
			{
				var value1:String = '';
				if (eventNotes[0].value1 != null)
					value1 = eventNotes[0].value1;

				var value2:String = '';
				if (eventNotes[0].value2 != null)
					value2 = eventNotes[0].value2;

				triggerEventNote(eventNotes[0].event, value1, value2);
				eventNotes.shift();
			}
			else
			{
				break;
			}
		}
	}

	public function updateScore(miss:Bool = false)
	{
		if (ClientPrefs.legacyUILayout)
		{
			newScoreTxt.text = 'Score: '
				+ songScore
				+ '\nRating: '
				+ ratingName
				+ (ratingName != '?' ? ' (${Highscore.floorDecimal(ratingPercent * 100, 2)}%)' : '');

			coolRates.text = 'Rate: ' + ratingFC;
		}
		else
		{
			scoreTxt.text = 'Score: ' + songScore
				+ ' | Misses: ' + songMisses
				+ ' | Rating: ' + ratingName
				+ (ratingName != '?' ? ' (${Highscore.floorDecimal(ratingPercent * 100, 2)}%) - $ratingFC' : '');

			if (ClientPrefs.scoreZoom && !miss && !cpuControlled)
			{
				if (scoreTxtTween != null) {
					scoreTxtTween.cancel();
				}
				scoreTxt.scale.x = 1.075;
				scoreTxt.scale.y = 1.075;
				scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
					onComplete: function(twn:FlxTween) {
						scoreTxtTween = null;
					}
				});
			}
		}
		callOnLuas('onUpdateScore', [miss]);
	}

	public function setSongTime(time:Float)
	{
		if (time < 0)
			time = 0;

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.play();

		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = time;
			vocals.pitch = playbackRate;
		}
		vocals.play();
		Conductor.songPosition = time;
		songTime = time;
	}

	function startNextDialogue()
	{
		dialogueCount++;
		callOnLuas('onNextDialogue', [dialogueCount]);
	}

	function skipDialogue()
	{
		callOnLuas('onSkipDialogue', [dialogueCount]);
	}

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	function startSong():Void
	{
		trace('--- PLAYSTATE TIMING: Entered startSong() at ' + flixel.FlxG.game.ticks + 'ms ---');
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		if (SONG.needsVoices)
		{
			var voiceSound = Paths.voices(PlayState.SONG.song);
			if (voiceSound != null) vocals.loadEmbedded(voiceSound);
		}

		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.onComplete = finishSong.bind();
		
		vocals.play();
		vocals.pitch = playbackRate;
		if (vocals.playing)
		{
			vocals.time = FlxG.sound.music.time;
		}

		if (startOnTime > 0)
		{
			setSongTime(startOnTime - 500);
		}
		startOnTime = 0;
		trace('--- PLAYSTATE TIMING: Exited startSong() at ' + flixel.FlxG.game.ticks + 'ms ---');
		if (paused)
		{
			// trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		if (isStoryMode == false)
		{
			FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
			FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		}

		#if desktop
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnLuas('songLength', songLength);
		callOnLuas('onSongStart', []);
		
		trace('--- PLAYSTATE TIMING: Exited generateSong() at ' + flixel.FlxG.game.ticks + 'ms ---');
	}

	var debugNum:Int = 0;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();

	private function generateSong(dataPath:String):Void
	{
		trace('--- PLAYSTATE TIMING: Entered generateSong() at ' + flixel.FlxG.game.ticks + 'ms ---');
		// FlxG.log.add(ChartParser.parse());
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype', 'multiplicative');

		switch (songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		vocals = new FlxSound();
		vocals.pitch = playbackRate;
		FlxG.sound.list.add(vocals);

		notes = new FlxTypedGroup<Note>();
		add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

		var hasEventsFile:Bool = false;
		var songName:String = Paths.formatToSongPath(SONG.song);
		var file:String = Paths.json(songName + '/events');
		var fileExists:Bool = false;
		
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modsJson(songName + '/events')))
			fileExists = true;
		#end
		
		if (!fileExists && (FileSystem.exists(file) || OpenFlAssets.exists(file)))
			fileExists = true;
			
		if (!chartingMode && fileExists)
		{
			hasEventsFile = true;
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) // Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}

		cameraEvents = [];
		var cameraFile:String = getCameraPath(SONG.song);
		var cameraExists:Bool = false;
		#if MODS_ALLOWED
		if (sys.FileSystem.exists(cameraFile))
			cameraExists = true;
		#else
		if (OpenFlAssets.exists(cameraFile))
			cameraExists = true;
		#end

		if (cameraExists) {
			try {
				var content:String = "";
				#if sys
				content = sys.io.File.getContent(cameraFile);
				#else
				content = OpenFlAssets.getText(cameraFile);
				#end
				var parsed:CameraData = cast haxe.Json.parse(content);
				if (parsed != null && parsed.camera_events != null) {
					cameraEvents = parsed.camera_events;
					for (ev in cameraEvents) {
						if (Reflect.field(ev, "zoom") == null) ev.zoom = -1.0;
						if (ev.ease == null) ev.ease = "linear";
						if (ev.target_type == null) ev.target_type = "global";
					}
					cameraEvents.sort(function(a, b) return Reflect.compare(a.step, b.step));
				}
			} catch(e:Dynamic) {
				trace("Error loading camera JSON: " + e);
			}
		}

		// NEW SHIT: Dynamic Stream Loader for Notes (Loads 5% initially and rest on backend)
		DynamicStreamLoader.init(this, SONG, songSpeed);
		if (!hasEventsFile && songData.events != null)
		{
			for (event in songData.events) // Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}
		// trace(unspawnNotes.length);
		// playerCounter += 1;
		unspawnNotes.sort(sortByShit);
		if (eventNotes.length > 1)
		{ // No need to sort if there's a single one or none at all
			eventNotes.sort(sortByTime);
		}
		checkEventNote();
		generatedMusic = true;
	}

	function eventPushed(event:EventNote)
	{
		switch (event.event)
		{
			case 'Change Character':
				var val1:String = event.value1 != null ? event.value1.trim() : "";
				var val2:String = event.value2 != null ? event.value2.trim() : "";

				var val1Lower:String = val1.toLowerCase();
				var isType:Bool = (val1Lower == 'gf' || val1Lower == 'girlfriend' || val1Lower == 'bf' || val1Lower == 'boyfriend' || val1Lower == 'dad' || val1Lower == 'opponent');
				if (!isType)
				{
					var parsed:Null<Int> = Std.parseInt(val1);
					if (parsed != null && !Math.isNaN(parsed))
					{
						isType = true;
					}
				}

				if (!isType && val2 != "")
				{
					var temp:String = val1;
					val1 = val2;
					val2 = temp;
				}

				var charType:Int = 0;
				switch (val1.toLowerCase())
				{
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(val1);
						if (Math.isNaN(charType)) charType = 0;
				}

				var newCharacter:String = val2;
				addCharacterToList(newCharacter, charType);

			case 'Dadbattle Spotlight':
				dadbattleBlack = new BGSprite(null, -800, -400, 0, 0);
				dadbattleBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				dadbattleBlack.alpha = 0.25;
				dadbattleBlack.visible = false;
				add(dadbattleBlack);

				dadbattleLight = new BGSprite('spotlight', 400, -400);
				dadbattleLight.alpha = 0.375;
				dadbattleLight.blend = ADD;
				dadbattleLight.visible = false;

				dadbattleSmokes = new FlxSpriteGroup();
				dadbattleSmokes.alpha = 0.7;
				dadbattleSmokes.blend = ADD;
				dadbattleSmokes.visible = false;
				add(dadbattleLight);
				add(dadbattleSmokes);

				var offsetX = 200;
				var smoke:BGSprite = new BGSprite('smoke', -1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(15, 22);
				smoke.active = true;
				dadbattleSmokes.add(smoke);
				var smoke:BGSprite = new BGSprite('smoke', 1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(-15, -22);
				smoke.active = true;
				smoke.flipX = true;
				dadbattleSmokes.add(smoke);

			case 'Philly Glow':
				vanillaHandler.blammedLightsBlack = new FlxSprite(FlxG.width * -0.5,
					FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				vanillaHandler.blammedLightsBlack.visible = false;
				insert(members.indexOf(vanillaHandler.phillyStreet), vanillaHandler.blammedLightsBlack);

				vanillaHandler.phillyWindow = new BGSprite('philly/window', vanillaHandler.phillyWindow.x, vanillaHandler.phillyWindow.y, 0.3, 0.3);
				vanillaHandler.phillyWindow.setGraphicSize(Std.int(vanillaHandler.phillyWindow.width * 0.85));
				vanillaHandler.phillyWindow.updateHitbox();
				vanillaHandler.phillyWindow.visible = false;
				insert(members.indexOf(vanillaHandler.blammedLightsBlack) + 1, vanillaHandler.phillyWindow);

				vanillaHandler.phillyGlowGradient = new PhillyGlow.PhillyGlowGradient(-400, 225); // This shit was refusing to properly load FlxGradient so fuck it
				vanillaHandler.phillyGlowGradient.visible = false;
				insert(members.indexOf(vanillaHandler.blammedLightsBlack) + 1, vanillaHandler.phillyGlowGradient);
				if (!ClientPrefs.flashing)
					vanillaHandler.phillyGlowGradient.intendedAlpha = 0.7;

				precacheList.set('philly/particle', 'image'); // precache particle image
				vanillaHandler.phillyGlowParticles = new FlxTypedGroup<PhillyGlow.PhillyGlowParticle>();
				vanillaHandler.phillyGlowParticles.visible = false;
				insert(members.indexOf(vanillaHandler.phillyGlowGradient) + 1, vanillaHandler.phillyGlowParticles);
		}

		if (!eventPushedMap.exists(event.event))
		{
			eventPushedMap.set(event.event, true);
		}
	}

	function eventNoteEarlyTrigger(event:EventNote):Float
	{
		var returnedValue:Float = callOnLuas('eventEarlyTrigger', [event.event]);
		if (returnedValue != 0)
		{
			return returnedValue;
		}

		switch (event.event)
		{
			case 'Kill Henchmen': // Better timing so that the kill sound matches the beat intended
				return 280; // Plays 280ms before the actual position
		}
		return 0;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:EventNote, Obj2:EventNote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	public var skipArrowStartTween:Bool = false; // for lua

	private function generateStaticArrows(player:Int, charID:Int = 0, sideIndex:Int = 0):Void
	{
	    for (i in 0...4)
	    {
	        var targetAlpha:Float = 1;
	        if (player < 1)
	        {
	            if (!ClientPrefs.opponentStrums)
	                targetAlpha = 0;
	            else if (ClientPrefs.middleScroll)
	                targetAlpha = 0.35;
	        }

	        var babyArrow:StrumNote = new StrumNote(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player, charID, sideIndex);
	        babyArrow.downScroll = ClientPrefs.downScroll;
		
	        if (!isStoryMode && !skipArrowStartTween)
	        {
	            babyArrow.alpha = 0;
	            FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
	        }
	        else
	        {
	            babyArrow.alpha = targetAlpha;
	        }

	        if (player == 1)
	        {
	            playerStrums.add(babyArrow);
	        }
	        else
	        {
	            if (ClientPrefs.middleScroll)
	            {
	                babyArrow.x += 310;
	                if (i > 1)
	                { // Up and Right
	                    babyArrow.x += FlxG.width / 2 + 25;
	                }
	            }
	            opponentStrums.add(babyArrow);
	        }

	        strumLineNotes.add(babyArrow);
	        babyArrow.postAddedToGroup();
	    }
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (songSpeedTween != null)
				songSpeedTween.active = false;

			if (vanillaHandler.carTimer != null)
				vanillaHandler.carTimer.active = false;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars)
			{
				if (char != null && char.colorTween != null)
				{
					char.colorTween.active = false;
				}
			}

			for (tween in modchartTweens)
			{
				tween.active = false;
			}
			for (timer in modchartTimers)
			{
				timer.active = false;
			}
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;

			if (vanillaHandler.carTimer != null)
				vanillaHandler.carTimer.active = true;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars)
			{
				if (char != null && char.colorTween != null)
				{
					char.colorTween.active = true;
				}
			}

			for (tween in modchartTweens)
			{
				tween.active = true;
			}
			for (timer in modchartTimers)
			{
				timer.active = true;
			}
			paused = false;
			callOnLuas('onResume', []);

			#if desktop
			if (startTimer != null && startTimer.finished)
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
			#end
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		#if desktop
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0.0)
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
		}
		#end

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		#if desktop
		if (health > 0 && !paused)
		{
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
		#end

		super.onFocusLost();
	}

	function resyncVocals():Void
	{
		if (finishTimer != null)
			return;

		if (!FlxG.sound.music.playing)
			FlxG.sound.music.play();
		FlxG.sound.music.pitch = playbackRate;
		Conductor.songPosition = FlxG.sound.music.time;
		
		if (vocals != null)
		{
			// Check if vocals are actually out of sync with the music (OS audio thread)
			// rather than just the CPU songPosition. If they are in sync, don't seek!
			var vocalIsOutOfSync:Bool = Math.abs(vocals.time - FlxG.sound.music.time) > (20 * playbackRate);
			
			if (!vocals.playing || vocalIsOutOfSync) 
			{
				if (Conductor.songPosition <= vocals.length)
				{
					vocals.time = Conductor.songPosition;
				}
				if (!vocals.playing)
				{
					vocals.play();
				}
				vocals.pitch = playbackRate;
			} 
			else 
			{
				vocals.pitch = playbackRate;
			}
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var limoSpeed:Float = 0;

	override public function update(elapsed:Float)
	{
		if (vanillaHandler != null) vanillaHandler.update(elapsed);
		MainThreadDispatcher.pump();
		try
		{
			callOnLuas('onUpdate', [elapsed]);

		if (!inCutscene)
		{
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed * playbackRate, 0, 1);
			var isPosTransition:Bool = false;
			if (activePosEvent != null)
			{
				var durationInSteps:Float = activePosEvent.duration * 4;
				var stepFloat:Float = Conductor.songPosition / Conductor.stepCrochet;
				if (durationInSteps > 0 && stepFloat >= activePosEvent.step && stepFloat < activePosEvent.step + durationInSteps)
				{
					isPosTransition = true;
				}
			}

			if ((activePosEvent != null && activePosEvent.ease == "instant") || isPosTransition)
			{
				camFollowPos.setPosition(camFollow.x, camFollow.y);
			}
			else
			{
				camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			}
			if (!startingSong
				&& !endingSong
				&& boyfriend.animation.curAnim != null
				&& boyfriend.animation.curAnim.name.startsWith('idle'))
			{
				boyfriendIdleTime += elapsed;
				if (boyfriendIdleTime >= 0.15)
				{ // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			}
			else
			{
				boyfriendIdleTime = 0;
			}
		}

		if (isSplitScreen)
		{
			// Synchronizacja zoomu
			camDad.zoom = FlxG.camera.zoom;
			camBF.zoom = FlxG.camera.zoom;

			var dadMid = dad.getMidpoint();
			camDadPoint.setPosition(dadMid.x
				+ 50
				+ dad.cameraPosition[0]
				+ opponentCameraOffset[0],
				dadMid.y
				- 100
				+ dad.cameraPosition[1]
				+ opponentCameraOffset[1]);

			var bfMid = boyfriend.getMidpoint();
			camBFPoint.setPosition(bfMid.x
				- 0
				- boyfriend.cameraPosition[0]
				+ boyfriendCameraOffset[0],
				bfMid.y
				- 100
				+ boyfriend.cameraPosition[1]
				+ boyfriendCameraOffset[1]);

			camDad.focusOn(camDadPoint.getPosition());
			camBF.focusOn(camBFPoint.getPosition());
		}

		if (isSplitScreen && camDad != null && camBF != null)
		{
			camDad.zoom = camGame.zoom;
			camBF.zoom = camGame.zoom;


			for (m in members)
			{
				if (m != null && Std.isOfType(m, flixel.FlxSprite))
				{
					var spr:flixel.FlxSprite = cast m;

					if (spr.cameras != null && spr.cameras.contains(camGame) && !spr.cameras.contains(camDad))
					{
						if (!spr.cameras.contains(camHUD) && !spr.cameras.contains(camOther))
						{
							spr.cameras = [camGame, camDad, camBF];
						}
					}
				}
			}
		}

		super.update(elapsed);

		setOnLuas('curDecStep', curDecStep);
		setOnLuas('curDecBeat', curDecBeat);

		if (botplayTxt.visible)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnLuas('onPause', [], false);
			if (ret != FunkinLua.Function_Stop)
			{
				openPauseMenu();
			}
		}

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene)
		{
			openChartEditor();
		}

		// FlxG.watch.addQuick('VOL', vocals.amplitudeLeft);
		// FlxG.watch.addQuick('VOLRight', vocals.amplitudeRight);

		for (i in 0...playerIcons.length) {
			var icon = playerIcons[i];
			var targetScale:Float = (i == 0) ? 1.0 : 0.65;
			var mult:Float = FlxMath.lerp(targetScale, icon.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
			icon.scale.set(mult, mult);
			icon.updateHitbox();
		}

		for (i in 0...opponentIcons.length) {
			var icon = opponentIcons[i];
			var targetScale:Float = (i == 0) ? 1.0 : 0.65;
			var mult:Float = FlxMath.lerp(targetScale, icon.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
			icon.scale.set(mult, mult);
			icon.updateHitbox();
		}

		if (health > 2)
			health = 2;
		else if (health < 0)
			health = 0;

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 15 * playbackRate, 0, 1);
		visualHealth = FlxMath.lerp(visualHealth, health, lerpVal);
		healthBar.updateBar();

		var iconOffset:Int = 26;
		var barPos:Float = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01));

		// Symmetrical layout for companion icons with mirrored bounce physics
		if (playerIcons.length > 0) {
			var mainIcon = playerIcons[0];
			mainIcon.x = barPos + (150 * mainIcon.scale.x - 150) / 2 - iconOffset;
			mainIcon.y = healthBar.y - 75;

			for (i in 1...playerIcons.length) {
				var icon = playerIcons[i];
				// Sits on BF's right shoulder so it doesn't clip directly into his face
				icon.x = mainIcon.x + 60 + 40 * (mainIcon.scale.x - 1) + (i - 1) * 20;
				icon.y = mainIcon.y - 28;
			}
		}

		if (opponentIcons.length > 0) {
			var mainIcon = opponentIcons[0];
			mainIcon.x = barPos - (150 * mainIcon.scale.x) / 2 - iconOffset * 2;
			mainIcon.y = healthBar.y - 75;

			for (i in 1...opponentIcons.length) {
				var icon = opponentIcons[i];
				// Sits on Dad's left shoulder, mirrored outward flight on beat
				icon.x = mainIcon.x - 35 - 40 * (mainIcon.scale.x - 1) - (i - 1) * 20;
				icon.y = mainIcon.y - 28;
			}
		}

		for (icon in playerIcons) {
			if (healthBar.percent < 20)
				icon.animation.curAnim.curFrame = 1;
			else
				icon.animation.curAnim.curFrame = 0;
		}

		for (icon in opponentIcons) {
			if (healthBar.percent > 80)
				icon.animation.curAnim.curFrame = 1;
			else
				icon.animation.curAnim.curFrame = 0;
		}

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene)
		{
			persistentUpdate = false;
			paused = true;
			cancelMusicFadeTween();
			MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
		}

		if (startedCountdown)
		{
			Conductor.songPosition += FlxG.elapsed * 1000 * playbackRate;
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= 0)
				startSong();
			else if (!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5;
		}
		else
		{
			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
					// Conductor.songPosition += FlxG.elapsed * 1000;
					// trace('MISSED FRAME');
				}

				var curTime:Float = Conductor.songPosition - ClientPrefs.noteOffset;
				if (curTime < 0)
					curTime = 0;

				if (FlxG.sound.music != null && (curTime >= songLength || FlxG.sound.music.time >= FlxG.sound.music.length - 200) && !endingSong)
				{
					finishSong();
				}

				if (updateTime)
				{
					songPercent = (curTime / songLength);

					var songCalc:Float = (songLength - curTime);
					if (ClientPrefs.timeBarType == 'Time Elapsed')
						songCalc = curTime;

					var secondsTotal:Int = Math.floor(songCalc / 1000);
					if (secondsTotal < 0)
						secondsTotal = 0;

					if (ClientPrefs.timeBarType != 'Song Name')
						timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
				}
			}

			// Conductor.lastSongPos = FlxG.sound.music.time;
		}

		if (smartCamera && camGame != null && camGame.angle != 0)
		{
			var rad:Float = Math.abs(camGame.angle) * (Math.PI / 180);
			smartCamZoomMult = Math.abs(Math.cos(rad)) + (16.0 / 9.0) * Math.abs(Math.sin(rad));
		}
		else
		{
			smartCamZoomMult = 1.0;
		}

		if (smartCamera && camGame != null && camGame.angle != 0)
		{
			var rad:Float = Math.abs(camGame.angle) * (Math.PI / 180);
			smartCamZoomMult = Math.abs(Math.cos(rad)) + (16.0 / 9.0) * Math.abs(Math.sin(rad));
		}
		else
		{
			smartCamZoomMult = 1.0;
		}
		if (camZooming)
		{
			var isZoomTransition:Bool = false;
			if (activeZoomEvent != null)
			{
				var durationInSteps:Float = activeZoomEvent.duration * 4;
				var stepFloat:Float = Conductor.songPosition / Conductor.stepCrochet;
				if (durationInSteps > 0 && stepFloat >= activeZoomEvent.step && stepFloat < activeZoomEvent.step + durationInSteps)
				{
					isZoomTransition = true;
				}
			}

			var targetCamZoom:Float = defaultCamZoom * smartCamZoomMult;
			if ((activeZoomEvent != null && activeZoomEvent.ease == "instant") || isZoomTransition)
			{
				FlxG.camera.zoom = targetCamZoom;
			}
			else
			{
				FlxG.camera.zoom = FlxMath.lerp(targetCamZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
			}
			camHUD.zoom = FlxMath.lerp(1.0, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
		}
		else
		{
			if (smartCamera && camGame != null && camGame.angle != 0)
			{
				var minZoom:Float = defaultCamZoom * smartCamZoomMult;
				if (FlxG.camera.zoom < minZoom)
					FlxG.camera.zoom = FlxMath.lerp(minZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
			}
			if (smartCamera && camHUD != null && camHUD.angle != 0)
			{
				if (camHUD.zoom < 1.0)
					camHUD.zoom = FlxMath.lerp(1.0, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
			}
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime;
			if (songSpeed < 1)
				time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1)
				time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;
				callOnLuas('onSpawnNote', [
					notes.members.indexOf(dunceNote),
					dunceNote.noteData,
					dunceNote.noteType,
					dunceNote.isSustainNote
				]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic && !inCutscene)
		{
			if (!cpuControlled)
			{
				keyShit();
			}
			else if (boyfriend.animation.curAnim != null
				&& boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration
					&& boyfriend.animation.curAnim.name.startsWith('sing')
					&& !boyfriend.animation.curAnim.name.endsWith('miss'))
			{
				boyfriend.dance();
				// boyfriend.animation.curAnim.finish();
			}

			// HoldTimer dla player-type extra chars (isPlayer=true nie ma holdTimer w Character.hx)
			if (SONG.extraChars != null && FlxG.sound.music != null) {
				for (i in 2...extraChars.length) {
					var eChar:Character = extraChars[i];
					if (eChar != null && eChar.isPlayer && eChar.animation.curAnim != null
						&& eChar.animation.curAnim.name.startsWith('sing')
						&& !eChar.animation.curAnim.name.endsWith('miss')) {
						eChar.holdTimer += FlxG.elapsed;
						if (eChar.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * eChar.singDuration) {
							eChar.dance();
							eChar.holdTimer = 0;
						}
					}
				}
			}

			if (startedCountdown)
			{
				var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
				notes.forEachAlive(function(daNote:Note)
				{
					var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
					if (!daNote.mustPress)
						strumGroup = opponentStrums;

					var strumX:Float = strumGroup.members[daNote.noteData].x;
					var strumY:Float = strumGroup.members[daNote.noteData].y;
					var strumAngle:Float = strumGroup.members[daNote.noteData].angle;
					var strumDirection:Float = strumGroup.members[daNote.noteData].direction;
					var strumAlpha:Float = strumGroup.members[daNote.noteData].alpha;
					var strumScroll:Bool = strumGroup.members[daNote.noteData].downScroll;

					strumX += daNote.offsetX;
					strumY += daNote.offsetY;
					strumAngle += daNote.offsetAngle;
					strumAlpha *= daNote.multAlpha;

					if (strumScroll) // Downscroll
					{
						// daNote.y = (strumY + 0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
						daNote.distance = (0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed * daNote.multSpeed);
					}
					else // Upscroll
					{
						// daNote.y = (strumY - 0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
						daNote.distance = (-0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed * daNote.multSpeed);
					}

					var angleDir = strumDirection * Math.PI / 180;
					if (daNote.copyAngle)
						daNote.angle = strumDirection - 90 + strumAngle;

					// Support both 'Bot Note' and 'Bot Notes' due to dropdown naming differences
					var isBotNote:Bool = (daNote.noteType == 'Bot Note' || daNote.noteType == 'Bot Notes');
					if (daNote.copyAlpha)
						daNote.alpha = isBotNote ? 0 : strumAlpha;

					if (isBotNote) {
						daNote.visible = false;
					}

					if (daNote.copyX)
						daNote.x = strumX + Math.cos(angleDir) * daNote.distance;

					if (daNote.copyY)
					{
						daNote.y = strumY + Math.sin(angleDir) * daNote.distance;

						// Jesus fuck this took me so much mother fucking time AAAAAAAAAA
						if (strumScroll && daNote.isSustainNote)
						{
							if (daNote.animation.curAnim.name.endsWith('end'))
							{
								daNote.y += 10.5 * (fakeCrochet / 400) * 1.5 * songSpeed + (46 * (songSpeed - 1));
								daNote.y -= 46 * (1 - (fakeCrochet / 600)) * songSpeed;
								if (PlayState.isPixelStage)
								{
									daNote.y += 8 + (6 - daNote.originalHeightForCalcs) * PlayState.daPixelZoom;
								}
								else
								{
									daNote.y -= 19;
								}
							}
							daNote.y += (Note.swagWidth / 2) - (60.5 * (songSpeed - 1));
							daNote.y += 27.5 * ((SONG.bpm / 100) - 1) * (songSpeed - 1);
						}
					}

					if ((daNote.noteType == 'Bot Note' || daNote.noteType == 'Bot Notes') && daNote.strumTime <= Conductor.songPosition)
					{
						var altAnim:String = daNote.animSuffix;
						if (SONG.notes[curSection] != null && SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection)
						{
							altAnim = '-alt';
						}

						var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + altAnim;
						var char:Character = daNote.mustPress ? boyfriend : dad;
						if (daNote.charNoteID >= 0 && daNote.charNoteID < extraChars.length) {
							char = extraChars[daNote.charNoteID];
						}
						if (daNote.gfNote) {
							char = gf;
						}

						if (char != null) {
							char.playAnim(animToPlay, true);
							char.holdTimer = 0;
						}

						daNote.active = false;
						daNote.visible = false;
						daNote.kill();
						notes.remove(daNote, true);
						daNote.destroy();
						return;
					}

					if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
					{
						opponentNoteHit(daNote);
					}

					if (!daNote.blockHit && daNote.mustPress && cpuControlled && daNote.canBeHit)
					{
						if (daNote.isSustainNote)
						{
							if (daNote.canBeHit)
							{
								goodNoteHit(daNote);
							}
						}
						else if (daNote.strumTime <= Conductor.songPosition || daNote.isSustainNote)
						{
							goodNoteHit(daNote);
						}
					}

					var center:Float = strumY + Note.swagWidth / 2;
					if (strumGroup.members[daNote.noteData].sustainReduce
						&& daNote.isSustainNote
						&& (daNote.mustPress || !daNote.ignoreNote)
						&& (!daNote.mustPress || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
					{
						if (strumScroll)
						{
							if (daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center)
							{
								var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
								swagRect.height = (center - daNote.y) / daNote.scale.y;
								swagRect.y = daNote.frameHeight - swagRect.height;

								daNote.clipRect = swagRect;
							}
						}
						else
						{
							if (daNote.y + daNote.offset.y * daNote.scale.y <= center)
							{
								var swagRect = new FlxRect(0, 0, daNote.width / daNote.scale.x, daNote.height / daNote.scale.y);
								swagRect.y = (center - daNote.y) / daNote.scale.y;
								swagRect.height -= swagRect.y;

								daNote.clipRect = swagRect;
							}
						}
					}

					// Kill extremely late notes and cause misses
					if (Conductor.songPosition > noteKillOffset + daNote.strumTime)
					{
						if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
						{
							noteMiss(daNote);
						}

						daNote.active = false;
						daNote.visible = false;

						daNote.kill();
						notes.remove(daNote, true);
						daNote.destroy();
					}
				});
			}
			else
			{
				notes.forEachAlive(function(daNote:Note)
				{
					daNote.canBeHit = false;
					daNote.wasGoodHit = false;
				});
			}
		}
		checkEventNote();

		#if debug
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if (FlxG.keys.justPressed.TWO)
			{ // Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		setOnLuas('cameraX', camFollowPos.x);
		setOnLuas('cameraY', camFollowPos.y);
		setOnLuas('botPlay', cpuControlled);

		activePosEvent = null;
		activeZoomEvent = null;
		if (hasActiveCameraEvent())
		{
			updateCameraEvents(elapsed);
		}
		else if (ClientPrefs.camMove && camFollow != null && !inCutscene && !isCameraOnForcedPos)
		{
			var gpPos = getGameplayCameraPosition();
			var camX = gpPos.x;
			var camY = gpPos.y;
			gpPos.put();

			var section:Section.SwagSection = null;
			if (SONG.notes[curSection] != null)
			{
				section = SONG.notes[curSection];
			}

			var mainCharacter:Character = dad;
			if (section != null)
			{
				var secDynamic:Dynamic = section;
				var focusID:Int = (secDynamic.camFocus != null) ? secDynamic.camFocus : (section.mustHitSection ? 1 : 0);

				if (section.gfSection)
					mainCharacter = gf;
				else if (focusID >= 0 && focusID < extraChars.length)
					mainCharacter = extraChars[focusID];
			}

			var addX:Float = 0;
			var addY:Float = 0;
			var shift:Float = ClientPrefs.camMoveStrength;

			if (mainCharacter != null && mainCharacter.animation.curAnim != null)
			{
				var animName:String = mainCharacter.animation.curAnim.name;
				if (animName.startsWith('singLEFT'))
					addX = -shift;
				else if (animName.startsWith('singRIGHT'))
					addX = shift;
				else if (animName.startsWith('singUP'))
					addY = -shift;
				else if (animName.startsWith('singDOWN'))
					addY = shift;
			}
			camFollow.x = camX + addX;
			camFollow.y = camY + addY;
		}

		callOnLuas('onUpdatePost', [elapsed]);
		}
		catch (e:Dynamic)
		{
			try {
				if (FlxG.sound.music != null) FlxG.sound.music.stop();
			} catch (_) {}
			trace("CRASH IN PLAYSTATE UPDATE: " + e);
			MusicBeatState.switchState(new GameCrashState(Std.string(e)));
		}
	}

	function openPauseMenu()
	{
		var pauseSub:PauseSubState = new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y);
		pauseSub.cameras = [camOther]; // Pause menu MUST be on the highest camera 'cause in other cases split cameras will be higher than it.
		openSubState(pauseSub);

		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		// 1 / 1000 chance for Gitaroo Man easter egg
		/*if (FlxG.random.bool(0.1))
			{
				// gitaroo man easter egg
				cancelMusicFadeTween();
				MusicBeatState.switchState(new GitarooPause());
			}
			else { */
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.pause();
			vocals.pause();
		}
		openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
		// }

		#if desktop
		DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function openChartEditor()
	{
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		MusicBeatState.switchState(new ChartingState());
		chartingMode = true;

		#if desktop
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end
	}

	public var isDead:Bool = false; // Don't mess with this on Lua!!!

	function doDeathCheck(?skipHealthCheck:Bool = false)
	{
		if (chartingMode) return false;
		
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnLuas('onGameOver', [], false);
			if (ret != FunkinLua.Function_Stop)
			{
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				vocals.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				for (tween in modchartTweens)
				{
					tween.active = true;
				}
				for (timer in modchartTimers)
				{
					timer.active = true;
				}
				openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x - boyfriend.positionArray[0],
					boyfriend.getScreenPosition().y - boyfriend.positionArray[1], camFollowPos.x, camFollowPos.y));

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if desktop
				// Game Over doesn't get his own variable because it's only used here
				DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote()
	{
		while (eventNotes.length > 0)
		{
			var leStrumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < leStrumTime)
			{
				break;
			}

			var value1:String = '';
			if (eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if (eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEventNote(eventNotes[0].event, value1, value2);
			eventNotes.shift();
		}
	}

	public function getControl(key:String)
	{
		var pressed:Bool = Reflect.getProperty(controls, key);
		// trace('Control result: ' + pressed);
		return pressed;
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String)
	{
		if (vanillaHandler != null) vanillaHandler.triggerVanillaEvent(eventName, value1, value2);
		switch (eventName)
		{
			case 'Dadbattle Spotlight':
				var val:Null<Int> = Std.parseInt(value1);
				if (val == null)
					val = 0;

				switch (Std.parseInt(value1))
				{
					case 1, 2, 3: // enable and target dad
						if (val == 1) // enable
						{
							dadbattleBlack.visible = true;
							dadbattleLight.visible = true;
							dadbattleSmokes.visible = true;
							defaultCamZoom += 0.12;
						}

						var who:Character = dad;
						if (val > 2)
							who = boyfriend;
						// 2 only targets dad
						dadbattleLight.alpha = 0;
						new FlxTimer().start(0.12, function(tmr:FlxTimer)
						{
							dadbattleLight.alpha = 0.375;
						});
						dadbattleLight.setPosition(who.getGraphicMidpoint().x - dadbattleLight.width / 2, who.y + who.height - dadbattleLight.height + 50);

					default:
						dadbattleBlack.visible = false;
						dadbattleLight.visible = false;
						defaultCamZoom -= 0.12;
						FlxTween.tween(dadbattleSmokes, {alpha: 0}, 1, {
							onComplete: function(twn:FlxTween)
							{
								dadbattleSmokes.visible = false;
							}
						});
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if (Math.isNaN(value) || value < 1)
					value = 1;
				gfSpeed = value;

			case 'Philly Glow':
				var lightId:Int = Std.parseInt(value1);
				if (Math.isNaN(lightId))
					lightId = 0;

				var doFlash:Void->Void = function()
				{
					var color:FlxColor = FlxColor.WHITE;
					if (!ClientPrefs.flashing)
						color.alphaFloat = 0.5;

					FlxG.camera.flash(color, 0.15, null, true);
				};

				var chars:Array<Character> = [boyfriend, gf, dad];
				switch (lightId)
				{
					case 0:
						if (vanillaHandler.phillyGlowGradient.visible)
						{
							doFlash();
							if (ClientPrefs.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							vanillaHandler.blammedLightsBlack.visible = false;
							vanillaHandler.phillyWindow.visible = false;
							vanillaHandler.phillyGlowGradient.visible = false;
							vanillaHandler.phillyGlowParticles.visible = false;
							curLightEvent = -1;

							for (who in chars)
							{
								who.color = FlxColor.WHITE;
							}
							vanillaHandler.phillyStreet.color = FlxColor.WHITE;
						}

					case 1: // turn on
						curLightEvent = FlxG.random.int(0, vanillaHandler.phillyLightsColors.length - 1, [curLightEvent]);
						var color:FlxColor = vanillaHandler.phillyLightsColors[curLightEvent];

						if (!vanillaHandler.phillyGlowGradient.visible)
						{
							doFlash();
							if (ClientPrefs.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							vanillaHandler.blammedLightsBlack.visible = true;
							vanillaHandler.blammedLightsBlack.alpha = 1;
							vanillaHandler.phillyWindow.visible = true;
							vanillaHandler.phillyGlowGradient.visible = true;
							vanillaHandler.phillyGlowParticles.visible = true;
						}
						else if (ClientPrefs.flashing)
						{
							var colorButLower:FlxColor = color;
							colorButLower.alphaFloat = 0.25;
							FlxG.camera.flash(colorButLower, 0.5, null, true);
						}

						var charColor:FlxColor = color;
						if (!ClientPrefs.flashing)
							charColor.saturation *= 0.5;
						else
							charColor.saturation *= 0.75;

						for (who in chars)
						{
							who.color = charColor;
						}
						vanillaHandler.phillyGlowParticles.forEachAlive(function(particle:PhillyGlow.PhillyGlowParticle)
						{
							particle.color = color;
						});
						vanillaHandler.phillyGlowGradient.color = color;
						vanillaHandler.phillyWindow.color = color;

						color.brightness *= 0.5;
						vanillaHandler.phillyStreet.color = color;

					case 2: // spawn particles
						if (!ClientPrefs.lowQuality)
						{
							var particlesNum:Int = FlxG.random.int(8, 12);
							var width:Float = (2000 / particlesNum);
							var color:FlxColor = vanillaHandler.phillyLightsColors[curLightEvent];
							for (j in 0...3)
							{
								for (i in 0...particlesNum)
								{
									var particle:PhillyGlow.PhillyGlowParticle = new PhillyGlow.PhillyGlowParticle(-400
										+ width * i
										+ FlxG.random.float(-width / 5, width / 5),
										vanillaHandler.phillyGlowGradient.originalY
										+ 200
										+ (FlxG.random.float(0, 125) + j * 40), color);
									vanillaHandler.phillyGlowParticles.add(particle);
								}
							}
						}
						vanillaHandler.phillyGlowGradient.bop();
				}

			case 'Kill Henchmen':
				vanillaHandler.killHenchmen();

			case 'Add Camera Zoom':
				if (ClientPrefs.camZooms && FlxG.camera.zoom < 1.35)
				{
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if (Math.isNaN(camZoom))
						camZoom = 0.015;
					if (Math.isNaN(hudZoom))
						hudZoom = 0.03;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Trigger BG Ghouls':
				if (curStage == 'schoolEvil' && !ClientPrefs.lowQuality)
				{
					vanillaHandler.bgGhouls.dance(true);
					vanillaHandler.bgGhouls.visible = true;
				}

			case 'Play Animation':
				// trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch (value2.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if (Math.isNaN(val2))
							val2 = 0;

						switch (val2)
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if (camFollow != null)
				{
					var val1:Float = Std.parseFloat(value1);
					var val2:Float = Std.parseFloat(value2);
					if (Math.isNaN(val1))
						val1 = 0;
					if (Math.isNaN(val2))
						val2 = 0;

					isCameraOnForcedPos = false;
					if (!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2)))
					{
						camFollow.x = val1;
						camFollow.y = val2;
						isCameraOnForcedPos = true;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch (value1.toLowerCase().trim())
				{
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if (Math.isNaN(val))
							val = 0;

						switch (val)
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length)
				{
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null)
						duration = Std.parseFloat(split[0].trim());
					if (split[1] != null)
						intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration))
						duration = 0;
					if (Math.isNaN(intensity))
						intensity = 0;

					if (duration > 0 && intensity != 0)
					{
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var val1:String = value1 != null ? value1.trim() : "";
				var val2:String = value2 != null ? value2.trim() : "";

				var val1Lower:String = val1.toLowerCase();
				var isType:Bool = (val1Lower == 'gf' || val1Lower == 'girlfriend' || val1Lower == 'bf' || val1Lower == 'boyfriend' || val1Lower == 'dad' || val1Lower == 'opponent');
				if (!isType)
				{
					var parsed:Null<Int> = Std.parseInt(val1);
					if (parsed != null && !Math.isNaN(parsed))
					{
						isType = true;
					}
				}

				if (!isType && val2 != "")
				{
					var temp:String = val1;
					val1 = val2;
					val2 = temp;
				}

				var isGf:Bool = false;
				var charId:Int = 0;
				
				var parsedValue:String = val1.toLowerCase().trim();
				if (parsedValue == 'gf' || parsedValue == 'girlfriend') {
					isGf = true;
				} else {
					charId = Std.parseInt(val1);
					if (Math.isNaN(charId)) {
						if (parsedValue == 'dad' || parsedValue == 'opponent') {
							charId = 0;
						} else {
							charId = 1; // default to boyfriend/player
						}
					}
				}

				// Stop and remove the old script for the character we are changing
				var oldChar:Character = null;
				if (isGf) {
					oldChar = gf;
				} else if (charId == 0) {
					oldChar = dad;
				} else if (charId == 1) {
					oldChar = boyfriend;
				} else if (extraChars != null && charId < extraChars.length) {
					oldChar = extraChars[charId];
				}

				#if LUA_ALLOWED
				if (oldChar != null && oldChar.character_script != null && oldChar.character_script.length > 0) {
					var scriptToFind:String = oldChar.character_script;
					if (!scriptToFind.endsWith('.lua')) scriptToFind += '.lua';
					var fullPathToFind:String = AssetHandler.getPath('characters/scripts/' + scriptToFind);
					
					var i:Int = charLuaArray.length - 1;
					while (i >= 0) {
						if (charLuaArray[i] != null && charLuaArray[i].scriptName == fullPathToFind) {
							charLuaArray[i].call('onDestroy', []);
							charLuaArray[i].stop();
							charLuaArray.splice(i, 1);
						}
						i--;
					}
				}
				#end

				if (isGf)
				{
					if (gf != null)
					{
						if (gf.curCharacter != val2)
						{
							if (!gfMap.exists(val2))
							{
								addCharacterToList(val2, 2);
							}

							if (gfMap.exists(val2))
							{
								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(val2);
								gf.alpha = lastAlpha;
							}
						}
						setOnLuas('gfName', gf.curCharacter);
					}
				}
				else if (charId == 0)
				{
					if (dad.curCharacter != val2)
					{
						if (!dadMap.exists(val2))
						{
							addCharacterToList(val2, 1);
						}

						if (dadMap.exists(val2))
						{
							var wasGf:Bool = dad.curCharacter.startsWith('gf');
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(val2);
							if (extraChars.length > 0) extraChars[0] = dad;
							if (!dad.curCharacter.startsWith('gf'))
							{
								if (wasGf && gf != null)
								{
									gf.visible = true;
								}
							}
							else if (gf != null)
							{
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
							charIconMap.set(dad, iconP2);
						}
					}
					setOnLuas('dadName', dad.curCharacter);
				}
				else if (charId == 1)
				{
					if (boyfriend.curCharacter != val2)
					{
						if (!boyfriendMap.exists(val2))
						{
							addCharacterToList(val2, 0);
						}

						if (boyfriendMap.exists(val2))
						{
							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(val2);
							if (extraChars.length > 1) extraChars[1] = boyfriend;
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
							charIconMap.set(boyfriend, iconP1);
						}
					}
					setOnLuas('boyfriendName', boyfriend.curCharacter);
				}
				else
				{
					if (extraChars != null && charId < extraChars.length && extraChars[charId] != null)
					{
						var targetChar:Character = extraChars[charId];
						if (targetChar.curCharacter != val2)
						{
							var isPlayer:Bool = targetChar.isPlayer;
							var newChar:Character = null;
							if (isPlayer) {
								if (!boyfriendMap.exists(val2)) {
									addCharacterToList(val2, 0);
								}
								if (boyfriendMap.exists(val2)) {
									newChar = boyfriendMap.get(val2);
								}
							} else {
								if (!dadMap.exists(val2)) {
									addCharacterToList(val2, 1);
								}
								if (dadMap.exists(val2)) {
									newChar = dadMap.get(val2);
								}
							}

							if (newChar != null) {
								var lastAlpha:Float = targetChar.alpha;
								targetChar.alpha = 0.00001;
								
								extraChars[charId] = newChar;
								newChar.alpha = lastAlpha;
								newChar.isPlayer = isPlayer;

								newChar.x = targetChar.x;
								newChar.y = targetChar.y;
								newChar.flipX = targetChar.flipX;

								if (extraCharsGroupBottom.members.contains(targetChar)) {
									extraCharsGroupBottom.remove(targetChar);
									extraCharsGroupBottom.add(newChar);
								} else if (extraCharsGroupTop.members.contains(targetChar)) {
									extraCharsGroupTop.remove(targetChar);
									extraCharsGroupTop.add(newChar);
								}

								var icon:HealthIcon = charIconMap.get(targetChar);
								if (icon != null) {
									charIconMap.set(newChar, icon);
									icon.changeIcon(newChar.healthIcon);
								}
							}
						}
					}
				}
				reloadHealthBarColors();

				#if LUA_ALLOWED
				characterScripts();
				#end

			case 'Change Icon':
				var targetSide:String = value1.toLowerCase().trim();
				var iconValue:String = value2.trim();
				var iconTarget:HealthIcon = null;
				
				if (targetSide == 'bf' || targetSide == 'player' || targetSide == '0') {
					iconTarget = iconP1;
				} else if (targetSide == 'dad' || targetSide == 'opponent' || targetSide == '1') {
					iconTarget = iconP2;
				} else if (targetSide.startsWith('extrabf')) {
					var idx:Int = 1;
					var suffix:String = targetSide.substring(7);
					if (suffix.length > 0) {
						var parsedIdx = Std.parseInt(suffix);
						if (parsedIdx != null && !Math.isNaN(parsedIdx)) idx = parsedIdx;
					}
					if (idx < playerIcons.length) iconTarget = playerIcons[idx];
				} else if (targetSide.startsWith('extradad')) {
					var idx:Int = 1;
					var suffix:String = targetSide.substring(8);
					if (suffix.length > 0) {
						var parsedIdx = Std.parseInt(suffix);
						if (parsedIdx != null && !Math.isNaN(parsedIdx)) idx = parsedIdx;
					}
					if (idx < opponentIcons.length) iconTarget = opponentIcons[idx];
				}
				
				if (iconTarget != null) {
					if (iconValue == 'false' || iconValue == 'off' || iconValue == 'hide') {
						iconTarget.visible = false;
					} else if (iconValue == 'true' || iconValue == 'on' || iconValue == 'show') {
						iconTarget.visible = true;
					} else {
						var charId:Null<Int> = Std.parseInt(iconValue);
						var resolvedIcon:String = iconValue;
						if (charId != null && !Math.isNaN(charId)) {
							var targetChar:Character = null;
							if (charId == 0) {
								targetChar = dad;
							} else if (charId == 1) {
								targetChar = boyfriend;
							} else if (extraChars != null && charId < extraChars.length) {
								targetChar = extraChars[charId];
							}
							if (targetChar != null) {
								resolvedIcon = targetChar.healthIcon;
							}
						}
						iconTarget.changeIcon(resolvedIcon);
					}
				}

			case 'Show Extra Character':
				var charId:Null<Int> = Std.parseInt(value1.trim());
				var visibleValue:String = value2.toLowerCase().trim();
				var visibleBool:Bool = (visibleValue == 'true' || visibleValue == 'on' || visibleValue == '1');
				
				if (charId != null && !Math.isNaN(charId) && extraChars != null && charId < extraChars.length) {
					var targetChar:Character = extraChars[charId];
					if (targetChar != null) {
						// Safeguard: Do not disable if there is a sustain (long) note currently active/on-screen for this character
						if (!visibleBool) {
							var hasActiveSustain:Bool = false;
							if (notes != null) {
								notes.forEachAlive(function(daNote:Note) {
									if (daNote != null && daNote.isSustainNote && daNote.charNoteID == charId) {
										hasActiveSustain = true;
									}
								});
							}
							if (hasActiveSustain) {
								return; // Do not disable during sustain note
							}
						}

						// Safeguards for Boyfriend and Dad
						if (!visibleBool) {
							if (charId == 1) {
								var otherPlayerActive:Bool = false;
								for (c in extraChars) {
									if (c != null && c != boyfriend && c.isPlayer && c.visible && c.alpha > 0.01) {
										otherPlayerActive = true;
										break;
									}
								}
								if (!otherPlayerActive) return;
							}
							if (charId == 0) {
								var otherOpponentActive:Bool = false;
								for (c in extraChars) {
									if (c != null && c != dad && !c.isPlayer && c.visible && c.alpha > 0.01) {
										otherOpponentActive = true;
										break;
									}
								}
								if (!otherOpponentActive) return;
							}
						}

						// Apply visibility changes to character
						targetChar.visible = visibleBool;
						targetChar.alpha = visibleBool ? 1.0 : 0.00001;

						// Apply visibility changes to corresponding icon
						var icon:HealthIcon = charIconMap.get(targetChar);
						if (icon != null) {
							icon.visible = (visibleBool && !ClientPrefs.hideHud);
						}
					}
				}

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if (Math.isNaN(val1))
					val1 = 1;
				if (Math.isNaN(val2))
					val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if (val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2 / playbackRate, {
						ease: FlxEase.linear,
						onComplete: function(twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Set Property':
				var killMe:Array<String> = value1.split('.');
				if (killMe.length > 1)
				{
					FunkinLua.setVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe, true, true), killMe[killMe.length - 1], value2);
				}
				else
				{
					FunkinLua.setVarInArray(this, value1, value2);
				}
			case 'Toggle Split Screen':
				var enable:Bool = (value1.toLowerCase() == 'on');

				var duration:Float = Std.parseFloat(value2);

				if (Math.isNaN(duration) || duration <= 0)
					duration = 0.7;

				toggleSplitScreen(enable, duration);
			case 'Set Split Position':
				var ratio:Float = Std.parseFloat(value1);
				var duration:Float = Std.parseFloat(value2);
				if (Math.isNaN(ratio))
					ratio = 0.5;
				if (Math.isNaN(duration))
					duration = 0;
				setSplitPos(ratio, duration);
			case 'Instant Cam Pos':
				if (camFollow != null)
				{
					var val1:Float = Std.parseFloat(value1);
					var val2:Float = Std.parseFloat(value2);

					// Handle NaN values
					if (Math.isNaN(val1))
						val1 = 0;
					if (Math.isNaN(val2))
						val2 = 0;

					isCameraOnForcedPos = false;
					if (!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2)))
					{
						camFollow.x = val1;
						camFollow.y = val2;
						camFollowPos.setPosition(val1, val2);
						isCameraOnForcedPos = true;
					}
				}
		}
		callOnLuas('onEvent', [eventName, value1, value2]);
	}

	function moveCameraSection():Void
	{
		if (SONG.notes[curSection] == null)
			return;

		if (gf != null && SONG.notes[curSection].gfSection)
		{
			camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
			if (gf.cameraPosition != null) {
				camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
				camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
			}
			tweenCamIn();
			callOnLuas('onMoveCamera', ['gf']);
			return;
		}

		var secDynamic:Dynamic = SONG.notes[curSection];
		var focusID:Int = (secDynamic.camFocus != null) ? secDynamic.camFocus : (SONG.notes[curSection].mustHitSection ? 1 : 0);

		if (focusID >= 0 && focusID < extraChars.length)
		{
			var char:Character = extraChars[focusID];
			if (char != null)
			{
				if (char.isPlayer)
				{
					camFollow.set(char.getMidpoint().x - 100, char.getMidpoint().y - 100);
					if (char.cameraPosition != null) {
						camFollow.x -= char.cameraPosition[0] - boyfriendCameraOffset[0];
						camFollow.y += char.cameraPosition[1] + boyfriendCameraOffset[1];
					}
					callOnLuas('onMoveCamera', [focusID == 1 ? 'boyfriend' : char.curCharacter]);
				}
				else
				{
					camFollow.set(char.getMidpoint().x + 150, char.getMidpoint().y - 100);
					if (char.cameraPosition != null) {
						camFollow.x += char.cameraPosition[0] + opponentCameraOffset[0];
						camFollow.y += char.cameraPosition[1] + opponentCameraOffset[1];
					}
					callOnLuas('onMoveCamera', [focusID == 0 ? 'dad' : char.curCharacter]);
				}
				tweenCamIn();
			}
		}
	}

	var cameraTwn:FlxTween;

	public function moveCamera(isDad:Bool)
	{
		if (isDad)
		{
			if (dad != null) {
				camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
				if (dad.cameraPosition != null) {
					camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
					camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
				}
				tweenCamIn();
			}
		}
		else
		{
			if (boyfriend != null) {
				camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
				if (boyfriend.cameraPosition != null) {
					camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
					camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
				}

				if (Paths.formatToSongPath(SONG.song) == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
				{
					cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {
						ease: FlxEase.elasticInOut,
						onComplete: function(twn:FlxTween)
						{
							cameraTwn = null;
						}
					});
				}
			}
		}
	}

	function tweenCamIn()
	{
		if (Paths.formatToSongPath(SONG.song) == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3)
		{
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {
				ease: FlxEase.elasticInOut,
				onComplete: function(twn:FlxTween)
				{
					cameraTwn = null;
				}
			});
		}
	}

	public function setCameraPositionInstant(x:Float, y:Float, ?zoom:Float)
	{
		if (camFollow != null)
		{
			// Snap both follow points to position
			snapCamFollowToPos(x, y);
			isCameraOnForcedPos = true;

			// Set zoom (use default if not specified)
			var baseZ:Float = (zoom != null) ? zoom : defaultCamZoom;
			FlxG.camera.zoom = baseZ * smartCamZoomMult;
		}
	}

	override public function onResize(Width:Int, Height:Int):Void
	{
		super.onResize(Width, Height);
		if (FlxG.game != null)
		{
			FlxG.game.scrollRect = new openfl.geom.Rectangle(0, 0, FlxG.scaleMode.gameSize.x, FlxG.scaleMode.gameSize.y);
		}
	}

	public function snapCamFollowToPos(x:Float, y:Float)
	{
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		endingSong = true;
		var finishCallback:Void->Void = endSong; // In case you want to change it in a specific song.

		updateTime = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		vocals.pause();
		if (ClientPrefs.noteOffset <= 0 || ignoreNoteOffset)
		{
			finishCallback();
		}
		else
		{
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer)
			{
				finishCallback();
			});
		}
	}

	public var transitioning = false;

	public function endSong():Void
	{
		// Should kill you if you tried to cheat
		if (!startingSong)
		{
			notes.forEach(function(daNote:Note)
			{
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= 0.05 * healthLoss;
				}
			});
			for (daNote in unspawnNotes)
			{
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= 0.05 * healthLoss;
				}
			}

			if (doDeathCheck())
			{
				return;
			}

		}

		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		if (achievementObj != null)
		{
			return;
		}
		else
		{
			var achieve:String = checkForAchievement([
				'week1_nomiss', 'week2_nomiss', 'week3_nomiss', 'week4_nomiss',
				'week5_nomiss', 'week6_nomiss', 'week7_nomiss', 'ur_bad',
				'ur_good', 'hype', 'two_keys', 'toastie', 'debugger'
			]);

			if (achieve != null)
			{
				startAchievement(achieve);
				return;
			}
		}
		#end

		var ret:Dynamic = callOnLuas('onEndSong', [], false);
		if (ret != FunkinLua.Function_Stop && !transitioning)
		{
			if (SONG.validScore)
			{
				#if !switch
				var percent:Float = ratingPercent;
				if (Math.isNaN(percent))
					percent = 0;
				Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);
				#end
			}
			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					WeekData.loadTheFirstEnabledMod();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));

					cancelMusicFadeTween();
					if (FlxTransitionableState.skipNextTransIn)
					{
						CustomFadeTransition.nextCamera = null;
					}

					if (!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false))
					{
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);

						if (SONG.validScore)
						{
							Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);
						}

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;

					CustomFadeTransition.nextCamera = camOther;
					openSubState(new StickerFadeTransition(false));
					new FlxTimer().start(1.5, function(_)
					{
						MusicBeatState.switchState(new StoryMenuState());
					});
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					var winterHorrorlandNext = (Paths.formatToSongPath(SONG.song) == "eggnog");
					if (winterHorrorlandNext)
					{
						var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
							-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
						blackShit.scrollFactor.set();
						add(blackShit);
						camHUD.visible = false;

						FlxG.sound.play(Paths.sound('Lights_Shut_off'));
					}

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					if (winterHorrorlandNext)
					{
						new FlxTimer().start(1.5, function(tmr:FlxTimer)
						{
							cancelMusicFadeTween();
							LoadingState.loadAndSwitchState(new PlayState());
						});
					}
					else
					{
						cancelMusicFadeTween();
						LoadingState.loadAndSwitchState(new PlayState());
					}
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				WeekData.loadTheFirstEnabledMod();
				cancelMusicFadeTween();
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				changedDifficulty = false;
				FreeplayState.stickerTransitionNext = true;
				MusicBeatState.switchState(new FreeplayState());
			}
			transitioning = true;
		}
	}

	function updateRatingsText()
	{
		var daText:String = "Marvelous: " + marvelouss;
		daText += "\nSick: " + sicks;
		daText += "\nGood: " + goods;
		daText += "\nBad: " + bads;
		daText += "\nShit: " + shits;
		daText += "\nMiss: " + misses;

		if (ratingsText != null)
		{
			ratingsText.text = daText;
		}
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementObject = null;

	public function startAchievement(achieve:String)
	{
		achievementObj = new AchievementObject(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}

	function achievementEnd():Void
	{
		achievementObj = null;
		if (endingSong && !inCutscene)
		{
			endSong();
		}
	}
	#end

	public function KillNotes()
	{
		while (notes.length > 0)
		{
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;
	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	private function cachePopUpScore()
	{
		var pixelShitPart1:String = '';
		var pixelShitPart2:String = '';
		if (isPixelStage)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		Paths.image(pixelShitPart1 + "sick" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "good" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "bad" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "shit" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "combo" + pixelShitPart2);

		for (i in 0...10)
		{
			Paths.image(pixelShitPart1 + 'num' + i + pixelShitPart2);
		}
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);
		vocals.volume = 1;

		var daRating:Rating = Conductor.judgeNote(note, noteDiff / playbackRate);
		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if (!note.ratingDisabled)
			daRating.increase();
		note.rating = daRating.name;

		if (daRating.noteSplash && !note.noteSplashDisabled)
		{
			spawnNoteSplashOnNote(note);
		}

		if (!practiceMode && !cpuControlled)
		{
			songScore += daRating.score;
			if (!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		var pixelShitPart1:String = "";
		var pixelShitPart2:String = '';
		if (PlayState.isPixelStage)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		var rating:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + daRating.image + pixelShitPart2));
		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = ClientPrefs.globalAntialiasing;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
		}
		rating.updateHitbox();

		if (ClientPrefs.comboOnGameCam)
		{
			// 1. GAME CAM
			rating.cameras = [camGame];

			rating.setPosition(boyfriend.getMidpoint().x - (rating.width / 2) + 60 - 250, boyfriend.y - (rating.height / 2) - 60 + 100);

			// Stage Offset + Menu Offset

            // And there's the same thing

            if (isPixelStage) {
                rating.x += rateX - 200;
			    rating.y -= rateY + 100;
			    rating.x += ClientPrefs.comboOffset[0];
			    rating.y -= ClientPrefs.comboOffset[1];
            } else {
                rating.x += rateX;
			    rating.y -= rateY;
			    rating.x += ClientPrefs.comboOffset[0];
			    rating.y -= ClientPrefs.comboOffset[1];
            }
		}
		else
		{
			// 2. HUD
			rating.cameras = [camHUD];
			rating.screenCenter();

			rating.x = (FlxG.width * 0.35) - (rating.width / 2) + 60;
			rating.y -= 60;

			// Menu Offset
			rating.x += ClientPrefs.comboOffset[0];
			rating.y -= ClientPrefs.comboOffset[1];
		}

		rating.visible = (!ClientPrefs.hideHud && showRating);
		rating.acceleration.y = 550 * playbackRate * playbackRate;
		rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;

		insert(members.indexOf(strumLineNotes), rating);

		if (!ClientPrefs.comboStacking)
		{
			if (lastRating != null)
				lastRating.kill();
			lastRating = rating;
		}

		var seperatedScore:Array<Int> = [];
		if (combo >= 1000)
		{
			seperatedScore.push(Math.floor(combo / 1000) % 10);
		}
		seperatedScore.push(Math.floor(combo / 100) % 10);
		seperatedScore.push(Math.floor(combo / 10) % 10);
		seperatedScore.push(combo % 10);

		if (lastScore != null)
		{
			while (lastScore.length > 0)
			{
				lastScore[0].kill();
				lastScore.remove(lastScore[0]);
			}
		}

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2));
			if (!PlayState.isPixelStage)
			{
				numScore.antialiasing = ClientPrefs.globalAntialiasing;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			}
			numScore.updateHitbox();

			if (ClientPrefs.comboOnGameCam)
			{
				numScore.cameras = [camGame];

				numScore.setPosition(boyfriend.getMidpoint().x - 90 + (daLoop * 43) - 250, boyfriend.y - (numScore.height / 2) + 80 + 100);			

                // ok. I saw some issue in pixel stages (I made that first LMAO)

                if (isPixelStage) {
                    numScore.x += comboX - 200;
				    numScore.y -= comboY + 100;
				    numScore.x += ClientPrefs.comboOffset[2];
				    numScore.y -= ClientPrefs.comboOffset[3];
                } else {
                    numScore.x += comboX;
				    numScore.y -= comboY;
				    numScore.x += ClientPrefs.comboOffset[2];
				    numScore.y -= ClientPrefs.comboOffset[3];
                }
			}
			else
			{
				
				numScore.cameras = [camHUD];
				numScore.screenCenter(Y);

				
				numScore.x = (FlxG.width * 0.35) - 90 + (daLoop * 43);
				numScore.y += 80;

				// Personalization offet or something
				numScore.x += ClientPrefs.comboOffset[2];
				numScore.y -= ClientPrefs.comboOffset[3];
			}

			if (!ClientPrefs.comboStacking)
				lastScore.push(numScore);

			numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			numScore.visible = (!ClientPrefs.hideHud && showComboNum);

			if (showComboNum)
				insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});
			daLoop++;
		}

		// Animacje znikania ratingu
		FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {startDelay: Conductor.crochet * 0.001 / playbackRate});
	}

	public var strumsBlocked:Array<Bool> = [];

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		// trace('Pressed: ' + eventKey);

		if (!cpuControlled
			&& startedCountdown
			&& !paused
			&& key > -1
			&& (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode))
		{
			if (!boyfriend.stunned && generatedMusic && !endingSong)
			{
				// more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.ghostTapping;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				// var notesDatas:Array<Int> = [];
				var notesStopped:Bool = false;

				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive(function(daNote:Note)
				{
					if (strumsBlocked[daNote.noteData] != true
						&& daNote.canBeHit
						&& daNote.mustPress
						&& !daNote.tooLate
						&& !daNote.wasGoodHit
						&& !daNote.isSustainNote
						&& !daNote.blockHit
						&& daNote.noteType != 'Bot Note'
						&& daNote.noteType != 'Bot Notes')
					{
						if (daNote.noteData == key)
						{
							sortedNotesList.push(daNote);
							// notesDatas.push(daNote.noteData);
						}
						canMiss = true;
					}
				});
				sortedNotesList.sort(sortHitNotes);

				if (sortedNotesList.length > 0)
				{
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes)
						{
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1)
							{
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							}
							else
								notesStopped = true;
						}

						// eee jack detection before was not super good
						if (!notesStopped)
						{
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}
					}
				}
				else
				{
					callOnLuas('onGhostTap', [key]);
					if (canMiss)
					{
						noteMissPress(key);
					}
				}

				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				keysPressed[key] = true;

				// more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if (strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			callOnLuas('onKeyPress', [key]);
		}
		// trace('pressed: ' + controlArray);
	}

	function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if (!cpuControlled && startedCountdown && !paused && key > -1)
		{
			var spr:StrumNote = playerStrums.members[key];
			if (spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			callOnLuas('onKeyRelease', [key]);
		}
		// trace('released: ' + controlArray);
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if (key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	// Hold notes
	private function keyShit():Void
	{
		// HOLDING
		var parsedHoldArray:Array<Bool> = parseKeys();

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (ClientPrefs.controllerMode)
		{
			var parsedArray:Array<Bool> = parseKeys('_P');
			if (parsedArray.contains(true))
			{
				for (i in 0...parsedArray.length)
				{
					if (parsedArray[i] && strumsBlocked[i] != true)
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}

		// FlxG.watch.addQuick('asdfa', upP);
		if (startedCountdown && !boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			notes.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (strumsBlocked[daNote.noteData] != true
					&& daNote.isSustainNote
					&& parsedHoldArray[daNote.noteData]
					&& daNote.canBeHit
					&& daNote.mustPress
					&& !daNote.tooLate
					&& !daNote.wasGoodHit
					&& !daNote.blockHit
					&& daNote.noteType != 'Bot Note'
					&& daNote.noteType != 'Bot Notes')
				{
					goodNoteHit(daNote);
				}
			});

			if (parsedHoldArray.contains(true) && !endingSong)
			{
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null)
				{
					startAchievement(achieve);
				}
				#end
			}
			else if (boyfriend.animation.curAnim != null
				&& boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration
					&& boyfriend.animation.curAnim.name.startsWith('sing')
					&& !boyfriend.animation.curAnim.name.endsWith('miss'))
			{
				boyfriend.dance();
				// boyfriend.animation.curAnim.finish();
			}
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (ClientPrefs.controllerMode || strumsBlocked.contains(true))
		{
			var parsedArray:Array<Bool> = parseKeys('_R');
			if (parsedArray.contains(true))
			{
				for (i in 0...parsedArray.length)
				{
					if (parsedArray[i] || strumsBlocked[i] == true)
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
	}

	private function parseKeys(?suffix:String = ''):Array<Bool>
	{
		var ret:Array<Bool> = [];
		for (i in 0...controlArray.length)
		{
			ret[i] = Reflect.getProperty(controls, controlArray[i] + suffix);
		}
		return ret;
	}

	function noteMiss(daNote:Note):Void
	{ // You didn't hit the key and let it go offscreen, also used by Hurt Notes
		// Dupe note remove
		notes.forEachAlive(function(note:Note)
		{if (dad != null && curBeat % dad.danceEveryNumBeats == 0 && !dad.stunned)
        dad.dance();

			if (daNote != note
				&& daNote.mustPress
				&& daNote.noteData == note.noteData
				&& daNote.isSustainNote == note.isSustainNote
				&& Math.abs(daNote.strumTime - note.strumTime) < 1)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		combo = 0;
		health -= daNote.missHealth * healthLoss;

		if (instakillOnMiss)
		{
			vocals.volume = 0;
			doDeathCheck(true);
		}

		// For testing purposes
		// trace(daNote.missHealth);
		songMisses++;
		misses++;
		updateRatingsText();
		vocals.volume = 0;
		if (!practiceMode)
			songScore -= 10;

		totalPlayed++;
		RecalculateRating(true);

		var char:Character = boyfriend;
		if (daNote.gfNote)
		{
			char = gf;
		}

		if (char != null && !daNote.noMissAnimation && char.hasMissAnimations)
		{
			var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daNote.animSuffix;
			char.playAnim(animToPlay, true);
		}

		callOnLuas('noteMiss', [
			notes.members.indexOf(daNote),
			daNote.noteData,
			daNote.noteType,
			daNote.isSustainNote
		]);
	}

	function noteMissPress(direction:Int = 1):Void // You pressed a key when there was no notes to press for this key
	{
		if (ClientPrefs.ghostTapping)
			return; // fuck it

		if (!boyfriend.stunned)
		{
			health -= 0.05 * healthLoss;
			if (instakillOnMiss)
			{
				vocals.volume = 0;
				doDeathCheck(true);
			}

			if (combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			if (!practiceMode)
				songScore -= 10;
			if (!endingSong)
			{
				songMisses++;
				misses++;
				updateRatingsText();
			}
			totalPlayed++;
			RecalculateRating(true);

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			// FlxG.sound.play(Paths.sound('missnote1'), 1, false);
			// FlxG.log.add('played imss note');

			/*boyfriend.stunned = true;
	
										// get stunned for 1/60 of a second, makes you able to
										new FlxTimer().start(1 / 60, function(tmr:FlxTimer)
										{
											boyfriend.stunned = false;
			});*/

			if (boyfriend.hasMissAnimations)
			{
				boyfriend.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
			}
			vocals.volume = 0;
		}
		callOnLuas('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note):Void
	{
		if (Paths.formatToSongPath(SONG.song) != 'tutorial')
			camZooming = true;

		if (note.noteType == 'Hey!' && dad.animOffsets.exists('hey'))
		{
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			vanillaHandler.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
			var altAnim:String = note.animSuffix;

			if (SONG.notes[curSection] != null)
			{
				if (SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection)
				{
					altAnim = '-alt';
				}
			}

			var char:Character = dad;
			if (note.charNoteID >= 0 && note.charNoteID < extraChars.length) {
				char = extraChars[note.charNoteID];
			}
			
			var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))] + altAnim;
			if (note.gfNote)
			{
				char = gf;
			}

			if (char != null)
			{
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		if (SONG.needsVoices)
			vocals.volume = 1;

		var time:Float = 0.15;
		if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
		{
			time += 0.15;
		}
		StrumPlayAnim(true, Std.int(Math.abs(note.noteData)), time);
		note.hitByOpponent = true;

		callOnLuas('opponentNoteHit', [
			notes.members.indexOf(note),
			Math.abs(note.noteData),
			note.noteType,
			note.isSustainNote
		]);

		if (!note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note)
	{
		if (!note.wasGoodHit)
		{
			if (cpuControlled && (note.ignoreNote || note.hitCausesMiss))
				return;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled)
			{
				FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);
			}

			if (note.hitCausesMiss)
			{
				noteMiss(note);
				if (!note.noteSplashDisabled && !note.isSustainNote)
				{
					spawnNoteSplashOnNote(note);
				}

				if (!note.noMissAnimation)
				{
					switch (note.noteType)
					{
						case 'Hurt Note': // Hurt note
							if (boyfriend.animation.getByName('hurt') != null)
							{
								boyfriend.playAnim('hurt', true);
								boyfriend.specialAnim = true;
							}
					}
				}

				note.wasGoodHit = true;
				if (!note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote)
			{
				combo += 1;
				if (combo > 9999)
					combo = 9999;
				popUpScore(note);

				// Why ts needs to minus 1 count...
				if (note.rating == 'marvelous')
				{
					marvelouss++;
					marvelouss -= 1;
				}
				else if (note.rating == 'sick')
				{
					sicks++;
					sicks -= 1;
				}
				else if (note.rating == 'good')
				{
					goods++;
					goods -= 1;
				}
				else if (note.rating == 'bad')
				{
					bads++;
					bads -= 1;
				}
				else if (note.rating == 'shit')
				{
					shits++;
					shits -= 1;
				}
				updateRatingsText();
			}

			health += note.hitHealth * healthGain;

			if (!note.noAnimation)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))];

				var char:Character = boyfriend;
				if (note.charNoteID >= 0 && note.charNoteID < extraChars.length) {
					char = extraChars[note.charNoteID];
				}

				if (note.gfNote)
				{
					if (gf != null)
					{
						gf.playAnim(animToPlay + note.animSuffix, true);
						gf.holdTimer = 0;
					}
				}
				else if (char != null)
				{
					char.playAnim(animToPlay + note.animSuffix, true);
					char.holdTimer = 0;
				}

				if (note.noteType == 'Hey!')
				{
					if (boyfriend.animOffsets.exists('hey'))
					{
						boyfriend.playAnim('hey', true);
						boyfriend.specialAnim = true;
						vanillaHandler.heyTimer = 0.6;
					}

					if (gf != null && gf.animOffsets.exists('cheer'))
					{
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						vanillaHandler.heyTimer = 0.6;
					}
				}
			}

			if (cpuControlled)
			{
				var time:Float = 0.15;
				if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
				{
					time += 0.15;
				}
				StrumPlayAnim(false, Std.int(Math.abs(note.noteData)), time);
			}
			else
			{
				var spr = playerStrums.members[note.noteData];
				if (spr != null)
				{
					spr.playAnim('confirm', true);
				}
			}
			note.wasGoodHit = true;
			vocals.volume = 1;

			var isSus:Bool = note.isSustainNote;
			var leData:Int = Math.round(Math.abs(note.noteData));
			var leType:String = note.noteType;
			callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	public function spawnNoteSplashOnNote(note:Note)
	{
		if (ClientPrefs.noteSplashes && note != null)
		{
			var strum:StrumNote = playerStrums.members[note.noteData];
			if (strum != null)
			{
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null)
	{
		var skin:String = 'noteSplashes';
		if (PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0)
			skin = PlayState.SONG.splashSkin;

		var hue:Float = 0;
		var sat:Float = 0;
		var brt:Float = 0;
		if (data > -1 && data < ClientPrefs.arrowHSV.length)
		{
			hue = ClientPrefs.arrowHSV[data][0] / 360;
			sat = ClientPrefs.arrowHSV[data][1] / 100;
			brt = ClientPrefs.arrowHSV[data][2] / 100;
			if (note != null)
			{
				skin = note.noteSplashTexture;
				hue = note.noteSplashHue;
				sat = note.noteSplashSat;
				brt = note.noteSplashBrt;
			}
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	override function destroy()
	{
		if (FlxG.game != null)
		{
			FlxG.game.scrollRect = null;
		}
		
		DynamicStreamLoader.kill();
		AsyncAssetPreloader.kill();
		
		FlxG.cameras.remove(camHUD, false);
		for (lua in luaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = [];

		for (lua in charLuaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		charLuaArray = [];

		#if hscript
		if (FunkinLua.hscript != null)
			FunkinLua.hscript = null;
		#end

		if (!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		FlxAnimationController.globalSpeed = 1;
		FlxG.sound.music.pitch = 1;
		
		// Lazy clearing: free assets when leaving the song (not when entering it)
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		super.destroy();
	}

	public static function cancelMusicFadeTween()
	{
		if (FlxG.sound.music.fadeTween != null)
		{
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	var lastStepHit:Int = -1;

	override function stepHit()
	{
		super.stepHit();
		if (Math.abs(FlxG.sound.music.time - (Conductor.songPosition - Conductor.offset)) > (20 * playbackRate)
			|| (SONG.needsVoices && vocals != null && vocals.playing && Math.abs(vocals.time - FlxG.sound.music.time) > (20 * playbackRate)))
		{
			resyncVocals();
		}

		if (curStep == lastStepHit)
		{
			return;
		}

		lastStepHit = curStep;
		setOnLuas('curStep', curStep);
		callOnLuas('onStepHit', []);
	}

	public var lightningStrikeBeat:Int = 0;
	public var lightningOffset:Int = 8;
	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		if (vanillaHandler != null) vanillaHandler.beatHit(curStage, curBeat);
		super.beatHit();

		if (lastBeatHit >= curBeat)
		{
			// trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		for (i in 0...playerIcons.length) {
			var icon = playerIcons[i];
			var scaleVal:Float = (i == 0) ? 1.2 : 0.78;
			icon.scale.set(scaleVal, scaleVal);
			icon.updateHitbox();
		}
		for (i in 0...opponentIcons.length) {
			var icon = opponentIcons[i];
			var scaleVal:Float = (i == 0) ? 1.2 : 0.78;
			icon.scale.set(scaleVal, scaleVal);
			icon.updateHitbox();
		}

		if (gf != null && curBeat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 
    	    && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
    	{
    	    gf.dance();
    	}

    	if (boyfriend != null && curBeat % boyfriend.danceEveryNumBeats == 0 
    	    && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
    	{
    	    boyfriend.dance();
    	}

    	if (dad != null && curBeat % dad.danceEveryNumBeats == 0 
    	    && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
    	{
    	    dad.dance();
    	}

    	if (SONG.extraChars != null) {
    	    for (i in 2...extraChars.length) {
    	        var char = extraChars[i];
    	        if (char != null && curBeat % char.danceEveryNumBeats == 0 
    	            && char.animation.curAnim != null && !char.animation.curAnim.name.startsWith("sing") && !char.stunned) 
    	        {
    	            char.dance();
    	        }
    	    }
    	}

		switch (curStage)
		{
			case 'tank':
				if (!ClientPrefs.lowQuality)
					vanillaHandler.tankWatchtower.dance();
				vanillaHandler.foregroundSprites.forEach(function(spr:BGSprite)
				{
					spr.dance();
				});

			case 'school':
				if (!ClientPrefs.lowQuality)
				{
					vanillaHandler.bgGirls.dance();
				}

			case 'mall':
				if (!ClientPrefs.lowQuality)
				{
					vanillaHandler.upperBoppers.dance(true);
				}

				if (vanillaHandler.heyTimer <= 0)
					vanillaHandler.bottomBoppers.dance(true);
				vanillaHandler.santa.dance(true);

			case 'limo':
				if (!ClientPrefs.lowQuality)
				{
					vanillaHandler.grpLimoDancers.forEach(function(dancer:BackgroundDancer)
					{
						dancer.dance();
					});
				}

				if (FlxG.random.bool(10) && vanillaHandler.fastCarCanDrive)
					vanillaHandler.fastCarDrive();
			case "philly":
				if (!vanillaHandler.trainMoving)
					vanillaHandler.trainCooldown += 1;

				if (curBeat % 4 == 0)
				{
					curLight = FlxG.random.int(0, vanillaHandler.phillyLightsColors.length - 1, [curLight]);
					vanillaHandler.phillyWindow.color = vanillaHandler.phillyLightsColors[curLight];
					vanillaHandler.phillyWindow.alpha = 1;
				}

				if (curBeat % 8 == 4 && FlxG.random.bool(30) && !vanillaHandler.trainMoving && vanillaHandler.trainCooldown > 8)
				{
					vanillaHandler.trainCooldown = FlxG.random.int(-4, 0);
					vanillaHandler.trainStart();
				}
		}

		if (curStage == 'spooky' && FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
		{
			vanillaHandler.lightningStrikeShit();
		}
		lastBeatHit = curBeat;

		setOnLuas('curBeat', curBeat); // DAWGG?????
		callOnLuas('onBeatHit', []);
	}

	override function sectionHit()
	{
		super.sectionHit();

		if (SONG.notes[curSection] != null)
		{
			var isStandalone:Bool = isCameraStandalone();

			if (generatedMusic && !endingSong && !isCameraOnForcedPos && !isStandalone && !isCameraEditor)
			{
				moveCameraSection();
			}

			if (camZooming && FlxG.camera.zoom < (1.35 * smartCamZoomMult) && ClientPrefs.camZooms && !isStandalone && !isCameraEditor)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[curSection].bpm);
				setOnLuas('curBpm', Conductor.bpm);
				setOnLuas('crochet', Conductor.crochet);
				setOnLuas('stepCrochet', Conductor.stepCrochet);
			}
			setOnLuas('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnLuas('altAnim', SONG.notes[curSection].altAnim);
			setOnLuas('gfSection', SONG.notes[curSection].gfSection);
		}

		setOnLuas('curSection', curSection);
		callOnLuas('onSectionHit', []);
	}

	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops = true, exclusions:Array<String> = null):Dynamic
	{
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		if (exclusions == null)
			exclusions = [];
		for (script in luaArray)
		{
			if (exclusions.contains(script.scriptName))
				continue;

			var ret:Dynamic = script.call(event, args);
			if (ret == FunkinLua.Function_StopLua && !ignoreStops)
				break;

			// had to do this because there is a bug in haxe where Stop != Continue doesnt work
			var bool:Bool = ret == FunkinLua.Function_Continue;
			if (!bool && ret != 0)
			{
				returnVal = cast ret;
			}
		}

		for (script in charLuaArray)
		{
			if (exclusions.contains(script.scriptName))
				continue;

			var ret:Dynamic = script.call(event, args);
			if (ret == FunkinLua.Function_StopLua && !ignoreStops)
				break;

			// had to do this because there is a bug in haxe where Stop != Continue doesnt work
			var bool:Bool = ret == FunkinLua.Function_Continue;
			if (!bool && ret != 0)
			{
				returnVal = cast ret;
			}
		}
		#end
		// trace(event, returnVal);
		return returnVal;
	}

	public function setOnLuas(variable:String, arg:Dynamic)
	{
		#if LUA_ALLOWED
		for (i in 0...luaArray.length)
		{
			luaArray[i].set(variable, arg);
		}

		for (i in 0...charLuaArray.length)
		{
			charLuaArray[i].set(variable, arg);
		}
		#end
	}

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float)
	{
		var spr:StrumNote = null;
		if (isDad)
		{
			spr = strumLineNotes.members[id];
		}
		else
		{
			spr = playerStrums.members[id];
		}

		if (spr != null)
		{
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;

	public function RecalculateRating(badHit:Bool = false)
	{
		setOnLuas('score', songScore);
		setOnLuas('misses', songMisses);
		setOnLuas('hits', songHits);

		var ret:Dynamic = callOnLuas('onRecalculateRating', [], false);
		if (ret != FunkinLua.Function_Stop)
		{
			if (totalPlayed < 1) // Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				// trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				if (ratingPercent >= 1)
				{
					ratingName = ratingStuff[ratingStuff.length - 1][0]; // Uses last string
				}
				else
				{
					for (i in 0...ratingStuff.length - 1)
					{
						if (ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			// Rating FC
			ratingFC = "";
			if (ratingPercent == 1)
				ratingFC = "SS!!!";
			else if (ratingPercent >= 0.9)
				ratingFC = "S!";
			else if (ratingPercent >= 0.8)
				ratingFC = "A";
			else if (ratingPercent >= 0.6)
				ratingFC = "B";
			else if (ratingPercent >= 0.4)
				ratingFC = "C";
			else if (ratingPercent >= 0.3)
				ratingFC = "D";
		}
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
		setOnLuas('rating', ratingPercent);
		setOnLuas('ratingName', ratingName);
		setOnLuas('ratingFC', ratingFC);
	}

	public function toggleSplitScreen(enabled:Bool, duration:Float = 0.7)
	{
		if (camDad == null || camBF == null)
			return;

		isSplitScreen = enabled;
		var worldCams:Array<FlxCamera> = [camGame, camDad, camBF];

		if (enabled)
		{
			for (member in members)
			{
				if (member != null && (member is flixel.FlxSprite || member is flixel.group.FlxSpriteGroup))
				{
					var obj:flixel.FlxBasic = cast member;
					if (obj.cameras == null || (!obj.cameras.contains(camHUD) && !obj.cameras.contains(camOther)))
					{
						obj.cameras = worldCams;
					}
				}
			}

			// Startowe pozycje poza ekranem
			camDad.x = -FlxG.width / 2;
			camBF.x = FlxG.width;
			camDad.visible = true;
			camBF.visible = true;

			FlxTween.tween(camDad, {x: 0}, duration, {ease: FlxEase.quartOut});
			FlxTween.tween(camBF, {x: FlxG.width / 2}, duration, {ease: FlxEase.quartOut});
		}
		else
		{
			FlxTween.tween(camDad, {x: -FlxG.width / 2}, duration, {ease: FlxEase.quartIn});
			FlxTween.tween(camBF, {x: FlxG.width}, duration, {
				ease: FlxEase.quartIn,
				onComplete: function(twn:FlxTween)
				{
					camDad.visible = false;
					camBF.visible = false;
				}
			});
		}
	}

	public function setSplitPos(ratio:Float, duration:Float)
	{
		if (!isSplitScreen || camDad == null || camBF == null)
			return;

		var targetX = Math.floor(FlxG.width * ratio);

		if (splitTweenDad != null)
			splitTweenDad.cancel();
		if (splitTweenBF != null)
			splitTweenBF.cancel();

		if (duration <= 0)
		{
			camDad.width = targetX;
			camBF.x = targetX;
			camBF.width = FlxG.width - targetX;
		}
		else
		{
			splitTweenDad = FlxTween.tween(camDad, {width: targetX}, duration, {ease: FlxEase.quartOut});
			splitTweenBF = FlxTween.tween(camBF, {x: targetX, width: FlxG.width - targetX}, duration, {ease: FlxEase.quartOut});
		}
	}

	#if LUA_ALLOWED
	function characterScripts()
	{
		var characters:Array<Character> = [dad, boyfriend, gf];
		if (extraChars != null) {
			for (i in 2...extraChars.length) {
				if (extraChars[i] != null && !characters.contains(extraChars[i])) {
					characters.push(extraChars[i]);
				}
			}
		}

		for (i in 0...characters.length)
		{
			if (characters[i] != null && characters[i].character_script != null && characters[i].character_script.length > 0)
			{
				var script:String = characters[i].character_script;
				if (!script.endsWith('.lua'))
					script += '.lua';

				var fullPath:String = AssetHandler.getPath('characters/scripts/' + script);
				
				var alreadyLoaded:Bool = false;
				for (loadedScript in charLuaArray) {
					if (loadedScript != null && loadedScript.scriptName == fullPath) {
						loadedScript.character = characters[i];
						alreadyLoaded = true;
						break;
					}
				}
				if (alreadyLoaded) continue;

				var lua:FunkinLua = new FunkinLua(fullPath);
				lua.character = characters[i];

				lua.set('bpm', Conductor.bpm);
				lua.set('scrollSpeed', songSpeed);
				lua.set('songName', SONG.song);
				lua.set('isStoryMode', isStoryMode);

				lua.set('defaultDadX', dad.x);
				lua.set('defaultDadY', dad.y);
				lua.set('defaultBoyfriendX', boyfriend.x);
				lua.set('defaultBoyfriendY', boyfriend.y);

				if (gf != null)
				{
					lua.set('defaultGfX', gf.x);
					lua.set('defaultGfY', gf.y);
				}

				charLuaArray.push(lua);
			}
		}
	}
	#end

	#if ACHIEVEMENTS_ALLOWED
	public function checkForAchievement(achievesToCheck:Array<String> = null):String
	{
		if (chartingMode)
			return null;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice', false) || ClientPrefs.getGameplaySetting('botplay', false));
		for (i in 0...achievesToCheck.length)
		{
			var achievementName:String = achievesToCheck[i];
			if (!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled)
			{
				var unlock:Bool = false;

				if (achievementName.contains(WeekData.getWeekFileName())
					&& achievementName.endsWith('nomiss')) // any FC achievements, name should be "weekFileName_nomiss", e.g: "weekd_nomiss";
				{
					if (isStoryMode
						&& campaignMisses + songMisses < 1
						&& CoolUtil.difficultyString() == 'HARD'
						&& storyPlaylist.length <= 1
						&& !changedDifficulty
						&& !usedPractice)
						unlock = true;
				}
				switch (achievementName)
				{
					case 'ur_bad':
						if (ratingPercent < 0.2 && !practiceMode)
						{
							unlock = true;
						}
					case 'ur_good':
						if (ratingPercent >= 1 && !usedPractice)
						{
							unlock = true;
						}
					case 'roadkill_enthusiast':
						if (Achievements.henchmenDeath >= 100)
						{
							unlock = true;
						}
					case 'oversinging':
						if (boyfriend.holdTimer >= 10 && !usedPractice)
						{
							unlock = true;
						}
					case 'hype':
						if (!boyfriendIdled && !usedPractice)
						{
							unlock = true;
						}
					case 'two_keys':
						if (!usedPractice)
						{
							var howManyPresses:Int = 0;
							for (j in 0...keysPressed.length)
							{
								if (keysPressed[j])
									howManyPresses++;
							}

							if (howManyPresses <= 2)
							{
								unlock = true;
							}
						}
					case 'toastie':
						if (/*ClientPrefs.framerate <= 60 &&*/ !ClientPrefs.shaders && ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing)
						{
							unlock = true;
						}
					case 'debugger':
						if (Paths.formatToSongPath(SONG.song) == 'test' && !usedPractice)
						{
							unlock = true;
						}
				}

				if (unlock)
				{
					Achievements.unlockAchievement(achievementName);
					return achievementName;
				}
			}
		}
		return null;
	}
	#end

	function normalizeOasisChart():Void
	{
		if (SONG == null || SONG.notes == null) return;
		
		for (sec in SONG.notes)
		{
			var secDynamic:Dynamic = sec;
			// If the section doesn't have the new camFocus field (loading an old Psych chart)
			if (secDynamic.camFocus == null) {
				secDynamic.camFocus = sec.mustHitSection ? 1 : 0; 

				// OASIS ENGINE CHART ALIGNMENT:
				// If mustHitSection was true, in the old Psych format columns 0-3 meant BF,
				// so we shift them by 4 columns to map into the new Oasis BF strum line (4-7)
				if (sec.mustHitSection) {
					for (note in sec.sectionNotes) {
						if (note[1] < 8) {
							note[1] = (note[1] + 4) % 8;
						}
					}
				}
			}
			sec.mustHitSection = (secDynamic.camFocus == 1);
		}
	}

	var curLight:Int = -1;
	var curLightEvent:Int = -1;

	public static function getCameraPath(songName:String):String {
		var formatted:String = Paths.formatToSongPath(songName);
		#if MODS_ALLOWED
		var modPath:String = Paths.mods('data/' + formatted + '/camera.json');
		if (sys.FileSystem.exists(modPath)) return modPath;
		#end
		return 'assets/data/' + formatted + '/camera.json';
	}

	public static function getCameraSavePath(songName:String):String {
		var formatted:String = Paths.formatToSongPath(songName);
		#if MODS_ALLOWED
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0) {
			var dir:String = Paths.mods(Paths.currentModDirectory + '/data/' + formatted);
			if (sys.FileSystem.exists(dir)) {
				return dir + '/camera.json';
			}
		}
		#end
		return 'assets/data/' + formatted + '/camera.json';
	}

	public function getDefaultCameraPosition():FlxPoint
	{
		var pos:FlxPoint = new FlxPoint(0, 0);
		var section:Section.SwagSection = null;
		if (SONG != null && SONG.notes != null && SONG.notes[curSection] != null)
		{
			section = SONG.notes[curSection];
		}

		var mainCharacter:Character = dad;
		if (section != null)
		{
			var secDynamic:Dynamic = section;
			var focusID:Int = (secDynamic.camFocus != null) ? secDynamic.camFocus : (section.mustHitSection ? 1 : 0);

			if (section.gfSection)
				mainCharacter = gf;
			else if (focusID >= 0 && focusID < extraChars.length)
				mainCharacter = extraChars[focusID];
		}

		if (mainCharacter != null) {
			pos.x = mainCharacter.getMidpoint().x;
			pos.y = mainCharacter.getMidpoint().y;

			if (mainCharacter.isPlayer)
			{
				pos.x -= 100;
				pos.y -= 100;
				if (mainCharacter.cameraPosition != null) {
					pos.x -= mainCharacter.cameraPosition[0] - boyfriendCameraOffset[0];
					pos.y += mainCharacter.cameraPosition[1] + boyfriendCameraOffset[1];
				}
			}
			else
			{
				pos.x += 150;
				pos.y -= 100;
				if (mainCharacter.cameraPosition != null) {
					pos.x += mainCharacter.cameraPosition[0] + opponentCameraOffset[0];
					pos.y += mainCharacter.cameraPosition[1] + opponentCameraOffset[1];
				}
			}
		}
		return pos;
	}

	public function getCameraTargetPosition(targetType:String, targetId:Int):FlxPoint {
		var pos:FlxPoint = new FlxPoint(0, 0);
		switch (targetType) {
			case "dad":
				if (dad != null) {
					pos.x = dad.getMidpoint().x + 150;
					pos.y = dad.getMidpoint().y - 100;
					if (dad.cameraPosition != null) {
						pos.x += dad.cameraPosition[0] + opponentCameraOffset[0];
						pos.y += dad.cameraPosition[1] + opponentCameraOffset[1];
					}
				}
			case "bf":
				if (boyfriend != null) {
					pos.x = boyfriend.getMidpoint().x - 100;
					pos.y = boyfriend.getMidpoint().y - 100;
					if (boyfriend.cameraPosition != null) {
						pos.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
						pos.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
					}
				}
			case "gf":
				if (gf != null) {
					pos.x = gf.getMidpoint().x;
					pos.y = gf.getMidpoint().y;
					if (gf.cameraPosition != null) {
						pos.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
						pos.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
					}
				}
			case "extra_char":
				if (extraChars != null && targetId >= 0 && targetId < extraChars.length) {
					var char = extraChars[targetId];
					if (char != null) {
						if (char.isPlayer) {
							pos.x = char.getMidpoint().x - 100;
							pos.y = char.getMidpoint().y - 100;
							if (char.cameraPosition != null) {
								pos.x -= char.cameraPosition[0] - boyfriendCameraOffset[0];
								pos.y += char.cameraPosition[1] + boyfriendCameraOffset[1];
							}
						} else {
							pos.x = char.getMidpoint().x + 150;
							pos.y = char.getMidpoint().y - 100;
							if (char.cameraPosition != null) {
								pos.x += char.cameraPosition[0] + opponentCameraOffset[0];
								pos.y += char.cameraPosition[1] + opponentCameraOffset[1];
							}
						}
					}
				}
			case "global":
				pos.set(0, 0);
		}
		return pos;
	}

	public function isCameraStandalone():Bool
	{
		if (cameraEvents == null || cameraEvents.length == 0) return false;
		
		var stepFloat:Float = Conductor.songPosition / Conductor.stepCrochet;
		
		var activePosEvent:CameraEvent = null;
		for (i in 0...cameraEvents.length) {
			var ev = cameraEvents[i];
			if (ev.step <= stepFloat) {
				if (ev.target_type != "zoom") {
					activePosEvent = ev;
				}
			} else {
				break;
			}
		}
		
		if (activePosEvent != null) {
			return activePosEvent.standalone;
		}
		return false;
	}

	public function getGameplayCameraPosition():FlxPoint
	{
		var section:Section.SwagSection = null;
		if (SONG != null && SONG.notes != null && SONG.notes[curSection] != null)
		{
			section = SONG.notes[curSection];
		}

		var mainCharacter:Character = dad;
		if (section != null)
		{
			var secDynamic:Dynamic = section;
			var focusID:Int = (secDynamic.camFocus != null) ? secDynamic.camFocus : (section.mustHitSection ? 1 : 0);

			if (section.gfSection)
				mainCharacter = gf;
			else if (focusID >= 0 && focusID < extraChars.length)
				mainCharacter = extraChars[focusID];
		}

		if (mainCharacter == null) return new FlxPoint(0, 0);

		var mid = mainCharacter.getMidpoint();
		var camX:Float = mid.x;
		var camY:Float = mid.y;
		mid.put();

		if (mainCharacter.isPlayer)
		{
			camX -= 100;
			camY -= 100;
			if (mainCharacter.cameraPosition != null) {
				camX -= mainCharacter.cameraPosition[0] - boyfriendCameraOffset[0];
				camY += mainCharacter.cameraPosition[1] + boyfriendCameraOffset[1];
			}
		}
		else
		{
			camX += 150;
			camY -= 100;
			if (mainCharacter.cameraPosition != null) {
				camX += mainCharacter.cameraPosition[0] + opponentCameraOffset[0];
				camY += mainCharacter.cameraPosition[1] + opponentCameraOffset[1];
			}
		}

		return new FlxPoint(camX, camY);
	}

	public function hasActiveCameraEvent():Bool
	{
		if (cameraEvents == null || cameraEvents.length == 0) return false;
		
		var stepFloat:Float = Conductor.songPosition / Conductor.stepCrochet;
		if (stepFloat < cameraEvents[0].step) return false;

		// 1. Check for active position event
		var activePosEvent:CameraEvent = null;
		for (i in 0...cameraEvents.length) {
			var ev = cameraEvents[i];
			if (ev.step <= stepFloat) {
				if (ev.target_type != "zoom") {
					activePosEvent = ev;
				}
			} else {
				break;
			}
		}
		var isPosActive:Bool = (activePosEvent != null);
		if (activePosEvent != null && activePosEvent.target_type == "default") {
			var durationInSteps:Float = activePosEvent.duration * 4;
			if (stepFloat >= activePosEvent.step + durationInSteps) {
				isPosActive = false; // Position reversion finished
			}
		}

		// 2. Check for active zoom event
		var activeZoomEvent:CameraEvent = null;
		for (i in 0...cameraEvents.length) {
			var ev = cameraEvents[i];
			if (ev.step <= stepFloat) {
				if ((ev.zoom != -1 && ev.zoom > 0) || ev.target_type == "default") {
					activeZoomEvent = ev;
				}
			} else {
				break;
			}
		}

		var isZoomActive = false;
		if (activeZoomEvent != null) {
			if (activeZoomEvent.target_type != "default") {
				isZoomActive = true; // Stay locked to the custom zoom indefinitely
			} else {
				if (activeZoomEvent.duration > 0) {
					var endTime = activeZoomEvent.step + activeZoomEvent.duration;
					if (stepFloat <= endTime) isZoomActive = true;
				}
			}
		}

		return (isPosActive || isZoomActive);
	}

	public function updateCameraEvents(elapsed:Float):Void
	{
		if (cameraEvents == null || cameraEvents.length == 0) return;

		var stepFloat:Float = Conductor.songPosition / Conductor.stepCrochet;
		
		// Find active position event and its previous position event
		activePosEvent = null;
		var activePosIndex:Int = -1;
		
		for (i in 0...cameraEvents.length) {
			var ev = cameraEvents[i];
			if (ev.step <= stepFloat) {
				if (ev.target_type != "zoom") {
					activePosEvent = ev;
					activePosIndex = i;
				}
			} else {
				break;
			}
		}
		
		var prevPosEvent:CameraEvent = null;
		if (activePosIndex > 0) {
			var idx = activePosIndex - 1;
			while (idx >= 0) {
				var ev = cameraEvents[idx];
				if (ev.target_type != "zoom" && ev.step < activePosEvent.step) {
					prevPosEvent = ev;
					break;
				}
				idx--;
			}
		}

		// Find active zoom event and its previous zoom event
		activeZoomEvent = null;
		var activeZoomIndex:Int = -1;
		
		for (i in 0...cameraEvents.length) {
			var ev = cameraEvents[i];
			if (ev.step <= stepFloat) {
				if ((ev.zoom != -1 && ev.zoom > 0) || ev.target_type == "default") {
					activeZoomEvent = ev;
					activeZoomIndex = i;
				}
			} else {
				break;
			}
		}
		
		var prevZoomEvent:CameraEvent = null;
		if (activeZoomIndex > 0) {
			var idx = activeZoomIndex - 1;
			while (idx >= 0) {
				var ev = cameraEvents[idx];
				if (((ev.zoom != -1 && ev.zoom > 0) || ev.target_type == "default") && ev.step < activeZoomEvent.step) {
					prevZoomEvent = ev;
					break;
				}
				idx--;
			}
		}

		var stageFile = StageData.getStageFile(curStage);
		var defaultZoomVal:Float = (stageFile != null) ? stageFile.defaultZoom : 0.9;

		// ─── 1. Position evaluation ──────────────────────────────────────────
		if (activePosEvent == null) {
			var defaultPos:FlxPoint = getDefaultCameraPosition();
			camFollow.x = defaultPos.x;
			camFollow.y = defaultPos.y;
		} else {
			var finalX:Float = 0;
			var finalY:Float = 0;

			if (activePosEvent.target_type == "default") {
				var gpPos = getGameplayCameraPosition();
				finalX = gpPos.x;
				finalY = gpPos.y;
				gpPos.put();
			} else if (activePosEvent.target_type == "midpoint") {
				var dadMid = dad.getMidpoint();
				var bfMid = boyfriend.getMidpoint();
				finalX = (dadMid.x + bfMid.x) * 0.5 + activePosEvent.x;
				finalY = (dadMid.y + bfMid.y) * 0.5 + activePosEvent.y;
				dadMid.put();
				bfMid.put();
			} else {
				var targetPos:FlxPoint = getCameraTargetPosition(activePosEvent.target_type, activePosEvent.target_id);
				finalX = activePosEvent.is_relative ? (targetPos.x + activePosEvent.x) : activePosEvent.x;
				finalY = activePosEvent.is_relative ? (targetPos.y + activePosEvent.y) : activePosEvent.y;
			}

			// Add sing offset if not locked and not in cutscene
			if (activePosEvent != null && activePosEvent.target_type != "default" && activePosEvent.target_type != "zoom") {
				if (!activePosEvent.lock_note_movement && ClientPrefs.camMove && !inCutscene) {
					var mainCharacter:Character = null;
					switch (activePosEvent.target_type) {
						case "dad": mainCharacter = dad;
						case "bf": mainCharacter = boyfriend;
						case "gf": mainCharacter = gf;
						case "extra_char":
							if (extraChars != null && activePosEvent.target_id >= 0 && activePosEvent.target_id < extraChars.length) {
								mainCharacter = extraChars[activePosEvent.target_id];
							}
						default:
							// For global or midpoint, fall back to the section focus character
							var section:Section.SwagSection = null;
							if (SONG != null && SONG.notes != null && SONG.notes[curSection] != null) {
								section = SONG.notes[curSection];
							}
							mainCharacter = dad;
							if (section != null) {
								var secDynamic:Dynamic = section;
								var focusID:Int = (secDynamic.camFocus != null) ? secDynamic.camFocus : (section.mustHitSection ? 1 : 0);
								if (section.gfSection)
									mainCharacter = gf;
								else if (focusID >= 0 && focusID < extraChars.length)
									mainCharacter = extraChars[focusID];
							}
					}
					if (mainCharacter != null && mainCharacter.animation.curAnim != null) {
						var animName:String = mainCharacter.animation.curAnim.name;
						var shift:Float = ClientPrefs.camMoveStrength;
						if (animName.startsWith('singLEFT'))
							finalX -= shift;
						else if (animName.startsWith('singRIGHT'))
							finalX += shift;
						else if (animName.startsWith('singUP'))
							finalY -= shift;
						else if (animName.startsWith('singDOWN'))
							finalY += shift;
					}
				}
			}

			// Handle position interpolation
			var durationInSteps:Float = activePosEvent.duration * 4;
			if (durationInSteps > 0 && stepFloat < activePosEvent.step + durationInSteps) {
				var startX:Float = 0;
				var startY:Float = 0;

				if (prevPosEvent != null) {
					if (prevPosEvent.target_type == "default") {
						var gpPos = getGameplayCameraPosition();
						startX = gpPos.x;
						startY = gpPos.y;
						gpPos.put();
					} else if (prevPosEvent.target_type == "midpoint") {
						var dadMid = dad.getMidpoint();
						var bfMid = boyfriend.getMidpoint();
						startX = (dadMid.x + bfMid.x) * 0.5 + prevPosEvent.x;
						startY = (dadMid.y + bfMid.y) * 0.5 + prevPosEvent.y;
						dadMid.put();
						bfMid.put();
					} else {
						var prevTarget:FlxPoint = getCameraTargetPosition(prevPosEvent.target_type, prevPosEvent.target_id);
						startX = prevPosEvent.is_relative ? (prevTarget.x + prevPosEvent.x) : prevPosEvent.x;
						startY = prevPosEvent.is_relative ? (prevTarget.y + prevPosEvent.y) : prevPosEvent.y;
					}
				} else {
					var defaultPos:FlxPoint = getDefaultCameraPosition();
					startX = defaultPos.x;
					startY = defaultPos.y;
				}

				var t:Float = (stepFloat - activePosEvent.step) / durationInSteps;
				if (t < 0) t = 0;
				if (t > 1) t = 1;

				var easeProgress:Float = 1.0;
				if (activePosEvent.ease == "instant") {
					easeProgress = 1.0;
				} else {
					var easeFunc = null;
					if (activePosEvent.ease != null && activePosEvent.ease.length > 0) {
						easeFunc = Reflect.field(flixel.tweens.FlxEase, activePosEvent.ease);
					}
					easeProgress = (easeFunc != null) ? easeFunc(t) : t;
				}

				camFollow.x = startX + (finalX - startX) * easeProgress;
				camFollow.y = startY + (finalY - startY) * easeProgress;
			} else {
				camFollow.x = finalX;
				camFollow.y = finalY;
			}
		}

		// ─── 2. Zoom evaluation ──────────────────────────────────────────────
		if (activeZoomEvent == null) {
			defaultCamZoom = defaultZoomVal;
		} else {
			var finalZoom:Float = (activeZoomEvent.target_type == "default") ? defaultZoomVal : activeZoomEvent.zoom;
			if (finalZoom <= 0) finalZoom = defaultZoomVal;

			var durationInSteps:Float = activeZoomEvent.duration * 4;
			if (durationInSteps > 0 && stepFloat < activeZoomEvent.step + durationInSteps) {
				var startZoom:Float = defaultZoomVal;

				if (prevZoomEvent != null) {
					startZoom = (prevZoomEvent.target_type == "default") ? defaultZoomVal : prevZoomEvent.zoom;
					if (startZoom <= 0) startZoom = defaultZoomVal;
				}

				var t:Float = (stepFloat - activeZoomEvent.step) / durationInSteps;
				if (t < 0) t = 0;
				if (t > 1) t = 1;

				var easeProgress:Float = 1.0;
				if (activeZoomEvent.ease == "instant") {
					easeProgress = 1.0;
				} else {
					var easeFunc = null;
					if (activeZoomEvent.ease != null && activeZoomEvent.ease.length > 0) {
						easeFunc = Reflect.field(flixel.tweens.FlxEase, activeZoomEvent.ease);
					}
					easeProgress = (easeFunc != null) ? easeFunc(t) : t;
				}

				defaultCamZoom = startZoom + (finalZoom - startZoom) * easeProgress;
			} else {
				defaultCamZoom = finalZoom;
			}
		}
	}
}
