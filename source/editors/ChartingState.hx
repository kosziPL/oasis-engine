package editors;

#if desktop
import Discord.DiscordClient;
#end
import flash.geom.Rectangle;
import haxe.Json;
import haxe.format.JsonParser;
import haxe.io.Bytes;
import Conductor.BPMChangeEvent;
import Section.SwagSection;
import Song.SwagSong;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import lime.media.AudioBuffer;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.ByteArray;
import flixel.FlxCamera;

using StringTools;

#if sys
import flash.media.Sound;
import sys.FileSystem;
import sys.io.File;
#end

@:access(flixel.system.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)
class ChartingState extends MusicBeatState
{
	public static var noteTypeList:Array<String> = // Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
		['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation', 'Bot Notes']; // Invisible notes for Extra Chars

	private var noteTypeIntMap:Map<Int, String> = new Map<Int, String>();
	private var noteTypeMap:Map<String, Null<Int>> = new Map<String, Null<Int>>();

	public var ignoreWarnings = false;

	var undoHistory:Array<{sec:Int, notes:Array<Array<Dynamic>>}> = [];
	var redos = [];
	var eventStuff:Array<Dynamic> = [
		['', "Nothing. Yep, that's right."],
		[
			'Dadbattle Spotlight',
			"Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"
		],
		[
			'Hey!',
			"Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"
		],
		[
			'Set GF Speed',
			"Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"
		],
		[
			'Philly Glow',
			"Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."
		],
		['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
		[
			'Add Camera Zoom',
			"Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."
		],
		['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
		['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
		[
			'Play Animation',
			"Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"
		],
		[
			'Camera Follow Pos',
			"Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."
		],
		[
			'Alt Idle Animation',
			"Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"
		],
		[
			'Screen Shake',
			"Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."
		],
		[
			'Change Character',
			"Value 1: Target (0=Dad, 1=BF, gf, or Index >= 2 for Extra Chars)\nValue 2: Character name (e.g. bf, dad, gf, jevil)"
		],
		[
			'Change Icon',
			"Value 1: Target (bf, dad, playerX, opponentX)\nValue 2: Icon name / status (false/off/hide, true/on/show, or icon name)"
		],
		[
			'Show Extra Character',
			"Value 1: Character ID (0=Dad, 1=BF, >=2 for Extras)\nValue 2: Show / Hide (true / false)"
		],
		[
			'Darken Screen',
			"Value 1: Darkening strength (0 - none, 1 - max)\nValue 2: Duration of transition (in seconds, default 1)"
		],
		[
			'Ghost Trails',
			"Value 1: Toggle ghost trails (on / off)\nValue 2: Target character (bf / dad / gf / leave blank for all)"
		],
		[
			'Change Scroll Speed',
			"Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."
		],
		['Set Property', "Value 1: Variable name\nValue 2: New value"],
		['Toggle Split Screen', "Turns on/off a split screen event.\nValue 1: on / off"],
		[
			'Set Split Position',
			"Sets a position of split.\nValue 1: Position (0.0 - 1.0, default 0.5)\nValue 2: ease duration (in seconds)"
		],
		['Instant Cam Pos', "Works just like \'Camera Follow Pos\' event, but instantly"]
	];

	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	var draggedNote:Array<Dynamic> = null;
	var isDraggingNotes:Bool = false;
	var clickedNoteRef:Array<Dynamic> = null;
	var dragInitialNotes:Array<{note:Array<Dynamic>, origTime:Float, origCol:Int}> = [];
	var dragStartPoint:FlxPoint = new FlxPoint();
	var dragStartVisualCol:Int = 0;
	var dragStartTime:Float = 0;
	var selectionBox:FlxSprite;
	var selectionStart:FlxPoint;
	var selectedNotes:Array<Array<Dynamic>> = [];
	var clipboardNotes:Array<Array<Dynamic>> = [];
	var playtestRateSlider:FlxUISlider;
	public var playtestPlaybackSpeed:Float = 1.0;

	public static var goToPlayState:Bool = false;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	public static var curSec:Int = 0;

	public static var lastSection:Int = 0;
	private static var lastSong:String = '';

	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;
	var camFocusVisualIdx:Int = 0;

	var showVisualChars:FlxUICheckBox;
	var visualCharsGroup:FlxTypedGroup<FlxSprite>;
	var visualDad:FlxSprite = null;
	var visualBf:FlxSprite = null;
	var bfSungInSection:Bool = false;
	var dadSungInSection:Bool = false;

	var tab_group_characters:FlxUI;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;

	var CAM_OFFSET:Int = 360;

	var dummyArrow:FlxSprite;
	var eventIcon:FlxSprite;
	var eventPlayheadArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;
	var strumlineDarkens:Array<FlxSprite> = [];

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	var _song:SwagSong;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic> = null;

	var tempBpm:Float = 0;
	var playbackSpeed:Float = 1;

	var vocals:FlxSound = null;

	// New method of generating icons cuz old sucks and there will be more characters ykyk
	var charIcons:Array<HealthIcon>;
	var charIconsGroup:FlxTypedGroup<HealthIcon>;

	var value1InputText:FlxUIInputText;
	var value2InputText:FlxUIInputText;
	var currentSongName:String;

	var zoomTxt:FlxText;

	var zoomList:Array<Float> = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 24];
	var curZoom:Int = 2;

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenuCustom> = [];
	var characterList:Array<String> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;

	public static var quantization:Int = 16;
	public static var curQuant = 3;

	public var quantizations:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];

	var text:String = "";

	public static var vortex:Bool = false;

	public var mouseQuant:Bool = false;

	var charactersCam:flixel.FlxCamera;

	public function getAmountOfColumns():Int
	{
		var chars:Int = 2; // Default Dad (0) and BF (1)

		// Treat _song as Dynamic to bypass strict Haxe structure checks
		var songDynamic:Dynamic = _song;
		if (songDynamic != null && songDynamic.extraChars != null)
		{
			var extra:Array<Dynamic> = cast songDynamic.extraChars;
			chars += extra.length;
		}

		return chars * 4; // 4 columns per character
	}

	public function getVisualCharOrderOfSection(sectionIndex:Int):Array<Int>
	{
		if (check_classicMode != null && check_classicMode.checked)
		{
			var focusID = 0;
			if (_song != null && _song.notes != null && sectionIndex < _song.notes.length && _song.notes[sectionIndex] != null)
			{
				focusID = getSectionCamFocus(_song.notes[sectionIndex]);
			}
			var charsCount = Std.int(getAmountOfColumns() / 4);
			var order:Array<Int> = [];
			for (i in 0...charsCount)
			{
				if (i == 0)
					order.push(focusID);
				else if (i == focusID)
					order.push(0);
				else
					order.push(i);
			}
			return order;
		}

		var order:Array<Int> = [0]; // Dad
		var songDynamic:Dynamic = _song;
		if (songDynamic != null && songDynamic.extraChars != null)
		{
			var extra:Array<Dynamic> = cast songDynamic.extraChars;
			for (i in 0...extra.length)
			{
				if (extra[i] != null && extra[i].isPlayer != true)
					order.push(i + 2);
			}
			for (i in 0...extra.length)
			{
				if (extra[i] != null && extra[i].isPlayer == true)
					order.push(i + 2);
			}
		}
		order.push(1); // BF
		return order;
	}

	public function logicalToVisualColumnOfSection(logicalCol:Int, sectionIndex:Int):Int
	{
		if (logicalCol < 0)
			return logicalCol;
		var charID:Int = Std.int(logicalCol / 4);
		var dir:Int = logicalCol % 4;
		var order = getVisualCharOrderOfSection(sectionIndex);
		for (i in 0...order.length)
		{
			if (order[i] == charID)
				return (i * 4) + dir;
		}
		return logicalCol;
	}

	public function visualToLogicalColumnOfSection(visualCol:Int, sectionIndex:Int):Int
	{
		if (visualCol < 0)
			return visualCol;
		var slotIndex:Int = Std.int(visualCol / 4);
		var dir:Int = visualCol % 4;
		var order = getVisualCharOrderOfSection(sectionIndex);
		if (slotIndex >= 0 && slotIndex < order.length)
		{
			return (order[slotIndex] * 4) + dir;
		}
		return visualCol;
	}

	public function getVisualCharOrder():Array<Int>
	{
		return getVisualCharOrderOfSection(curSec);
	}

	public function logicalToVisualColumn(logicalCol:Int):Int
	{
		return logicalToVisualColumnOfSection(logicalCol, curSec);
	}

	public function visualToLogicalColumn(visualCol:Int):Int
	{
		return visualToLogicalColumnOfSection(visualCol, curSec);
	}

	override function create()
	{
		Paths.localTrackedAssets = [];
		Paths.clearUnusedMemory();

		#if !html5
		openfl.Assets.cache.clear("songs");
		var keysToRemove:Array<String> = [];
		for (key in Paths.currentTrackedSounds.keys())
		{
			if (key != null
				&& !Paths.dumpExclusions.contains(key)
				&& (key.contains('songs/') || key.contains('Voices') || key.contains('Inst')))
			{
				keysToRemove.push(key);
			}
		}
		for (key in keysToRemove)
		{
			lime.utils.Assets.cache.clear(key);
			Paths.currentTrackedSounds.remove(key);
		}
		#end

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();

			_song = {
				song: 'Test',
				notes: [],
				events: [],
				bpm: 150.0,
				needsVoices: true,
				arrowSkin: '',
				splashSkin: 'noteSplashes', // idk it would crash if i didn't
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				speed: 1,
				stage: 'stage',
				validScore: false,
				authors: ''
			};
			addSection();
			PlayState.SONG = _song;
		}
		normalizeOasisChart(); // Shit fuck

		// Paths.clearMemory();

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editing chart stuff...", StringTools.replace(_song.song, '-', ' '));
		#end

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;

		gridLayer = new FlxTypedGroup<FlxSprite>();

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);

		eventIcon = new FlxSprite(-GRID_SIZE - 5, -90);
		eventIcon.makeGraphic(30, 30, flixel.util.FlxColor.TRANSPARENT);
		flixel.util.FlxSpriteUtil.drawPolygon(eventIcon, [
			new flixel.math.FlxPoint(0, 0),
			new flixel.math.FlxPoint(30, 0),
			new flixel.math.FlxPoint(15, 30)
		], flixel.util.FlxColor.RED);
		eventIcon.scrollFactor.set(1, 1);

		eventPlayheadArrow = new FlxSprite(0, 50).loadGraphic(Paths.image('eventArrow'));
		eventPlayheadArrow.setGraphicSize(GRID_SIZE, GRID_SIZE);
		eventPlayheadArrow.updateHitbox();
		eventPlayheadArrow.scrollFactor.set(1, 1);

		charIcons = new Array<HealthIcon>();
		charIconsGroup = new FlxTypedGroup<HealthIcon>();
		var totalChars = Std.int(getAmountOfColumns() / 4);
		for (i in 0...totalChars)
		{
			var charName:String = 'bf';
			var isPlayer:Bool = false;
			if (i == 0)
			{
				charName = _song.player2; // Dad
				isPlayer = false;
			}
			else if (i == 1)
			{
				charName = _song.player1; // BF
				isPlayer = true;
			}
			else
			{
				var songDynamic:Dynamic = _song;
				if (songDynamic != null && songDynamic.extraChars != null)
				{
					var extra:Array<Dynamic> = cast songDynamic.extraChars;
					if (extra[i - 2] != null)
					{
						if (extra[i - 2].name != null)
							charName = extra[i - 2].name;
						if (extra[i - 2].isPlayer != null)
							isPlayer = extra[i - 2].isPlayer;
					}
				}
			}

			var iconName:String = loadHealthIconFromCharacter(charName);
			var icon:HealthIcon = new HealthIcon(iconName, isPlayer);
			icon.scrollFactor.set(1, 1);
			icon.setGraphicSize(0, 45);
			icon.updateHitbox();
			icon.offset.set(-0.5 * (icon.width - icon.frameWidth), -0.5 * (icon.height - icon.frameHeight)); // Center fix
			var visualSlot = Std.int(logicalToVisualColumn(i * 4) / 4);
			icon.setPosition(GRID_SIZE + (visualSlot * 4 * GRID_SIZE) + (4 * GRID_SIZE) / 2 - icon.width / 2, -50);
			charIcons.push(icon);
			charIconsGroup.add(icon);
		}

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		if (curSec >= _song.notes.length)
			curSec = _song.notes.length - 1;

		FlxG.mouse.visible = true;
		// FlxG.save.bind('funkin', 'ninjamuffin99');

		tempBpm = _song.bpm;

		addSection();

		// sections = _song.notes;

		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);
		resortNotes();

		bpmTxt = new FlxText(10, 40, 0, "", 16);
		bpmTxt.scrollFactor.set();

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * (getAmountOfColumns() + 1)), 4);

		quant = new AttachedSprite('chart_quant', 'chart_quant');
		quant.animation.addByPrefix('q', 'chart_quant', 0, false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		var totalCols = Std.int(getAmountOfColumns());
		for (i in 0...totalCols)
		{
			var charID:Int = Std.int(i / 4); // Automatically calculate character ID for column

			// Pass charID and sideIndex (0) to the updated StrumNote constructor
			var note:StrumNote = new StrumNote(GRID_SIZE * (logicalToVisualColumn(i) + 1), strumLine.y, i % 4, 0, charID, 0);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Metadata", label: 'Metadata'},
			{name: "Characters", label: 'Characters'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(400, 400);
		UI_box.x = FlxG.width - 20 - UI_box.width;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		// Useless trash text
		/*
				text = "W/S or Mouse Wheel - Change Conductor's strum time
			\nA/D - Go to the previous/next section
			\nLeft/Right - Change Snap
			\nUp/Down - Change Conductor's Strum Time with Snapping
			\nLeft Bracket / Right Bracket - Change Song Playback Rate (SHIFT to go Faster)
			\nALT + Left Bracket / Right Bracket - Reset Song Playback Rate
			\nHold Shift to move 4x faster
			\nHold Control and click on an arrow to select it
			\nZ/X - Zoom in/out
			\n
			\nEsc - Test your chart inside Chart Editor
			\nEnter - Play your chart
			\nQ/E - Decrease/Increase Note Sustain Length
			\nSpace - Stop/Resume song";
		 */
		text = "";

		var tipTextArray:Array<String> = text.split('\n');

		addSongUI();
		addMetadataUI();
		addCharactersUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		updateHeads();
		updateWaveform();
		// UI_box.selected_tab = 4;
		UI_box.selected_tab_id = "Song";

		if (lastSong != currentSongName)
		{
			changeSection();
		}
		lastSong = currentSongName;

		zoomTxt = new FlxText(10, 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.scrollFactor.set();

		updateGrid();

		// Background
		add(bg);
		visualCharsGroup = new FlxTypedGroup<FlxSprite>();
		add(visualCharsGroup);
		add(gridLayer);
		add(waveformSprite);

		// Indicators and Strums
		add(strumLine);
		add(quant);
		add(strumLineNotes);
		add(dummyArrow);

		// Dynamic Notes
		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		selectionBox.alpha = 0.3;
		selectionBox.visible = false;
		add(selectionBox);

		// Interface
		add(eventIcon);
		add(eventPlayheadArrow);
		add(charIconsGroup);
		add(bpmTxt);
		add(zoomTxt);
		add(UI_box);
		for (i in 0...tipTextArray.length)
		{
			var tipText:FlxText = new FlxText(UI_box.x, UI_box.y + UI_box.height + 8, 0, tipTextArray[i], 16);
			tipText.y += i * 12;
			tipText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT /*, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK*/);
			// tipText.borderSize = 2;
			tipText.scrollFactor.set();
			add(tipText);
		}

		super.create();

		if (FlxG.save.data.chart_characters == true)
			rebuildVisualCharacters();
	}

	override function destroy()
	{
		if (charactersCam != null)
		{
			FlxG.cameras.remove(charactersCam);
			charactersCam = null;
		}
		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
			vocals = null;
		}
		if (instBuffer != null)
		{
			instBuffer.dispose();
			instBuffer = null;
		}
		instBytes = null;
		if (voicesBuffer != null)
		{
			voicesBuffer.dispose();
			voicesBuffer = null;
		}
		voicesBytes = null;

		characterDropdowns = null;
		blockPressWhileScrolling = null;
		blockPressWhileTypingOn = null;
		blockPressWhileTypingOnStepper = null;
		charTabInputTexts = null;
		charTabSteppers = null;

		super.destroy();
	}

	var check_mute_inst:FlxUICheckBox = null;
	var check_vortex:FlxUICheckBox = null;
	var check_warnings:FlxUICheckBox = null;
	var check_classicMode:FlxUICheckBox = null;
	var playSoundBf:FlxUICheckBox = null;
	var playSoundDad:FlxUICheckBox = null;
	var UI_songTitle:FlxUIInputText;
	var UI_composersInputText:FlxUIInputText;
	var deadCharacterDropDown:FlxUIDropDownMenuCustom;
	var deadCharacterList:Array<String> = [];
	var noteSkinInputText:FlxUIInputText;
	var noteSplashesInputText:FlxUIInputText;
	var stageDropDown:FlxUIDropDownMenuCustom;
	var sliderRate:FlxUISlider;

	var charactersScrollContainer:flixel.group.FlxSpriteGroup;
	var charactersInputTexts:Array<Dynamic> = [];
	var characterDropdowns:Array<FlxUIDropDownMenuCustom> = [];
	var charactersScrollY:Float = 0;

	function addCharactersUI():Void
	{
		tab_group_characters = new FlxUI(null, UI_box);
		tab_group_characters.name = 'Characters';
		UI_box.addGroup(tab_group_characters);

		charactersCam = new FlxCamera(Std.int(UI_box.x + 10), Std.int(UI_box.y + 35), 380, 355);
		charactersCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(charactersCam, false);

		charactersScrollContainer = new flixel.group.FlxSpriteGroup(0, 0);
		add(charactersScrollContainer);
		charactersScrollContainer.cameras = [charactersCam];

		rebuildCharactersUI();
	}

	function refreshOasisLayout():Void
	{
		if (charIcons != null)
		{
			for (icon in charIcons)
			{
				icon.destroy();
			}
		}
		charIcons = [];
		if (charIconsGroup != null)
			charIconsGroup.clear();
		var totalChars = Std.int(getAmountOfColumns() / 4);
		for (i in 0...totalChars)
		{
			var charName:String = 'bf';
			var isPlayer:Bool = false;
			if (i == 0)
			{
				charName = _song.player2;
				isPlayer = false;
			}
			else if (i == 1)
			{
				charName = _song.player1;
				isPlayer = true;
			}
			else
			{
				var songDynamic:Dynamic = _song;
				if (songDynamic != null && songDynamic.extraChars != null)
				{
					var extra:Array<Dynamic> = cast songDynamic.extraChars;
					if (extra[i - 2] != null)
					{
						if (extra[i - 2].name != null)
							charName = extra[i - 2].name;
						if (extra[i - 2].isPlayer != null)
							isPlayer = extra[i - 2].isPlayer;
					}
				}
			}

			var iconName:String = loadHealthIconFromCharacter(charName);
			var icon:HealthIcon = new HealthIcon(iconName, isPlayer);
			icon.scrollFactor.set(1, 1);
			icon.setGraphicSize(0, 45);
			icon.updateHitbox();
			icon.offset.set(-0.5 * (icon.width - icon.frameWidth), -0.5 * (icon.height - icon.frameHeight));
			var visualSlot = Std.int(logicalToVisualColumn(i * 4) / 4);
			icon.setPosition(GRID_SIZE + (visualSlot * 4 * GRID_SIZE) + (4 * GRID_SIZE) / 2 - icon.width / 2, -50);
			charIcons.push(icon);
			charIconsGroup.add(icon);
		}

		if (strumLine != null)
		{
			strumLine.makeGraphic(Std.int(GRID_SIZE * (getAmountOfColumns() + 1)), 4);
		}

		if (strumLineNotes != null)
		{
			strumLineNotes.clear();
			var totalCols = Std.int(getAmountOfColumns());
			for (i in 0...totalCols)
			{
				var charID:Int = Std.int(i / 4);
				var note:StrumNote = new StrumNote(GRID_SIZE * (logicalToVisualColumn(i) + 1), strumLine.y, i % 4, 0, charID, 0);
				note.setGraphicSize(GRID_SIZE, GRID_SIZE);
				note.updateHitbox();
				note.playAnim('static', true);
				strumLineNotes.add(note);
				note.scrollFactor.set(1, 1);
			}
		}

		reloadGridLayer();
		updateGrid();
		updateSectionUI(); // Immediate shading loading
	}

	// Arrays of inputs belonging exclusively to the Characters tab (tracked separately to easily clear them during rebuild)
	var charTabInputTexts:Array<FlxUIInputText> = [];
	var charTabSteppers:Array<FlxUINumericStepper> = [];

	function rebuildCharactersUI():Void
	{
		// STEP 1: Clear old dropdowns from the block list
		if (characterDropdowns != null)
		{
			for (dd in characterDropdowns)
			{
				blockPressWhileScrolling.remove(dd);
			}
		}
		characterDropdowns = [];

		// STEP 2: Clear old Characters inputs from global block arrays (prevents null crash)
		for (inp in charTabInputTexts)
		{
			blockPressWhileTypingOn.remove(inp);
		}
		charTabInputTexts = [];
		for (stp in charTabSteppers)
		{
			blockPressWhileTypingOnStepper.remove(stp);
		}
		charTabSteppers = [];

		// STEP 3: Clear UI containers
		while (charactersScrollContainer.members.length > 0)
		{
			var member = charactersScrollContainer.members[0];
			charactersScrollContainer.remove(member, true);
			if (member != null)
				member.destroy();
		}

		charactersInputTexts = [];

		var songDynamic:Dynamic = _song;
		if (songDynamic.extraChars == null)
		{
			songDynamic.extraChars = [];
		}
		var extra:Array<Dynamic> = cast songDynamic.extraChars;

		var currentY:Float = 10;
		var coreHeight:Float = 115;
		var extraHeight:Float = 165;
		var dropdownsToRenderOnTop:Array<FlxUIDropDownMenuCustom> = [];

		// NARROW EMBEDS FOR MAIN CHARACTERS (Side height reduced to 105px)
		var coreCast:Array<Dynamic> = [
			{
				type: "dad",
				name: _song.player2,
				label: "Dad [ID: 0]",
				hasSkin: true,
				isPlayer: false
			},
			{
				type: "gf",
				name: _song.gfVersion,
				label: "GF",
				hasSkin: false,
				isPlayer: false
			},
			{
				type: "bf",
				name: _song.player1,
				label: "BF [ID: 1]",
				hasSkin: true,
				isPlayer: true
			}
		];

		for (idx in 0...coreCast.length)
		{
			var coreData = coreCast[idx];
			var charY:Float = currentY;

			var bgBox = new FlxSprite(5, charY - 5).makeGraphic(370, Std.int(coreHeight - 10), FlxColor.BLACK);
			bgBox.alpha = 0.6;
			charactersScrollContainer.add(bgBox);

			var iconName:String = loadHealthIconFromCharacter(coreData.name);
			var icon:HealthIcon = new HealthIcon(iconName, coreData.isPlayer);
			icon.setGraphicSize(0, 45);
			icon.updateHitbox();
			icon.offset.set(-0.5 * (icon.width - icon.frameWidth), -0.5 * (icon.height - icon.frameHeight));
			icon.setPosition(15, charY + 5);
			charactersScrollContainer.add(icon);

			var idText = new FlxText(15, charY + 75, 0, coreData.label);
			charactersScrollContainer.add(idText);

			var charDropDown:FlxUIDropDownMenuCustom = null;
			charDropDown = new FlxUIDropDownMenuCustom(80, charY + 10, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characterList, true),
				function(character:String)
				{
					var targetChar:String = characterList[Std.parseInt(character)];
					if (coreData.type == "dad")
						_song.player2 = targetChar;
					else if (coreData.type == "gf")
						_song.gfVersion = targetChar;
					else if (coreData.type == "bf")
						_song.player1 = targetChar;
					refreshOasisLayout();
					rebuildCharactersUI();
				});
			charDropDown.selectedLabel = coreData.name;
			blockPressWhileScrolling.push(charDropDown);
			characterDropdowns.push(charDropDown);
			dropdownsToRenderOnTop.push(charDropDown);

			if (coreData.hasSkin)
			{
				var skinText = new FlxText(80, charY + 45, 0, 'Skin:');
				charactersScrollContainer.add(skinText);

				var skinInput = new FlxUIInputText(120, charY + 45, 100, _song.arrowSkin, 8);
				blockPressWhileTypingOn.push(skinInput);
				charTabInputTexts.push(skinInput);
				charactersScrollContainer.add(skinInput);
				charactersInputTexts.push({input: skinInput, data: _song, isArrowSkin: true});
			}

			currentY += coreHeight;
		}

		// STANDARD 16-ROW EMBEDS FOR GUEST CHARACTERS (ID 2+)
		for (i in 0...extra.length)
		{
			var charData = extra[i];
			if (charData.name == null)
				charData.name = 'bf';
			if (Reflect.field(charData, 'isPlayer') == null)
				charData.isPlayer = false;
			if (Reflect.field(charData, 'isBelow') == null)
				charData.isBelow = false;
			if (charData.noteSkin == null)
				charData.noteSkin = '';
			if (Reflect.field(charData, 'x') == null)
				charData.x = 0;
			if (Reflect.field(charData, 'y') == null)
				charData.y = 0;

			var charY:Float = currentY;

			var bgBox = new FlxSprite(5, charY - 5).makeGraphic(370, Std.int(extraHeight - 10), FlxColor.BLACK);
			bgBox.alpha = 0.6;
			charactersScrollContainer.add(bgBox);

			var iconName:String = loadHealthIconFromCharacter(charData.name);
			var icon:HealthIcon = new HealthIcon(iconName, charData.isPlayer);
			icon.setGraphicSize(0, 45);
			icon.updateHitbox();
			icon.offset.set(-0.5 * (icon.width - icon.frameWidth), -0.5 * (icon.height - icon.frameHeight));
			icon.setPosition(15, charY + 5);
			charactersScrollContainer.add(icon);

			var idText = new FlxText(15, charY + 60, 0, 'ID: ' + (i + 2));
			charactersScrollContainer.add(idText);

			var charDropDown:FlxUIDropDownMenuCustom = null;
			charDropDown = new FlxUIDropDownMenuCustom(80, charY + 10, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characterList, true),
				function(character:String)
				{
					charData.name = characterList[Std.parseInt(character)];
					refreshOasisLayout();
					rebuildCharactersUI();
				});
			charDropDown.selectedLabel = charData.name;
			blockPressWhileScrolling.push(charDropDown);
			characterDropdowns.push(charDropDown);
			dropdownsToRenderOnTop.push(charDropDown);

			var playerCheck:FlxUICheckBox = null;
			playerCheck = new FlxUICheckBox(80, charY + 50, null, null, "Player?", 80);
			playerCheck.callback = function()
			{
				charData.isPlayer = playerCheck.checked;
				refreshOasisLayout();
				rebuildCharactersUI();
			};
			playerCheck.checked = charData.isPlayer;
			charactersScrollContainer.add(playerCheck);

			var belowCheck:FlxUICheckBox = null;
			belowCheck = new FlxUICheckBox(180, charY + 50, null, null, "Below?", 80);
			belowCheck.callback = function()
			{
				charData.isBelow = belowCheck.checked;
				refreshOasisLayout();
				rebuildCharactersUI();
			};
			belowCheck.checked = charData.isBelow;
			charactersScrollContainer.add(belowCheck);

			var skinText = new FlxText(80, charY + 80, 0, 'Skin:');
			charactersScrollContainer.add(skinText);

			var skinInput = new FlxUIInputText(120, charY + 80, 100, charData.noteSkin != null ? charData.noteSkin : '', 8);
			blockPressWhileTypingOn.push(skinInput);
			charTabInputTexts.push(skinInput);
			charactersScrollContainer.add(skinInput);
			charactersInputTexts.push({input: skinInput, data: charData});

			var xLabel = new FlxText(45, charY + 105, 0, 'OffsetX:');
			charactersScrollContainer.add(xLabel);
			var stepperX:FlxUINumericStepper = new FlxUINumericStepper(100, charY + 105, 10,
				(Reflect.field(charData, 'x') != null ? (charData.x : Float) : 0.0), -9999, 9999, 0);
			stepperX.name = 'extraChar_x_' + i;
			blockPressWhileTypingOnStepper.push(stepperX);
			charTabSteppers.push(stepperX);
			charactersScrollContainer.add(stepperX);
			charactersInputTexts.push({stepper: stepperX, data: charData, field: 'x'});

			var yLabel = new FlxText(175, charY + 105, 0, 'OffsetY:');
			charactersScrollContainer.add(yLabel);
			var stepperY:FlxUINumericStepper = new FlxUINumericStepper(230, charY + 105, 10,
				(Reflect.field(charData, 'y') != null ? (charData.y : Float) : 0.0), -9999, 9999, 0);
			stepperY.name = 'extraChar_y_' + i;
			blockPressWhileTypingOnStepper.push(stepperY);
			charTabSteppers.push(stepperY);
			charactersScrollContainer.add(stepperY);
			charactersInputTexts.push({stepper: stepperY, data: charData, field: 'y'});

			var removeBtn:FlxButton = new FlxButton(305, charY + 105, "Remove", function()
			{
				extra.splice(i, 1);
				refreshOasisLayout();
				rebuildCharactersUI();
			});
			removeBtn.color = FlxColor.RED;
			removeBtn.label.color = FlxColor.WHITE;
			charactersScrollContainer.add(removeBtn);

			currentY += extraHeight;
		}

		var addBtn:FlxButton = new FlxButton(150, currentY + 10, "Add New Character", function()
		{
			extra.push({
				name: 'bf',
				isPlayer: false,
				isBelow: false,
				noteSkin: '',
				x: 0,
				y: 0
			});
			refreshOasisLayout();
			rebuildCharactersUI();
		});
		addBtn.color = FlxColor.GREEN;
		addBtn.label.color = FlxColor.WHITE;
		charactersScrollContainer.add(addBtn);

		var j:Int = dropdownsToRenderOnTop.length - 1;
		while (j >= 0)
		{
			charactersScrollContainer.add(dropdownsToRenderOnTop[j]);
			j--;
		}
	}

	function addMetadataUI():Void
	{
		var tab_group_metadata = new FlxUI(null, UI_box);
		tab_group_metadata.name = "Metadata";

		var check_cameraEditor = new FlxUICheckBox(15, 40, null, null, "Use Camera Custom Movements", 100);
		check_cameraEditor.checked = (_song.useCameraEditor == true);
		check_cameraEditor.callback = function()
		{
			_song.useCameraEditor = check_cameraEditor.checked;
		};

		var authorsStr = _song.authors;
		if (authorsStr == null)
			authorsStr = '';
		UI_composersInputText = new FlxUIInputText(10, 80, 150, authorsStr, 8);
		blockPressWhileTypingOn.push(UI_composersInputText);

		var deadCharStr = _song.gameOverChar;
		if (deadCharStr == null || deadCharStr == '')
			deadCharStr = 'bf-dead';

		var deadCharIndex = deadCharacterList.indexOf(deadCharStr);
		if (deadCharIndex < 0)
			deadCharIndex = 0;

		deadCharacterDropDown = new FlxUIDropDownMenuCustom(10, 120, FlxUIDropDownMenuCustom.makeStrIdLabelArray(deadCharacterList, true),
			function(character:String)
			{
				_song.gameOverChar = deadCharacterList[Std.parseInt(character)];
			});
		deadCharacterDropDown.selectedLabel = deadCharStr;
		blockPressWhileScrolling.push(deadCharacterDropDown);

		tab_group_metadata.add(check_cameraEditor);
		tab_group_metadata.add(new FlxText(UI_composersInputText.x, UI_composersInputText.y - 15, 0, 'Composers (Authors):'));
		tab_group_metadata.add(UI_composersInputText);
		tab_group_metadata.add(new FlxText(deadCharacterDropDown.x, deadCharacterDropDown.y - 15, 0, 'Game Over Character:'));
		tab_group_metadata.add(deadCharacterDropDown);

		UI_box.addGroup(tab_group_metadata);
	}

	function addSongUI():Void
	{
		UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song, 8);
		blockPressWhileTypingOn.push(UI_songTitle);
		var check_voices = new FlxUICheckBox(10, 25, null, null, "Has voice track", 100);
		check_voices.checked = _song.needsVoices;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
		};

		var saveButton:FlxButton = new FlxButton(110, 8, "Save", function()
		{
			saveLevel();
		});
		var reloadSong:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			loadSong();
			updateWaveform();
		});
		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function()
			{
				loadJson(_song.song.toLowerCase());
			}, null, ignoreWarnings));
		});
		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
			MusicBeatState.resetState();
		});
		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function()
		{
			var songName:String = Paths.formatToSongPath(_song.song);
			var file:String = Paths.json(songName + '/events');
			#if sys
			if (#if MODS_ALLOWED FileSystem.exists(Paths.modsJson(songName + '/events')) || #end FileSystem.exists(file))
			#else
			if (OpenFlAssets.exists(file))
			#end
			{
				clearEvents();
				var events:SwagSong = Song.loadFromJson('events', songName);
				_song.events = events.events;
				changeSection(curSec);
			}
		});
		var saveEvents:FlxButton = new FlxButton(110, reloadSongJson.y, 'Save Events', function()
		{
			saveEvents();
		});
		var clear_events:FlxButton = new FlxButton(320, 310, 'Clear events', function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null, ignoreWarnings));
		});
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(320, clear_events.y + 30, 'Clear notes', function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function()
			{
				for (sec in 0..._song.notes.length)
				{
					_song.notes[sec].sectionNotes = [];
				}
				updateGrid();
			}, null, ignoreWarnings));
		});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 400, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);

		#if MODS_ALLOWED
		var directories:Array<String> = [
			Paths.mods('characters/'),
			Paths.mods(Paths.currentModDirectory + '/characters/'),
			Paths.getPreloadPath('characters/')
		];
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('characters/')];
		#end

		var tempMap:Map<String, Bool> = new Map<String, Bool>();
		characterList = CoolUtil.coolTextFile(Paths.txt('characterList'));
		for (i in 0...characterList.length)
		{
			tempMap.set(characterList[i], true);
		}

		var tempMapDead:Map<String, Bool> = new Map<String, Bool>();
		deadCharacterList = ['bf-dead']; // default

		#if MODS_ALLOWED
		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var charToCheck:String = file.substr(0, file.length - 5);
						if (!charToCheck.endsWith('-dead') && !tempMap.exists(charToCheck))
						{
							tempMap.set(charToCheck, true);
							characterList.push(charToCheck);
						}
						else if (charToCheck.endsWith('-dead') && !tempMapDead.exists(charToCheck))
						{
							tempMapDead.set(charToCheck, true);
							if (charToCheck != 'bf-dead')
								deadCharacterList.push(charToCheck);
						}
					}
				}
			}
		}
		#end

		#if MODS_ALLOWED
		var directories:Array<String> = [
			Paths.mods('stages/'),
			Paths.mods(Paths.currentModDirectory + '/stages/'),
			Paths.getPreloadPath('stages/')
		];
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('stages/')];
		#end

		tempMap.clear();
		var stageFile:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));
		var stages:Array<String> = [];
		for (i in 0...stageFile.length)
		{
			var stageToCheck:String = stageFile[i];
			if (!tempMap.exists(stageToCheck))
			{
				stages.push(stageToCheck);
			}
			tempMap.set(stageToCheck, true);
		}
		#if MODS_ALLOWED
		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var stageToCheck:String = file.substr(0, file.length - 5);
						if (!tempMap.exists(stageToCheck))
						{
							tempMap.set(stageToCheck, true);
							stages.push(stageToCheck);
						}
					}
				}
			}
		}
		#end

		if (stages.length < 1)
			stages.push('stage');

		stageDropDown = new FlxUIDropDownMenuCustom(10, stepperSpeed.y + 45, FlxUIDropDownMenuCustom.makeStrIdLabelArray(stages, true),
			function(character:String)
			{
				_song.stage = stages[Std.parseInt(character)];
			});
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		var skin = PlayState.SONG.arrowSkin;
		if (skin == null)
			skin = '';

		noteSkinInputText = new FlxUIInputText(10, stageDropDown.y + 50, 150, skin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, _song.splashSkin, 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', function()
		{
			_song.arrowSkin = noteSkinInputText.text;
			updateGrid();
		});

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEvents);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);

		playtestRateSlider = new FlxUISlider(this, 'playtestPlaybackSpeed', stepperSpeed.x + 100, stepperSpeed.y, 0.5, 3, 100, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		playtestRateSlider.nameLabel.text = 'Playtest Rate';
		playtestRateSlider.decimals = 1;
		tab_group_song.add(playtestRateSlider);
		tab_group_song.add(reloadNotesButton);
		tab_group_song.add(noteSkinInputText);
		tab_group_song.add(noteSplashesInputText);

		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperBPM.x + 100, stepperBPM.y - 15, 0, 'Song Offset:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		tab_group_song.add(stageDropDown);

		UI_box.addGroup(tab_group_song);
		FlxG.camera.follow(camPos);
	}

	var stepperBeats:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;
	var stepperCamFocus:FlxUINumericStepper;
	var sectionToCopy:Int = 0;
	var notesCopied:Array<Dynamic>;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		// Safety check fallback for Oasis Engine
		var sec = _song.notes[curSec];

		check_mustHitSection = new FlxUICheckBox(10, 15, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = (sec != null) ? sec.mustHitSection : true;
		check_mustHitSection.active = false; // Debugger is read-only

		check_gfSection = new FlxUICheckBox(10, check_mustHitSection.y + 22, null, null, "GF section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = (sec != null) ? sec.gfSection : false;

		check_altAnim = new FlxUICheckBox(check_gfSection.x + 120, check_gfSection.y, null, null, "Alt Animation", 100);
		check_altAnim.checked = (sec != null) ? sec.altAnim : false;
		check_altAnim.name = 'check_altAnim';

		// === TIME SIGNATURE ===
		// Beats per measure numerator (e.g. 4 for 4/4, 3 for 3/4)
		stepperBeats = new FlxUINumericStepper(10, 100, 1, 4, 1, 32, 0);
		stepperBeats.value = Math.floor(getSectionBeats());
		stepperBeats.name = 'section_beats';
		blockPressWhileTypingOnStepper.push(stepperBeats);

		check_changeBPM = new FlxUICheckBox(10, stepperBeats.y + 30, null, null, 'Change BPM', 100);
		check_changeBPM.checked = (sec != null) ? sec.changeBPM : false;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
		if (sec != null && sec.changeBPM)
		{
			stepperSectionBPM.value = sec.bpm;
		}
		else
		{
			stepperSectionBPM.value = Conductor.bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		stepperCamFocus = new FlxUINumericStepper(220, stepperSectionBPM.y, 1, -1, -1, 10, 0);
		stepperCamFocus.name = 'section_cam_focus';
		stepperCamFocus.value = getSectionCamFocus(sec);
		blockPressWhileTypingOnStepper.push(stepperCamFocus);

		var focusLabel:FlxText = new FlxText(220, stepperCamFocus.y - 18, 0, 'Camera Focus (-1 = Auto):');
		tab_group_section.add(focusLabel);
		tab_group_section.add(stepperCamFocus);

		var check_eventsSec:FlxUICheckBox = null;
		var check_notesSec:FlxUICheckBox = null;

		var copyButton:FlxButton = new FlxButton(10, 190, "Copy Section", function()
		{
			notesCopied = [];
			sectionToCopy = curSec;
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				var col:Int = note[1];
				if (check_classicMode != null && check_classicMode.checked)
				{
					col = logicalToVisualColumnOfSection(col, curSec);
				}
				var copiedNote:Array<Dynamic> = [note[0], col, note[2], note[3]];
				if (note[4] != null)
					copiedNote.push(note[4]);
				notesCopied.push(copiedNote);
			}

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(copyButton.x + 100, copyButton.y, "Paste Section", function()
		{
			if (notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));

			for (note in notesCopied)
			{
				var copiedNote:Array<Dynamic> = [];
				var newStrumTime:Float = note[0] + addToTime;
				if (note[1] < 0)
				{
					if (check_eventsSec.checked)
					{
						var copiedEventArray:Array<Dynamic> = [];
						for (i in 0...note[2].length)
						{
							var eventToPush:Array<Dynamic> = note[2][i];
							copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
						}
						_song.events.push([newStrumTime, copiedEventArray]);
					}
				}
				else
				{
					if (check_notesSec.checked)
					{
						var col:Int = note[1];
						if (check_classicMode != null && check_classicMode.checked)
						{
							col = visualToLogicalColumnOfSection(col, curSec);
						}
						if (note[4] != null)
						{
							copiedNote = [newStrumTime, col, note[2], note[3], note[4]];
						}
						else
						{
							copiedNote = [newStrumTime, col, note[2], note[3]];
						}
						_song.notes[curSec].sectionNotes.push(copiedNote);
					}
				}
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 100, pasteButton.y, "Clear", function()
		{
			if (check_notesSec.checked)
			{
				_song.notes[curSec].sectionNotes = [];
			}

			if (check_eventsSec.checked)
			{
				var i:Int = _song.events.length - 1;
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				while (i > -1)
				{
					var event:Array<Dynamic> = _song.events[i];
					if (event != null && endThing > event[0] && event[0] >= startThing)
					{
						_song.events.remove(event);
					}
					--i;
				}
			}
			updateGrid();
			updateNoteUI();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;

		check_notesSec = new FlxUICheckBox(10, clearSectionButton.y + 25, null, null, "Notes", 100);
		check_notesSec.checked = true;

		check_eventsSec = new FlxUICheckBox(check_notesSec.x + 100, check_notesSec.y, null, null, "Events", 100);
		check_eventsSec.checked = true;

		var swapChar1Stepper = new FlxUINumericStepper(10, check_notesSec.y + 40, 1, 0, 0, 999, 0);
		var swapChar1Label = new FlxText(swapChar1Stepper.x + 60, swapChar1Stepper.y + 2, 0, "Char 1 ID");
		
		var swapChar2Stepper = new FlxUINumericStepper(130, check_notesSec.y + 40, 1, 1, 0, 999, 0);
		var swapChar2Label = new FlxText(swapChar2Stepper.x + 60, swapChar2Stepper.y + 2, 0, "Char 2 ID");

		var swapSection:FlxButton = new FlxButton(10, swapChar1Stepper.y + 30, "Swap Selected", function()
		{
			var id1:Int = Std.int(swapChar1Stepper.value);
			var id2:Int = Std.int(swapChar2Stepper.value);
			if (id1 == id2) return;
			pushUndoSnapshot();

			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				var col:Int = Std.int(note[1]);
				if (col >= id1 * 4 && col < (id1 + 1) * 4)
				{
					note[1] = col - (id1 * 4) + (id2 * 4);
					_song.notes[curSec].sectionNotes[i] = note;
				}
				else if (col >= id2 * 4 && col < (id2 + 1) * 4)
				{
					note[1] = col - (id2 * 4) + (id1 * 4);
					_song.notes[curSec].sectionNotes[i] = note;
				}
			}
			updateGrid();
		});

		var stepperCopy:FlxUINumericStepper = null;
		var copyLastButton:FlxButton = new FlxButton(10, swapSection.y + 30, "Copy last section", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if (value == 0)
				return;

			var daSec = FlxMath.maxInt(curSec, value);

			for (note in _song.notes[daSec - value].sectionNotes)
			{
				var strum = note[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);

				var col:Int = note[1];
				if (check_classicMode != null && check_classicMode.checked)
				{
					var visualCol = logicalToVisualColumnOfSection(col, daSec - value);
					col = visualToLogicalColumnOfSection(visualCol, daSec);
				}
				var copiedNote:Array<Dynamic> = [strum, col, note[2], note[3]];
				_song.notes[daSec].sectionNotes.push(copiedNote);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					strumTime += Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					_song.events.push([strumTime, copiedEventArray]);
				}
			}
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();

		stepperCopy = new FlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		var duetButton:FlxButton = new FlxButton(10, copyLastButton.y + 45, "Duet Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1];
				if (boob > 3)
				{
					boob -= 4;
				}
				else
				{
					boob += 4;
				}

				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				duetNotes.push(copiedNote);
			}

			for (i in duetNotes)
			{
				_song.notes[curSec].sectionNotes.push(i);
			}

			updateGrid();
		});

		var mirrorButton:FlxButton = new FlxButton(duetButton.x + 100, duetButton.y, "Mirror Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1] % 4;
				boob = 3 - boob;
				if (note[1] > 3)
					boob += 4;

				note[1] = boob;
			}
			updateGrid();
		});

		var beatsLabel = new FlxText(stepperBeats.x, stepperBeats.y - 15, 0, 'Beats Per Section:');
		tab_group_section.add(beatsLabel);
		tab_group_section.add(stepperBeats);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(pasteButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(check_notesSec);
		tab_group_section.add(check_eventsSec);
		tab_group_section.add(swapChar1Stepper);
		tab_group_section.add(swapChar1Label);
		tab_group_section.add(swapChar2Stepper);
		tab_group_section.add(swapChar2Label);
		tab_group_section.add(swapSection);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyLastButton);
		tab_group_section.add(duetButton);
		tab_group_section.add(mirrorButton);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;
	var strumTimeInputText:FlxUIInputText; // I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:FlxUIDropDownMenuCustom;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 64);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new FlxUIInputText(10, 65, 180, "0");
		tab_group_note.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length)
		{
			displayNameList.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if LUA_ALLOWED
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('notetypes/'));
		directories.push(Paths.mods(Paths.currentModDirectory + '/notetypes/'));
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/notetypes/'));
		#end

		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.lua'))
					{
						var fileToCheck:String = file.substr(0, file.length - 4);
						if (!noteTypeMap.exists(fileToCheck))
						{
							displayNameList.push(fileToCheck);
							noteTypeMap.set(fileToCheck, key);
							noteTypeIntMap.set(key, fileToCheck);
							key++;
						}
					}
				}
			}
		}
		#end

		for (i in 1...displayNameList.length)
		{
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		noteTypeDropDown = new FlxUIDropDownMenuCustom(10, 105, FlxUIDropDownMenuCustom.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			currentType = Std.parseInt(character);
			if (curSelectedNote != null && curSelectedNote[1] > -1)
			{
				curSelectedNote[3] = noteTypeIntMap.get(currentType);
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		tab_group_note.add(new FlxText(10, 10, 0, 'Sustain length:'));
		tab_group_note.add(new FlxText(10, 50, 0, 'Strum time (in miliseconds):'));
		tab_group_note.add(new FlxText(10, 90, 0, 'Note type:'));
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(strumTimeInputText);
		tab_group_note.add(noteTypeDropDown);

		UI_box.addGroup(tab_group_note);
	}

	var eventDropDown:FlxUIDropDownMenuCustom;
	var descText:FlxText;
	var selectedEventText:FlxText;

	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Events';

		#if LUA_ALLOWED
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('events/'));
		directories.push(Paths.mods(Paths.currentModDirectory + '/events/'));
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/events/'));
		#end

		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt'))
					{
						var fileToCheck:String = file.substr(0, file.length - 4);
						if (!eventPushedMap.exists(fileToCheck))
						{
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, File.getContent(path)]);
						}
					}
				}
			}
		}
		eventPushedMap.clear();
		eventPushedMap = null;
		#end

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length)
		{
			leEvents.push(eventStuff[i][0]);
		}

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
		tab_group_event.add(text);
		eventDropDown = new FlxUIDropDownMenuCustom(20, 50, FlxUIDropDownMenuCustom.makeStrIdLabelArray(leEvents, true), function(pressed:String)
		{
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventStuff[selectedEvent][1];
			if (curSelectedNote != null && eventStuff != null)
			{
				if (curSelectedNote != null && curSelectedNote[2] == null)
				{
					curSelectedNote[1][curEventSelected][0] = eventStuff[selectedEvent][0];
				}
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(eventDropDown);

		var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new FlxUIInputText(20, 110, 100, "");
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new FlxUIInputText(20, 150, 100, "");
		blockPressWhileTypingOn.push(value2InputText);

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
			{
				if (curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if (curEventSelected < 0)
					curEventSelected = 0;
				else if (curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length)
					curEventSelected = eventsGroup.length - 1;

				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		tab_group_event.add(removeButton);

		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		tab_group_event.add(addButton);

		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', function()
		{
			changeEventSelected(-1);
		});
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		tab_group_event.add(moveLeftButton);

		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function()
		{
			changeEventSelected(1);
		});
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);

		UI_box.addGroup(tab_group_event);
	}

	function changeEventSelected(change:Int = 0)
	{
		if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
		{
			curEventSelected += change;
			if (curEventSelected < 0)
				curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if (curEventSelected >= curSelectedNote[1].length)
				curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	var metronome:FlxUICheckBox;
	var mouseScrollingQuant:FlxUICheckBox;
	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;
	var disableAutoScrolling:FlxUICheckBox;
	#if desktop
	var waveformUseInstrumental:FlxUICheckBox;
	var waveformUseVoices:FlxUICheckBox;
	#end
	var check_showFocusIcon:FlxUICheckBox;
	var instVolume:FlxUINumericStepper;
	var voicesVolume:FlxUINumericStepper;

	function addChartingUI()
	{
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Charting';

		#if desktop
		if (FlxG.save.data.chart_waveformInst == null)
			FlxG.save.data.chart_waveformInst = false;
		if (FlxG.save.data.chart_waveformVoices == null)
			FlxG.save.data.chart_waveformVoices = false;

		waveformUseInstrumental = new FlxUICheckBox(10, 90, null, null, "Waveform for Instrumental", 100);
		waveformUseInstrumental.checked = FlxG.save.data.chart_waveformInst;
		waveformUseInstrumental.callback = function()
		{
			waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked;
			updateWaveform();
		};

		waveformUseVoices = new FlxUICheckBox(waveformUseInstrumental.x + 120, waveformUseInstrumental.y, null, null, "Waveform for Voices", 100);
		waveformUseVoices.checked = FlxG.save.data.chart_waveformVoices;
		waveformUseVoices.callback = function()
		{
			waveformUseInstrumental.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked;
			updateWaveform();
		};
		#end

		check_mute_inst = new FlxUICheckBox(10, 310, null, null, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};
		mouseScrollingQuant = new FlxUICheckBox(10, 200, null, null, "Mouse Scrolling Quantization", 100);
		if (FlxG.save.data.mouseScrollingQuant == null)
			FlxG.save.data.mouseScrollingQuant = false;
		mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

		mouseScrollingQuant.callback = function()
		{
			FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = FlxG.save.data.mouseScrollingQuant;
		};

		check_vortex = new FlxUICheckBox(10, 160, null, null, "Vortex Editor (BETA)", 100);
		if (FlxG.save.data.chart_vortex == null)
			FlxG.save.data.chart_vortex = false;
		check_vortex.checked = FlxG.save.data.chart_vortex;

		check_vortex.callback = function()
		{
			FlxG.save.data.chart_vortex = check_vortex.checked;
			vortex = FlxG.save.data.chart_vortex;
			reloadGridLayer();
		};

		check_warnings = new FlxUICheckBox(10, 120, null, null, "Ignore Progress Warnings", 100);
		if (FlxG.save.data.ignoreWarnings == null)
			FlxG.save.data.ignoreWarnings = false;
		check_warnings.checked = FlxG.save.data.ignoreWarnings;

		check_warnings.callback = function()
		{
			FlxG.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = FlxG.save.data.ignoreWarnings;
		};

		var check_mute_vocals = new FlxUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, null, null, "Mute Vocals (in editor)", 100);
		check_mute_vocals.checked = false;
		check_mute_vocals.callback = function()
		{
			if (vocals != null)
			{
				var vol:Float = 1;

				if (check_mute_vocals.checked)
					vol = 0;

				vocals.volume = vol;
			}
		};

		check_classicMode = new FlxUICheckBox(check_mute_vocals.x + 120, 200, null, null, "Legacy Chart Layout", 100);
		if (FlxG.save.data.classicChartingMode == null)
			FlxG.save.data.classicChartingMode = false;
		check_classicMode.checked = FlxG.save.data.classicChartingMode;
		check_classicMode.callback = function()
		{
			FlxG.save.data.classicChartingMode = check_classicMode.checked;
			refreshOasisLayout();
		};

		check_showFocusIcon = new FlxUICheckBox(check_classicMode.x, check_classicMode.y + 30, null, null, "Show Focus on Playhead", 100);
		if (FlxG.save.data.chart_showFocusIcon == null)
			FlxG.save.data.chart_showFocusIcon = true;
		check_showFocusIcon.checked = FlxG.save.data.chart_showFocusIcon;
		check_showFocusIcon.callback = function()
		{
			FlxG.save.data.chart_showFocusIcon = check_showFocusIcon.checked;
		};

		playSoundBf = new FlxUICheckBox(check_mute_inst.x, check_mute_vocals.y + 30, null, null, 'Play Sound (Boyfriend notes)', 100, function()
		{
			FlxG.save.data.chart_playSoundBf = playSoundBf.checked;
		});
		if (FlxG.save.data.chart_playSoundBf == null)
			FlxG.save.data.chart_playSoundBf = false;
		playSoundBf.checked = FlxG.save.data.chart_playSoundBf;

		playSoundDad = new FlxUICheckBox(check_mute_inst.x + 120, playSoundBf.y, null, null, 'Play Sound (Opponent notes)', 100, function()
		{
			FlxG.save.data.chart_playSoundDad = playSoundDad.checked;
		});
		if (FlxG.save.data.chart_playSoundDad == null)
			FlxG.save.data.chart_playSoundDad = false;
		playSoundDad.checked = FlxG.save.data.chart_playSoundDad;

		metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100, function()
		{
			FlxG.save.data.chart_metronome = metronome.checked;
		});
		if (FlxG.save.data.chart_metronome == null)
			FlxG.save.data.chart_metronome = false;
		metronome.checked = FlxG.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, _song.bpm, 1, 1500, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 120, metronome.y, null, null, "Disable Autoscroll (Not Recommended)", 120, function()
		{
			FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
		});
		if (FlxG.save.data.chart_noAutoScroll == null)
			FlxG.save.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(metronomeStepper.x, 270, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		voicesVolume = new FlxUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';
		blockPressWhileTypingOnStepper.push(voicesVolume);

		#if !html5
		sliderRate = new FlxUISlider(this, 'playbackSpeed', 120, 120, 0.5, 3, 150, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = 'Playback Rate';
		tab_group_chart.add(sliderRate);
		#end

		showVisualChars = new FlxUICheckBox(check_mute_vocals.x + 120, check_mute_vocals.y, null, null, "Show Visual Characters", 100, function()
		{
			rebuildVisualCharacters();
		});
		showVisualChars.checked = FlxG.save.data.chart_characters;
		showVisualChars.callback = function()
		{
			FlxG.save.data.chart_characters = showVisualChars.checked;
			rebuildVisualCharacters();
		};
		if (FlxG.save.data.chart_characters == null)
			FlxG.save.data.chart_characters = false;

		tab_group_chart.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'BPM:'));
		tab_group_chart.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):'));
		tab_group_chart.add(new FlxText(instVolume.x, instVolume.y - 15, 0, 'Inst Volume'));
		tab_group_chart.add(new FlxText(voicesVolume.x, voicesVolume.y - 15, 0, 'Voices Volume'));
		tab_group_chart.add(metronome);
		tab_group_chart.add(disableAutoScrolling);
		tab_group_chart.add(metronomeStepper);
		tab_group_chart.add(metronomeOffsetStepper);
		#if desktop
		tab_group_chart.add(waveformUseInstrumental);
		tab_group_chart.add(waveformUseVoices);
		#end
		tab_group_chart.add(instVolume);
		tab_group_chart.add(voicesVolume);
		tab_group_chart.add(check_mute_inst);
		tab_group_chart.add(check_mute_vocals);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_warnings);
		tab_group_chart.add(check_classicMode);
		tab_group_chart.add(check_showFocusIcon);
		tab_group_chart.add(playSoundBf);
		tab_group_chart.add(playSoundDad);
		tab_group_chart.add(showVisualChars);

		UI_box.addGroup(tab_group_chart);
	}

	function loadSong():Void
	{
		if (instBuffer != null)
		{
			instBuffer.dispose();
			instBuffer = null;
		}
		instBytes = null;
		if (voicesBuffer != null)
		{
			voicesBuffer.dispose();
			voicesBuffer = null;
		}
		voicesBytes = null;

		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			// vocals.stop();
		}

		var file:Dynamic = Paths.voices(currentSongName);
		vocals = new FlxSound();
		if (Std.isOfType(file, Sound) || OpenFlAssets.exists(file))
		{
			vocals.loadEmbedded(file);
			FlxG.sound.list.add(vocals);
		}
		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;
		rebuildVisualCharacters();
	}

	function generateSong()
	{
		FlxG.sound.playMusic(Paths.inst(currentSongName), 0.6 /*, false*/);
		if (instVolume != null)
			FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked)
			FlxG.sound.music.volume = 0;

		FlxG.sound.music.onComplete = function()
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			if (vocals != null)
			{
				vocals.pause();
				vocals.time = 0;
			}
			changeSection();
			curSec = 0;
			updateGrid();
			updateSectionUI();
			vocals.play();
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = (check.getLabel() != null) ? check.getLabel().text : "";
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSec].mustHitSection = check.checked;

					updateGrid();
					updateHeads();

				case 'GF section':
					_song.notes[curSec].gfSection = check.checked;

					updateGrid();
					updateHeads();

				case 'Change BPM':
					_song.notes[curSec].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
				case "Alt Animation":
					_song.notes[curSec].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);
			if (wname == 'section_beats')
			{
				_song.notes[curSec].sectionBeats = nums.value;
				resortNotes();
				reloadGridLayer();
			}
			else if (wname == 'song_speed')
			{
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				tempBpm = nums.value;
				Conductor.mapBPMChanges(_song);
				Conductor.changeBPM(nums.value);
			}
			else if (wname == 'note_susLength')
			{
				if (curSelectedNote != null && curSelectedNote[2] != null)
				{
					curSelectedNote[2] = nums.value;
					updateGrid();
				}
			}
			else if (wname == 'section_bpm')
			{
				_song.notes[curSec].bpm = nums.value;
				updateGrid();
			}
			else if (wname == 'inst_volume')
			{
				FlxG.sound.music.volume = nums.value;
			}
			else if (wname == 'voices_volume')
			{
				vocals.volume = nums.value;
			}
			else if (wname == 'section_cam_focus')
			{
				var secDynamic:Dynamic = _song.notes[curSec];
				secDynamic.camFocus = Std.int(nums.value);

				// OASIS ENGINE FOCUS SYNC: mustHitSection is true only for character ID = 1 (BF)
				_song.notes[curSec].mustHitSection = (secDynamic.camFocus == 1);

				updateGrid();
				updateSectionUI();
			}
		}
		else if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == noteSplashesInputText)
			{
				_song.splashSkin = noteSplashesInputText.text;
			}
			else if (curSelectedNote != null)
			{
				if (sender == value1InputText)
				{
					if (curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][1] = value1InputText.text;
						updateGrid();
					}
				}
				else if (sender == value2InputText)
				{
					if (curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][2] = value2InputText.text;
						updateGrid();
					}
				}
				else if (sender == strumTimeInputText)
				{
					var value:Float = Std.parseFloat(strumTimeInputText.text);
					if (Math.isNaN(value))
						value = 0;
					curSelectedNote[0] = value;
					updateGrid();
				}
			}
		}
		else if (id == FlxUISlider.CHANGE_EVENT && (sender is FlxUISlider))
		{
			var slider:FlxUISlider = cast sender;
			switch (slider.name)
			{
				case 'playbackSpeed':
					playbackSpeed = sliderRate.value;
			}
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	function sectionStartTime(add:Int = 0):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSec + add)
		{
			if (_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					daBPM = _song.notes[i].bpm;
				}
				daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
			}
		}
		return daPos;
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;

	override function update(elapsed:Float)
	{
		curStep = recalculateSteps();

		if (FlxG.sound.music.time < 0)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		_song.song = UI_songTitle.text;
		_song.authors = UI_composersInputText.text;

		strumLineUpdateY();
		var sec = _song.notes[curSec];
		var focusID:Int = getSectionCamFocus(sec);

		for (i in 0...strumLineNotes.length)
		{
			strumLineNotes.members[i].y = strumLine.y;
			var charID:Int = Std.int(i / 4);
			if (charID == focusID)
			{
				strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
			}
			else
			{
				strumLineNotes.members[i].alpha = 0.2; // Shadow alpha for inactive focus
			}
		}

		FlxG.mouse.visible = true; // cause reasons. trust me
		camPos.y = strumLine.y;

		var camSpeed:Float = 1000; // Base camera scroll speed (pixels per second)

		// Turbo camera scroll speed if SHIFT is pressed
		if (FlxG.keys.pressed.SHIFT)
		{
			camSpeed *= 3;
		}

		// Sprawdzamy stan klawiszy w locie (Linear Panning)
		if (FlxG.keys.pressed.J)
		{
			camPos.x -= camSpeed * elapsed;
		}
		if (FlxG.keys.pressed.L)
		{
			camPos.x += camSpeed * elapsed;
		}

		if (camPos.x < gridBG.x)
			camPos.x = gridBG.x;
		if (camPos.x > gridBG.x + gridBG.width)
			camPos.x = gridBG.x + gridBG.width;

		if (!disableAutoScrolling.checked)
		{
			if (Math.ceil(strumLine.y) >= gridBG.height)
			{
				if (_song.notes[curSec + 1] == null)
				{
					addSection();
				}

				changeSection(curSec + 1, false);
			}
			else if (strumLine.y < -10)
			{
				changeSection(curSec - 1, false);
			}
		}
		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
			{
				var gridmult = GRID_SIZE / (quantization / 16);
				dummyArrow.y = Math.floor(FlxG.mouse.y / gridmult) * gridmult;
			}
		}
		else
		{
			dummyArrow.visible = false;
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn)
		{
			if (inputText.hasFocus)
			{
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;
				break;
			}
		}

		if (!blockInput)
		{
			for (stepper in blockPressWhileTypingOnStepper)
			{
				@:privateAccess
				var leText:Dynamic = stepper.text_field;
				var leText:FlxUIInputText = leText;
				if (leText.hasFocus)
				{
					FlxG.sound.muteKeys = [];
					FlxG.sound.volumeDownKeys = [];
					FlxG.sound.volumeUpKeys = [];
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			for (dropDownMenu in blockPressWhileScrolling)
			{
				if (dropDownMenu != null && dropDownMenu.dropPanel != null && dropDownMenu.dropPanel.visible)
				{
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.ESCAPE)
			{
				autosaveSong();
				LoadingState.loadAndSwitchState(new editors.EditorPlayState(sectionStartTime()));
			}
			if (FlxG.keys.justPressed.ENTER)
			{
				autosaveSong();
				FlxG.mouse.visible = false;
				PlayState.chartingMode = true;
				PlayState.editorPlaybackRate = playtestPlaybackSpeed;
				PlayState.startOnTime = 0; // Tymczasowo hardcodowane na 0, dopóki nie dodamy checkboxa
				PlayState.SONG = _song;
				FlxG.sound.music.stop();
				if (vocals != null)
					vocals.stop();

				// if(_song.stage == null) _song.stage = stageDropDown.selectedLabel;
				StageData.loadDirectory(_song);
				LoadingState.loadAndSwitchState(new PlayState());
			}

			if (curSelectedNote != null && curSelectedNote[1] > -1)
			{
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}

			if (FlxG.keys.justPressed.BACKSPACE)
			{
				PlayState.chartingMode = false;
				MusicBeatState.switchState(new editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				FlxG.mouse.visible = false;
				return;
			}

			if (FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL)
			{
				undo();
			}

			if (FlxG.keys.justPressed.C && FlxG.keys.pressed.CONTROL)
			{
				if (selectedNotes.length > 0)
				{
					clipboardNotes = [];
					var earliestTime:Float = Math.POSITIVE_INFINITY;
					for (note in selectedNotes) {
						if (note[0] < earliestTime) earliestTime = note[0];
					}
					for (note in selectedNotes) {
						var copyNote:Array<Dynamic> = [note[0] - earliestTime, note[1], note[2], note[3]];
						clipboardNotes.push(copyNote);
					}
					FlxG.log.add('Copied ' + clipboardNotes.length + ' notes.');
				}
				else if (curSelectedNote != null)
				{
					clipboardNotes = [[0, curSelectedNote[1], curSelectedNote[2], curSelectedNote[3]]];
					FlxG.log.add('Copied 1 note.');
				}
			}

			if (FlxG.keys.justPressed.X && FlxG.keys.pressed.CONTROL)
			{
				pushUndoSnapshot();
				if (selectedNotes.length > 0)
				{
					clipboardNotes = [];
					var earliestTime:Float = Math.POSITIVE_INFINITY;
					for (note in selectedNotes) {
						if (note[0] < earliestTime) earliestTime = note[0];
					}
					for (note in selectedNotes) {
						var copyNote:Array<Dynamic> = [note[0] - earliestTime, note[1], note[2], note[3]];
						clipboardNotes.push(copyNote);
					}
					for (note in selectedNotes) {
						var sectionData:Array<Array<Dynamic>> = cast getNotes();
						for (sec in sectionData) sec.remove(note);
					}
					selectedNotes = [];
					updateGrid();
					autosaveSong();
				}
				else if (curSelectedNote != null)
				{
					clipboardNotes = [[0, curSelectedNote[1], curSelectedNote[2], curSelectedNote[3]]];
					var sectionData:Array<Array<Dynamic>> = cast getNotes();
					for (sec in sectionData) sec.remove(curSelectedNote);
					curSelectedNote = null;
					updateGrid();
					autosaveSong();
				}
			}

			if (FlxG.keys.justPressed.V && FlxG.keys.pressed.CONTROL)
			{
				if (clipboardNotes.length > 0)
				{
					pushUndoSnapshot();
					var stepCrochet = Conductor.stepCrochet;
					var playheadTime = Math.round(FlxG.sound.music.time / stepCrochet) * stepCrochet;

					var uniqueIDs = new Array<Int>();
					for (note in clipboardNotes) {
						var id = Std.int(note[1] / 4);
						if (!uniqueIDs.contains(id)) uniqueIDs.push(id);
					}

					var targetID = -1;
					if (uniqueIDs.length == 1) {
						var secDynamic:Dynamic = _song.notes[curSec];
						targetID = (secDynamic != null && secDynamic.camFocus != null) ? secDynamic.camFocus : 0;
					}

					for (note in clipboardNotes)
					{
						var newTime = playheadTime + note[0];
						var newCol:Int = note[1];
						
						if (targetID != -1) {
							var dir = newCol % 4;
							newCol = (targetID * 4) + dir;
						}
						
						var newNote:Array<Dynamic> = [newTime, newCol, note[2], note[3]];
						
						var targetSec = Math.floor(newTime / (stepCrochet * 16));
						if (targetSec < 0) targetSec = 0;
						while (_song.notes.length <= targetSec) {
							_song.notes.push({
								sectionNotes: [],
								sectionBeats: 4,
								typeOfSection: 0,
								mustHitSection: false,
								gfSection: false,
								bpm: _song.bpm,
								changeBPM: false,
								altAnim: false
							});
						}
						_song.notes[targetSec].sectionNotes.push(newNote);
					}
					updateGrid();
					autosaveSong();
				}
			}

			if (FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL)
			{
				--curZoom;
				updateZoom();
			}
			if (FlxG.keys.justPressed.X && curZoom < zoomList.length - 1 && !FlxG.keys.pressed.CONTROL)
			{
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					UI_box.selected_tab -= 1;
					if (UI_box.selected_tab < 0)
						UI_box.selected_tab = 2;
				}
				else
				{
					UI_box.selected_tab += 1;
					if (UI_box.selected_tab >= 3)
						UI_box.selected_tab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if (vocals != null)
						vocals.pause();
				}
				else
				{
					if (vocals != null)
					{
						vocals.play();
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
						vocals.play();
					}
					FlxG.sound.music.play();
				}
			}

			if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (charactersCam != null && UI_box != null && charactersScrollContainer != null)
			{
				var isCharTab:Bool = (UI_box.selected_tab_id == "Characters");
				charactersCam.visible = isCharTab;
				charactersScrollContainer.visible = isCharTab;
				charactersScrollContainer.active = isCharTab;

				if (isCharTab)
				{
					var targetX:Float = UI_box.x + 10;
					var targetY:Float = UI_box.y + 35;

					// Smooth interpolation for premium UI feel (frame-rate independent)
					var lerpVal:Float = Math.max(0, Math.min(1, elapsed * 15));
					charactersCam.x = Std.int(charactersCam.x + (targetX - charactersCam.x) * lerpVal);
					charactersCam.y = Std.int(charactersCam.y + (targetY - charactersCam.y) * lerpVal);
				}
			}

			if (FlxG.mouse.wheel != 0)
			{
				var mouseOverUI:Bool = (FlxG.mouse.screenX >= UI_box.x
					&& FlxG.mouse.screenX <= UI_box.x + UI_box.width
					&& FlxG.mouse.screenY >= UI_box.y
					&& FlxG.mouse.screenY <= UI_box.y + UI_box.height);

				if (UI_box.selected_tab_id == "Characters" && mouseOverUI)
				{
					charactersScrollY += FlxG.mouse.wheel * 45;
					if (charactersScrollY > 0)
						charactersScrollY = 0;

					var songDynamic:Dynamic = _song;
					var totalExtra:Int = (songDynamic.extraChars != null ? cast(songDynamic.extraChars, Array<Dynamic>).length : 0);
					var minScroll = -Math.max(0, ((3 * 115) + (totalExtra * 165) + 70) - 340);

					if (charactersScrollY < minScroll)
						charactersScrollY = minScroll;
					charactersScrollContainer.y = charactersScrollY;
				}
				else
				{
					FlxG.sound.music.pause();
					if (!mouseQuant)
						FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.8);
					else
					{
						var time:Float = FlxG.sound.music.time;
						var beat:Float = curDecBeat;
						var snap:Float = quantization / 4;
						var increase:Float = 1 / snap;
						if (FlxG.mouse.wheel > 0)
						{
							var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}
						else
						{
							var fuck:Float = CoolUtil.quantize(beat, snap) + increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}
					}
					if (vocals != null)
					{
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
					}
				}
			}

			// ARROW VORTEX SHIT NO DEADASS

			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL)
					holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT)
					holdingShift = 4;

				var daTime:Float = 700 * FlxG.elapsed * holdingShift;

				if (FlxG.keys.pressed.W)
				{
					FlxG.sound.music.time -= daTime;
				}
				else
					FlxG.sound.music.time += daTime;

				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
			}

			if (!vortex)
			{
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();
					updateCurStep();
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase; // (Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
					else
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; // (Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
				}
			}

			var style = currentType;

			if (FlxG.keys.pressed.SHIFT)
			{
				style = 3;
			}

			var conductorTime = Conductor.songPosition; // + sectionStartTime();Conductor.songPosition / Conductor.stepCrochet;

			// AWW YOU MADE IT SEXY <3333 THX SHADMAR

			if (!blockInput)
			{
				if (FlxG.keys.justPressed.RIGHT)
				{
					curQuant++;
					if (curQuant > quantizations.length - 1)
						curQuant = 0;

					quantization = quantizations[curQuant];
				}

				if (FlxG.keys.justPressed.LEFT)
				{
					curQuant--;
					if (curQuant < 0)
						curQuant = quantizations.length - 1;

					quantization = quantizations[curQuant];
				}
				quant.animation.play('q', true, false, curQuant);
			}
			if (vortex && !blockInput)
			{
				var controlArray:Array<Bool> = [
					 FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
					FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT
				];

				if (controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if (controlArray[i])
							doANoteThing(conductorTime, i, style);
					}
				}

				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();

					updateCurStep();
					// FlxG.sound.music.time = (Math.round(curStep/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;

					// (Math.floor((curStep+quants[curQuant]*1.5/(quants[curQuant]/2))/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;//snap into quantization
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
						feces = Conductor.beatToSeconds(fuck);
					}
					else
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; // (Math.floor((beat+snap) / snap) * snap);
						feces = Conductor.beatToSeconds(fuck);
					}
					FlxTween.tween(FlxG.sound.music, {time: feces}, 0.1, {ease: FlxEase.circOut});
					if (vocals != null)
					{
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
					}

					var dastrum = 0;

					if (curSelectedNote != null)
					{
						dastrum = curSelectedNote[0];
					}

					var secStart:Float = sectionStartTime();
					var datime = (feces - secStart) - (dastrum - secStart); // idk math find out why it doesn't work on any other section other than 0
					if (curSelectedNote != null)
					{
						var controlArray:Array<Bool> = [
							 FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
							FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT
						];

						if (controlArray.contains(true))
						{
							for (i in 0...controlArray.length)
							{
								if (controlArray[i])
									if (curSelectedNote[1] == i)
										curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;
							}
							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;

			if (FlxG.keys.justPressed.D)
				changeSection(curSec + shiftThing);
			if (FlxG.keys.justPressed.A)
			{
				if (curSec <= 0)
				{
					changeSection(_song.notes.length - 1);
				}
				else
				{
					changeSection(curSec - shiftThing);
				}
			}
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			for (i in 0...blockPressWhileTypingOn.length)
			{
				if (blockPressWhileTypingOn[i].hasFocus)
				{
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		_song.bpm = tempBpm;

		strumLineNotes.visible = quant.visible = eventPlayheadArrow.visible = vortex;

		if (FlxG.sound.music.time < 0)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		strumLineUpdateY();
		camPos.y = strumLine.y;
		for (i in 0...strumLineNotes.length)
		{
			strumLineNotes.members[i].y = strumLine.y;
			var charID:Int = Std.int(i / 4);
			if (charID == focusID)
			{
				strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
			}
			else
			{
				strumLineNotes.members[i].alpha = 0.2;
			}
		}

		// PLAYBACK SPEED CONTROLS //
		var holdingShift = FlxG.keys.pressed.SHIFT;
		var holdingLB = FlxG.keys.pressed.LBRACKET;
		var holdingRB = FlxG.keys.pressed.RBRACKET;
		var pressedLB = FlxG.keys.justPressed.LBRACKET;
		var pressedRB = FlxG.keys.justPressed.RBRACKET;

		var speedChanged:Bool = false;
		if (!holdingShift && pressedLB || holdingShift && holdingLB)
		{
			playbackSpeed -= 0.01;
			speedChanged = true;
		}
		if (!holdingShift && pressedRB || holdingShift && holdingRB)
		{
			playbackSpeed += 0.01;
			speedChanged = true;
		}
		if (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB))
		{
			playbackSpeed = 1;
			speedChanged = true;
		}
		//

		if (playbackSpeed <= 0.5)
			playbackSpeed = 0.5;
		if (playbackSpeed >= 3)
			playbackSpeed = 3;

		if (speedChanged && sliderRate != null)
		{
			sliderRate.value = playbackSpeed;
		}

		FlxG.sound.music.pitch = playbackSpeed;
		vocals.pitch = playbackSpeed;

		bpmTxt.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
			+ " / "
			+ Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))
			+ "\nSection: "
			+ curSec
			+ "\n\nBeat: "
			+ Std.string(curDecBeat).substring(0, 4)
			+ "\n\nStep: "
			+ curStep
			+ "\n\nBeat Snap: "
			+ quantization
			+ "th";

		var playedSound:Array<Bool> = [false, false, false, false]; // Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive(function(note:Note)
		{
			note.alpha = 1;
			var isSelected = false;
			if (curSelectedNote != null)
			{
				var noteDataToCheck:Int = note.ID;

				if (curSelectedNote[0] == note.strumTime
					&& ((curSelectedNote[2] == null && noteDataToCheck < 0)
						|| (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
				{
					isSelected = true;
				}
			}
			
			if (!isSelected && selectedNotes != null && selectedNotes.length > 0)
			{
				for (sNote in selectedNotes) {
					if (sNote[0] == note.strumTime && sNote[1] == note.ID) {
						isSelected = true;
						break;
					}
				}
			}

			if (isSelected) {
				colorSine += elapsed;
				var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
				note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999);
			}

			if (note.strumTime <= Conductor.songPosition)
			{
				note.alpha = 0.4;
				if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1)
				{
					var data:Int = note.noteData % 4;
					var noteDataToCheck:Int = note.ID;
					if (noteDataToCheck > -1)
					{
						strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
						strumLineNotes.members[noteDataToCheck].resetAnim = (note.sustainLength / 1000) + 0.15;
					}

					// Oaza Visual Characters Trigger:
					if (showVisualChars != null && showVisualChars.checked)
					{
						var dirAnims:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
						var isBf:Bool = note.mustPress;
						var animName:String = dirAnims[data];
						playVisualAnim(isBf, animName.toLowerCase());
						if (isBf)
						{
							bfSungInSection = true;
						}
						else
						{
							dadSungInSection = true;
						}
					}
					if (!playedSound[data])
					{
						if ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress))
						{
							var soundToPlay = 'hitsound';
							if (_song.player1 == 'gf')
							{ // Easter egg
								soundToPlay = 'GF_' + Std.string(data + 1);
							}

							var sound = FlxG.sound.play(Paths.sound(soundToPlay));
							if (sound != null)
							{
								sound.pan = !note.mustPress ? -0.3 : 0.3;
								sound.pitch = 1.0;
							}
							playedSound[data] = true;
						}
					}
				}
			}
		});

		if (metronome.checked && lastConductorPos != Conductor.songPosition)
		{
			var currentBpm:Float = Conductor.bpm;
			var metroInterval:Float = 60 / currentBpm;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if (metroStep != lastMetroStep)
			{
				var sound = FlxG.sound.play(Paths.sound('Metronome_Tick'));
				if (sound != null)
				{
					sound.pitch = 1.0;
				}
			}
		}
		lastConductorPos = Conductor.songPosition;

		if (FlxG.mouse.justPressed)
		{
			var blockNoteClick:Bool = false;

			if (charIcons != null)
			{
				for (i in 0...charIcons.length)
				{
					var targetCam = (charIcons[i].camera != null) ? charIcons[i].camera : FlxG.camera;
					if (FlxG.mouse.overlaps(charIcons[i], targetCam))
					{
						var secDynamic:Dynamic = _song.notes[curSec];
						if (secDynamic != null)
						{
							secDynamic.camFocus = i; // Zapisujemy nowe Focus ID postaci
							_song.notes[curSec].mustHitSection = (i == 1);
							updateGrid();
							updateSectionUI();
						}
						blockNoteClick = true;
						break;
					}
				}
			}

			var mouseOverUI:Bool = (FlxG.mouse.screenX >= UI_box.x
				&& FlxG.mouse.screenX <= UI_box.x + UI_box.width
				&& FlxG.mouse.screenY >= UI_box.y
				&& FlxG.mouse.screenY <= UI_box.y + UI_box.height);

			if (charactersCam != null && UI_box != null && charactersScrollContainer != null)
			{
				var isCharTab:Bool = (UI_box.selected_tab_id == "Characters");
				charactersCam.visible = isCharTab;
				charactersScrollContainer.visible = isCharTab;
				charactersScrollContainer.active = isCharTab;

				if (isCharTab)
				{
					charactersCam.x = Std.int(UI_box.x + 10);
					charactersCam.y = Std.int(UI_box.y + 35);
				}
			}

			for (item in charactersInputTexts)
			{
				if (item.input != null)
				{
					if (item.isArrowSkin == true)
					{
						_song.arrowSkin = item.input.text;
					}
					else
					{
						item.data.noteSkin = item.input.text;
					}
				}
				if (item.stepper != null && item.field != null)
				{
					Reflect.setField(item.data, item.field, item.stepper.value);
				}
			}

			if (!blockNoteClick
				&& FlxG.mouse.screenX >= UI_box.x
				&& FlxG.mouse.screenX <= UI_box.x + UI_box.width
				&& FlxG.mouse.screenY >= UI_box.y
				&& FlxG.mouse.screenY <= UI_box.y + UI_box.height)
			{
				blockNoteClick = true;
			}

			if (!blockNoteClick
				&& FlxG.mouse.screenX >= UI_box.x
				&& FlxG.mouse.screenX <= UI_box.x + UI_box.width
				&& FlxG.mouse.screenY >= UI_box.y
				&& FlxG.mouse.screenY <= UI_box.y + UI_box.height)
			{
				blockNoteClick = true;
			}

			if (!blockNoteClick)
			{
				for (dropDownMenu in blockPressWhileScrolling)
				{
					if (dropDownMenu != null
						&& dropDownMenu.dropPanel != null
						&& dropDownMenu.dropPanel.visible
						&& FlxG.mouse.overlaps(dropDownMenu.dropPanel))
					{
						blockNoteClick = true;
						break;
					}
				}
			}

			if (!blockNoteClick)
			{
				var clickedNote:Bool = false;
				var checkNoteClick = function(note:Note)
				{
					if (FlxG.mouse.overlaps(note) && !clickedNote)
					{
						clickedNote = true;
						
						var noteDataRef:Array<Dynamic> = null;
						if (note.noteData > -1) {
							var sectionData:Array<Array<Dynamic>> = cast getNotes();
							for (sec in sectionData) {
								for (i in sec) {
									if (i.length > 2 && i[0] == note.strumTime && i[1] == note.ID) {
										noteDataRef = i;
										break;
									}
								}
								if (noteDataRef != null) break;
							}
						}

						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
							if (noteDataRef != null) {
								if (selectedNotes.contains(noteDataRef))
									selectedNotes.remove(noteDataRef);
								else
									selectedNotes.push(noteDataRef);
							}
						}
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note);
							if (noteDataRef != null) {
								pushUndoSnapshot();
								if (!selectedNotes.contains(noteDataRef)) selectedNotes.push(noteDataRef);
								for (sn in selectedNotes) sn[3] = noteTypeIntMap.get(currentType);
								updateGrid();
							}
						}
						else
						{
							selectNote(note);
							if (noteDataRef != null) {
								pushUndoSnapshot();
								clickedNoteRef = noteDataRef;
								if (!selectedNotes.contains(noteDataRef))
								{
									if (!FlxG.keys.pressed.SHIFT)
										selectedNotes = [noteDataRef];
									else
										selectedNotes.push(noteDataRef);
								}
								
								dragInitialNotes = [];
								for (sn in selectedNotes)
								{
									dragInitialNotes.push({note: sn, origTime: sn[0], origCol: sn[1]});
								}
								
								dragStartPoint.set(FlxG.mouse.x, FlxG.mouse.y);
								dragStartVisualCol = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) - 1;
								dragStartTime = getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false) + sectionStartTime();
								isDraggingNotes = true;
							}
						}
					}
				};
				curRenderedNotes.forEachAlive(checkNoteClick);
				nextRenderedNotes.forEachAlive(checkNoteClick);

				if (!clickedNote)
				{
					if (FlxG.mouse.x > gridBG.x
						&& FlxG.mouse.x < gridBG.x + gridBG.width
						&& FlxG.mouse.y > gridBG.y
						&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectionStart = FlxG.mouse.getWorldPosition();
							selectionBox.visible = true;
							selectionBox.setPosition(selectionStart.x, selectionStart.y);
							selectionBox.setGraphicSize(1, 1);
							selectionBox.updateHitbox();
						}
						else
						{
							FlxG.log.add('added note');
							addNote();
						}
					}
					else if (!FlxG.keys.pressed.CONTROL)
					{
						selectedNotes = [];
						curSelectedNote = null;
					}
				}
			}
		}

		if (FlxG.mouse.pressed)
		{
			if (selectionBox.visible && selectionStart != null)
			{
				var currentMouse = FlxG.mouse.getWorldPosition();
				var left = Math.min(selectionStart.x, currentMouse.x);
				var top = Math.min(selectionStart.y, currentMouse.y);
				var right = Math.max(selectionStart.x, currentMouse.x);
				var bottom = Math.max(selectionStart.y, currentMouse.y);
				
				selectionBox.setPosition(left, top);
				selectionBox.setGraphicSize(Std.int(right - left), Std.int(bottom - top));
				selectionBox.updateHitbox();
			}
			else if (isDraggingNotes && dragInitialNotes.length > 0)
			{
				var dist = Math.abs(FlxG.mouse.x - dragStartPoint.x) + Math.abs(FlxG.mouse.y - dragStartPoint.y);
				if (dist >= 4)
				{
					var currentVisualCol = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) - 1;
					var currentSnappedTime = getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false) + sectionStartTime();
					if (FlxG.keys.pressed.SHIFT)
					{
						var relativeY = FlxG.mouse.y - gridBG.y;
						var totalGridHeight = GRID_SIZE * getSectionBeats() * 4 * zoomList[curZoom];
						currentSnappedTime = (relativeY / totalGridHeight) * (getSectionBeats() * 4 * Conductor.stepCrochet) + sectionStartTime();
					}
					
					var deltaVisualCol = currentVisualCol - dragStartVisualCol;
					var deltaTime = currentSnappedTime - dragStartTime;
					
					var changed:Bool = false;
					for (d in dragInitialNotes)
					{
						var newTime = Math.max(0, d.origTime + deltaTime);
						var origVis = logicalToVisualColumn(d.origCol);
						var newVis = origVis + deltaVisualCol;
						if (newVis >= 0 && newVis < getAmountOfColumns())
						{
							var newLogCol = visualToLogicalColumn(newVis);
							if (d.note[0] != newTime || d.note[1] != newLogCol)
							{
								d.note[0] = newTime;
								d.note[1] = newLogCol;
								changed = true;
							}
						}
					}
					if (changed)
					{
						updateGrid();
					}
				}
			}
		}

		if (FlxG.mouse.justReleased)
		{
			if (selectionBox.visible)
			{
				selectionBox.visible = false;

				var checkBoxSelection = function(note:Note)
				{
					if (FlxG.overlap(selectionBox, note))
					{
						if (note.noteData > -1) {
							var sectionData:Array<Array<Dynamic>> = cast getNotes();
							for (sec in sectionData) {
								for (i in sec) {
									if (i.length > 2 && i[0] == note.strumTime && i[1] == note.ID) {
										if (!selectedNotes.contains(i)) selectedNotes.push(i);
									}
								}
							}
						}
					}
				};
				curRenderedNotes.forEachAlive(checkBoxSelection);
				nextRenderedNotes.forEachAlive(checkBoxSelection);
			}
			else if (isDraggingNotes)
			{
				var dist = Math.abs(FlxG.mouse.x - dragStartPoint.x) + Math.abs(FlxG.mouse.y - dragStartPoint.y);
				if (dist < 4 && clickedNoteRef != null)
				{
					for (sec in _song.notes)
					{
						sec.sectionNotes.remove(clickedNoteRef);
					}
					selectedNotes.remove(clickedNoteRef);
					if (curSelectedNote == clickedNoteRef) curSelectedNote = null;
					updateGrid();
				}
				else if (dist >= 4)
				{
					resortNotes();
					updateGrid();
					autosaveSong();
				}
				isDraggingNotes = false;
				clickedNoteRef = null;
				dragInitialNotes = [];
			}
		}
		
		super.update(elapsed);
	}

	function updateZoom()
	{
		var daZoom:Float = zoomList[curZoom];
		var zoomThing:String = '1 / ' + daZoom;
		if (daZoom < 1)
			zoomThing = Math.round(1 / daZoom) + ' / 1';
		zoomTxt.text = 'Zoom: ' + zoomThing;
		reloadGridLayer();
	}

	/*
		function loadAudioBuffer() {
			if(audioBuffers[0] != null) {
				audioBuffers[0].dispose();
			}
			audioBuffers[0] = null;
			#if MODS_ALLOWED
			if(FileSystem.exists(Paths.modFolders('songs/' + currentSongName + '/Inst.ogg'))) {
				audioBuffers[0] = AudioBuffer.fromFile(Paths.modFolders('songs/' + currentSongName + '/Inst.ogg'));
				//trace('Custom vocals found');
			}
			else { #end
				var leVocals:String = Paths.getPath(currentSongName + '/Inst.' + Paths.SOUND_EXT, SOUND, 'songs');
				if (OpenFlAssets.exists(leVocals)) { //Vanilla inst
					audioBuffers[0] = AudioBuffer.fromFile('./' + leVocals.substr(6));
					//trace('Inst found');
				}
			#if MODS_ALLOWED
			}
			#end

			if(audioBuffers[1] != null) {
				audioBuffers[1].dispose();
			}
			audioBuffers[1] = null;
			#if MODS_ALLOWED
			if(FileSystem.exists(Paths.modFolders('songs/' + currentSongName + '/Voices.ogg'))) {
				audioBuffers[1] = AudioBuffer.fromFile(Paths.modFolders('songs/' + currentSongName + '/Voices.ogg'));
				//trace('Custom vocals found');
			} else { #end
				var leVocals:String = Paths.getPath(currentSongName + '/Voices.' + Paths.SOUND_EXT, SOUND, 'songs');
				if (OpenFlAssets.exists(leVocals)) { //Vanilla voices
					audioBuffers[1] = AudioBuffer.fromFile('./' + leVocals.substr(6));
					//trace('Voices found, LETS FUCKING GOOOO');
				}
			#if MODS_ALLOWED
			}
			#end
		}
	 */
	var lastSecBeats:Float = 0;
	var lastSecBeatsNext:Float = 0;

	function reloadGridLayer()
	{
		gridLayer.forEach(function(spr)
		{
			spr.destroy();
		});
		gridLayer.clear();

		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (1 + getAmountOfColumns()),
			Std.int(GRID_SIZE * getSectionBeats() * 4 * zoomList[curZoom]));

		var leHeight:Int = Std.int(gridBG.height);
		var foundNextSec:Bool = false;
		if (sectionStartTime(1) <= FlxG.sound.music.length)
		{
			nextGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (getAmountOfColumns() + 1),
				Std.int(GRID_SIZE * getSectionBeats(curSec + 1) * 4 * zoomList[curZoom]));
			leHeight = Std.int(gridBG.height + nextGridBG.height);
			foundNextSec = true;
		}
		else
			nextGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		nextGridBG.y = gridBG.height;

		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);
		if (foundNextSec)
		{
			var gridBlack:FlxSprite = new FlxSprite(0,
				gridBG.height).makeGraphic(Std.int(GRID_SIZE * (getAmountOfColumns() + 1)), Std.int(nextGridBG.height), FlxColor.BLACK);
			gridBlack.alpha = 0.4;
			gridLayer.add(gridBlack);
		}

		// AUTOMATYCZNE SEPARATORY POSTACI
		for (charNum in 1...Std.int(getAmountOfColumns() / 4))
		{
			var separator:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE + (GRID_SIZE * 4 * charNum)).makeGraphic(2, leHeight, FlxColor.BLACK);
			gridLayer.add(separator);
		}


		var secBeats:Int = Std.int(getSectionBeats());
		var beatHeight:Float = GRID_SIZE * 4 * zoomList[curZoom];
		for (i in 1...secBeats)
		{
			var beatsep1:FlxSprite = new FlxSprite(gridBG.x, beatHeight * i).makeGraphic(Std.int(gridBG.width), 1, 0x44FF0000);
			if (vortex)
			{
				gridLayer.add(beatsep1);
			}
		}

		var gridBlackLineFirst:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(2, leHeight, FlxColor.BLACK);
		gridLayer.add(gridBlackLineFirst);

		strumlineDarkens = [];
		var totalCharsForDarkens = Std.int(getAmountOfColumns() / 4);
		for (charNum in 0...totalCharsForDarkens)
		{
			var visualSlot = Std.int(logicalToVisualColumn(charNum * 4) / 4);
			var dark:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE + (GRID_SIZE * 4 * visualSlot), 0).makeGraphic(GRID_SIZE * 4, leHeight, FlxColor.BLACK);
			dark.alpha = 0;
			gridLayer.add(dark);
			strumlineDarkens.push(dark);
		}

		updateGrid();

		lastSecBeats = getSectionBeats();
		if (sectionStartTime(1) > FlxG.sound.music.length)
			lastSecBeatsNext = 0;
		else
			getSectionBeats(curSec + 1);
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);

		if (charIcons != null)
		{
			var usePlayhead:Bool = FlxG.save.data.chart_showFocusIcon;
			for (i in 0...charIcons.length)
			{
				if (charIcons[i] != null)
				{
					if (usePlayhead)
					{
						charIcons[i].y = strumLine.y - charIcons[i].height - 10;
					}
					else
					{
						charIcons[i].y = -50;
					}
				}
			}

			if (eventIcon != null)
			{
				var focusID:Int = 0;
				if (curSec < _song.notes.length && _song.notes[curSec] != null)
				{
					focusID = getSectionCamFocus(_song.notes[curSec]);
				}
				if (charIcons.length > focusID && focusID >= 0 && charIcons[focusID] != null)
				{
					var icon = charIcons[focusID];
					eventIcon.x = icon.x + (icon.width / 2) - (eventIcon.width / 2);
					eventIcon.y = icon.y - eventIcon.height - 5;
					eventIcon.visible = true;
				}
				else
				{
					eventIcon.visible = false;
				}
			}
		}

		if (eventPlayheadArrow != null)
		{
			eventPlayheadArrow.x = 0;
			if (FlxG.save.data.chart_showFocusIcon)
			{
				eventPlayheadArrow.y = strumLine.y - eventPlayheadArrow.height - 10;
			}
			else
			{
				eventPlayheadArrow.y = -50;
			}
		}
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];

	var instBuffer:lime.media.AudioBuffer = null;
	var instBytes:haxe.io.Bytes = null;
	var voicesBuffer:lime.media.AudioBuffer = null;
	var voicesBytes:haxe.io.Bytes = null;

	function getSongSoundPath(soundName:String):String
	{
		var songKey:String = Paths.formatToSongPath(currentSongName) + '/' + soundName;
		#if MODS_ALLOWED
		var file:String = Paths.modsSounds('songs', songKey);
		if (sys.FileSystem.exists(file))
		{
			return file;
		}
		#end
		var gottenPath:String = Paths.getPath('songs/' + songKey + '.' + Paths.SOUND_EXT, SOUND);
		var idx = gottenPath.indexOf(':');
		if (idx != -1)
			gottenPath = gottenPath.substring(idx + 1);
		if (sys.FileSystem.exists('./' + gottenPath))
		{
			return './' + gottenPath;
		}
		if (sys.FileSystem.exists(gottenPath))
		{
			return gottenPath;
		}
		return gottenPath;
	}

	function updateWaveform()
	{
		#if desktop
		if (waveformPrinted)
		{
			waveformSprite.makeGraphic(Std.int(GRID_SIZE * 8), Std.int(gridBG.height), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridBG.height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if (!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices)
		{
			// trace('Epic fail on the waveform lol');
			return;
		}

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		var steps:Int = Math.round(getSectionBeats() * 4);
		var st:Float = sectionStartTime();
		var et:Float = st + (Conductor.stepCrochet * steps);

		if (FlxG.save.data.chart_waveformInst)
		{
			if (instBuffer == null)
			{
				var path:String = getSongSoundPath('Inst');
				if (sys.FileSystem.exists(path))
				{
					instBuffer = lime.media.AudioBuffer.fromFile(path);
					if (instBuffer != null && instBuffer.data != null)
					{
						instBytes = instBuffer.data.toBytes();
					}
				}
			}
			if (instBuffer != null && instBytes != null)
			{
				wavData = waveformData(instBuffer, instBytes, st, et, 1, wavData, Std.int(gridBG.height));
			}
		}

		if (FlxG.save.data.chart_waveformVoices)
		{
			if (voicesBuffer == null)
			{
				var path:String = getSongSoundPath('Voices');
				if (sys.FileSystem.exists(path))
				{
					voicesBuffer = lime.media.AudioBuffer.fromFile(path);
					if (voicesBuffer != null && voicesBuffer.data != null)
					{
						voicesBytes = voicesBuffer.data.toBytes();
					}
				}
			}
			if (voicesBuffer != null && voicesBytes != null)
			{
				wavData = waveformData(voicesBuffer, voicesBytes, st, et, 1, wavData, Std.int(gridBG.height));
			}
		}

		// Draws
		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize / 2);

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var size:Float = 1;

		var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);

		var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		var index:Int;
		for (i in 0...length)
		{
			index = i;

			lmin = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			lmax = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			rmin = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			rmax = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>,
			?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null)
			return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null)
			steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true; // samples > 17200;
		var v1:Bool = false;

		if (array == null)
			array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1))
		{
			if (index >= 0)
			{
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2)
					byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0)
				{
					if (sample > lmax)
						lmax = sample;
				}
				else if (sample < 0)
				{
					if (sample < lmin)
						lmin = sample;
				}

				if (channels >= 2)
				{
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2)
						byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0)
					{
						if (sample > rmax)
							rmax = sample;
					}
					else if (sample < 0)
					{
						if (sample < rmin)
							rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow)
			{
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length)
					array[0][0].push(lRMin);
				else
					array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length)
					array[0][1].push(lRMax);
				else
					array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2)
				{
					if (gotIndex > array[1][0].length)
						array[1][0].push(rRMin);
					else
						array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length)
						array[1][1].push(rRMax);
					else
						array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else
				{
					if (gotIndex > array[1][0].length)
						array[1][0].push(lRMin);
					else
						array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length)
						array[1][1].push(lRMax);
					else
						array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if (gotIndex > steps)
				break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function changeNoteSustain(value:Float):Void
	{
		pushUndoSnapshot();
		if (selectedNotes != null && selectedNotes.length > 0)
		{
			for (note in selectedNotes)
			{
				if (note[2] != null)
				{
					note[2] += value;
					note[2] = Math.max(note[2], 0);
				}
			}
		}
		else if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += value;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}
		updateNoteUI();
		updateGrid();
	}

	function recalculateSteps(add:Float = 0):Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime + add) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSec = 0;
		}

		if (vocals != null)
		{
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}
		updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		if (_song.notes[sec] != null)
		{
			curSec = sec;
			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = sectionStartTime();
				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				updateCurStep();
			}

			var blah1:Float = getSectionBeats();
			var blah2:Float = getSectionBeats(curSec + 1);
			if (sectionStartTime(1) > FlxG.sound.music.length)
				blah2 = 0;

			if (blah1 != lastSecBeats || blah2 != lastSecBeatsNext)
			{
				reloadGridLayer();
			}
			else
			{
				updateGrid();
			}
			updateSectionUI();
			repairCurrentSection();
		}
		else
		{
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		updateWaveform();

		if (showVisualChars != null && showVisualChars.checked)
		{
			bfSungInSection = false;
			dadSungInSection = false;
			playVisualAnim(false, 'idle');
			playVisualAnim(true, 'idle');
		}
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSec];

		stepperBeats.value = getSectionBeats();
		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;
		var currentFocusID:Int = getSectionCamFocus(sec);
		if (stepperCamFocus != null)
		{
			stepperCamFocus.value = currentFocusID;
		}

		if (strumlineDarkens != null)
		{
			for (i in 0...strumlineDarkens.length)
			{
				var visualSlot = Std.int(logicalToVisualColumn(i * 4) / 4);
				strumlineDarkens[i].x = gridBG.x + GRID_SIZE + (GRID_SIZE * 4 * visualSlot);

				if (i == currentFocusID)
				{
					strumlineDarkens[i].alpha = 0;
				}
				else
				{
					strumlineDarkens[i].alpha = 0.4;
				}
			}
		}

		if (strumLineNotes != null)
		{
			for (i in 0...strumLineNotes.length)
			{
				var logicalCol = i;
				strumLineNotes.members[i].x = GRID_SIZE * (logicalToVisualColumn(logicalCol) + 1);
			}
		}

		if (charIcons != null)
		{
			for (i in 0...charIcons.length)
			{
				var visualSlot = Std.int(logicalToVisualColumn(i * 4) / 4);
				charIcons[i].x = GRID_SIZE + (visualSlot * 4 * GRID_SIZE) + (4 * GRID_SIZE) / 2 - charIcons[i].width / 2;
			}
		}

		updateHeads();
	}

	function updateHeads():Void
	{
		if (charIcons == null)
			return;

		var healthIconP1:String = loadHealthIconFromCharacter(_song.player1);
		var healthIconP2:String = loadHealthIconFromCharacter(_song.player2);

		if (charIcons.length > 0)
		{
			charIcons[0].changeIcon(healthIconP2);
			charIcons[0].setGraphicSize(0, 45);
			charIcons[0].updateHitbox();
			charIcons[0].offset.set(-0.5 * (charIcons[0].width - charIcons[0].frameWidth), -0.5 * (charIcons[0].height - charIcons[0].frameHeight));
		}
		if (charIcons.length > 1)
		{
			charIcons[1].changeIcon(healthIconP1);
			charIcons[1].setGraphicSize(0, 45);
			charIcons[1].updateHitbox();
			charIcons[1].offset.set(-0.5 * (charIcons[1].width - charIcons[1].frameWidth), -0.5 * (charIcons[1].height - charIcons[1].frameHeight));
		}

		var songDynamic:Dynamic = _song;
		if (songDynamic != null && songDynamic.extraChars != null)
		{
			var extra:Array<Dynamic> = cast songDynamic.extraChars;
			for (i in 0...extra.length)
			{
				if (charIcons.length > i + 2)
				{
					var healthIconExtra:String = loadHealthIconFromCharacter(extra[i].name);
					charIcons[i + 2].changeIcon(healthIconExtra);
					charIcons[i + 2].setGraphicSize(0, 45);
					charIcons[i + 2].updateHitbox();
					charIcons[i + 2].offset.set(-0.5 * (charIcons[i + 2].width - charIcons[i + 2].frameWidth),
						-0.5 * (charIcons[i + 2].height - charIcons[i + 2].frameHeight));
				}
			}
		}

		var focusID:Int = getSectionCamFocus(_song.notes[curSec]);
		if (eventIcon != null && charIcons.length > focusID && focusID >= 0)
		{
			var icon = charIcons[focusID];
			if (icon != null)
			{
				eventIcon.x = icon.x + (icon.width / 2) - (eventIcon.width / 2);
				eventIcon.y = icon.y - eventIcon.height - 5;
				eventIcon.visible = true;
			}
		}
		else if (eventIcon != null)
		{
			eventIcon.visible = false;
		}

		if (eventPlayheadArrow != null)
		{
			eventPlayheadArrow.x = 0;
			if (FlxG.save.data.chart_showFocusIcon)
			{
				eventPlayheadArrow.y = strumLine.y - eventPlayheadArrow.height - 10;
			}
			else
			{
				eventPlayheadArrow.y = -50;
			}
		}
	}

	function loadHealthIconFromCharacter(char:String)
	{
		var characterPath:String = 'characters/' + char + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path))
		{
			path = Paths.getPreloadPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!OpenFlAssets.exists(path))
		#end
		{
			path = Paths.getPreloadPath('characters/' + Character.DEFAULT_CHARACTER +
				'.json'); // If a character couldn't be found, change him to BF just to prevent a crash
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = OpenFlAssets.getText(path);
		#end

		var json:Character.CharacterFile = cast Json.parse(rawJson);
		return json.healthicon;
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				stepperSusLength.value = curSelectedNote[2];
				if (curSelectedNote[3] != null)
				{
					currentType = noteTypeMap.get(curSelectedNote[3]);
					if (currentType <= 0)
					{
						noteTypeDropDown.selectedLabel = '';
					}
					else
					{
						noteTypeDropDown.selectedLabel = currentType + '. ' + curSelectedNote[3];
					}
				}
			}
			else
			{
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if (selected > 0 && selected < eventStuff.length)
				{
					descText.text = eventStuff[selected][1];
				}
				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
			}
			strumTimeInputText.text = '' + curSelectedNote[0];
		}
	}

	function updateGrid():Void
	{
		curRenderedNotes.forEach(function(spr)
		{
			spr.destroy();
		});
		curRenderedNotes.clear();

		curRenderedSustains.forEach(function(spr)
		{
			spr.destroy();
		});
		curRenderedSustains.clear();

		curRenderedNoteType.forEach(function(spr)
		{
			spr.destroy();
		});
		curRenderedNoteType.clear();

		nextRenderedNotes.forEach(function(spr)
		{
			spr.destroy();
		});
		nextRenderedNotes.clear();

		nextRenderedSustains.forEach(function(spr)
		{
			spr.destroy();
		});
		nextRenderedSustains.clear();

		if (_song.notes[curSec].changeBPM && _song.notes[curSec].bpm > 0)
		{
			Conductor.changeBPM(_song.notes[curSec].bpm);
			// trace('BPM of this section:');
		}
		else
		{
			// get last bpm
			var daBPM:Float = _song.bpm;
			for (i in 0...curSec)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.changeBPM(daBPM);
		}

		// CURRENT SECTION
		var beats:Float = getSectionBeats();
		for (i in _song.notes[curSec].sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note, beats));
			}

			if (i[3] != null && note.noteType != null && note.noteType.length > 0)
			{
				var typeInt:Null<Int> = noteTypeMap.get(i[3]);
				var theType:String = '' + typeInt;
				if (typeInt == null)
					theType = '?';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
			var charID:Int = Std.int(i[1] / 4);
			note.mustPress = false;
			if (charID == 1)
				note.mustPress = true;
			else
			{
				var songDynamic:Dynamic = _song;
				if (songDynamic != null && songDynamic.extraChars != null)
				{
					var extra:Array<Dynamic> = cast songDynamic.extraChars;
					if (charID >= 2 && charID - 2 < extra.length)
					{
						if (extra[charID - 2] != null && extra[charID - 2].isPlayer == true)
						{
							note.mustPress = true;
						}
					}
				}
			}
		}

		// CURRENT EVENTS
		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);

				var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: '
					+ note.eventVal2;
				if (note.eventLength > 1)
					text = note.eventLength + ' Events:\n' + note.eventName;

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -410;
				daText.borderSize = 1;
				if (note.eventLength > 1)
					daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
				// trace('test: ' + i[0], 'startThing: ' + startThing, 'endThing: ' + endThing);
			}
		}

		// NEXT SECTION
		var beats:Float = getSectionBeats(1);
		if (curSec < _song.notes.length - 1)
		{
			for (i in _song.notes[curSec + 1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note, beats));
				}
			}
		}

		// NEXT EVENTS
		var startThing:Float = sectionStartTime(1);
		var endThing:Float = sectionStartTime(2);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var daNoteInfo = i[1];
		var daStrumTime = i[0];
		var daSus:Dynamic = i[2];

		var note:Note = null;
		var logicalCol:Int = -1;

		if (daSus != null)
		{
			logicalCol = cast daNoteInfo;

			note = new Note(daStrumTime, logicalCol % 4, null, null, true);
			note.ID = logicalCol; // Nasza kotwica logiczna

			if (!Std.isOfType(i[3], String)) // Convert old note type to new note type format
			{
				i[3] = noteTypeIntMap.get(i[3]);
			}
			if (i.length > 3 && (i[3] == null || i[3].length < 1))
			{
				i.remove(i[3]);
			}
			note.sustainLength = daSus;
			note.noteType = i[3];
		}
		else
		{ // EVENT NOTE
			note = new Note(daStrumTime, 0, null, null, true);
			note.loadGraphic(Paths.image('eventArrow'));
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if (i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.noteData = -1;
			logicalCol = -1; // Kolumna eventowa na siatce Oasis (zawsze X = 0)
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();

		note.x = Math.floor(logicalToVisualColumn(logicalCol) * GRID_SIZE) + GRID_SIZE;

		var beats:Float = getSectionBeats(isNextSection ? 1 : 0);
		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime(), beats);
		if (note.y < -150)
			note.y = -150;

		return note;
	}

	function getEventName(names:Array<Dynamic>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if (addedOne)
				retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	function setupSusNote(note:Note, beats:Float):FlxSprite
	{
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, GRID_SIZE * 16 * zoomList[curZoom])
			+ (GRID_SIZE * zoomList[curZoom])
			- GRID_SIZE / 2);
		var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if (height < minHeight)
			height = minHeight;
		if (height < 1)
			height = 1; // Prevents error of invalid height

		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, height);
		return spr;
	}

	private function addSection(sectionBeats:Float = 4):Void
	{
		var sec:SwagSection = {
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		var secDynamic:Dynamic = sec;
		secDynamic.camFocus = 1; // Default to BF (ID 1) camera focus

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		if (note.noteData > -1)
		{
			var mustHit = _song.notes[curSec].mustHitSection;
			var targetRaw = (note.ID < 8 && mustHit) ? (note.ID + 4) % 8 : note.ID;

			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == note.ID)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in _song.events)
			{
				if (i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
					break;
				}
			}
		}
		changeEventSelected();
		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		pushUndoSnapshot();
		if (note.noteData > -1) // Normalne Nuty
		{
			var mustHit = _song.notes[curSec].mustHitSection;
			var targetRaw = (note.ID < 8 && mustHit) ? (note.ID + 4) % 8 : note.ID;

			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == note.ID)
				{
					if (i == curSelectedNote)
						curSelectedNote = null;
					_song.notes[curSec].sectionNotes.remove(i);
					break;
				}
			}
		}
		else // Eventy
		{
			for (i in _song.events)
			{
				if (i[0] == note.strumTime)
				{
					if (i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	public function doANoteThing(cs, d, style)
	{
		var delnote = false;
		if (strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1, strumLine.y + 1)) && note.ID == d)
				{
					// trace('tryin to delete note...');
					if (!delnote)
						deleteNote(note);
					delnote = true;
				}
			});
		}

		if (!delnote)
		{
			addNote(cs, d, style);
		}
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	
	function isNoteInSection(strumTime:Float, secIndex:Int):Bool
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		var snapTolerance:Float = 8.0;
		for (i in 0..._song.notes.length)
		{
			var secStart = daPos;
			if (_song.notes[i] != null && _song.notes[i].changeBPM)
				daBPM = _song.notes[i].bpm;
			daPos += getSectionBeats(i) * (1000 * 60 / daBPM);

			if (i == secIndex)
			{
				var t = strumTime;
				if (Math.abs(t - secStart) < snapTolerance)
					return true;
				if (Math.abs(t - daPos) < snapTolerance)
					return false;
				return t >= secStart && t < daPos;
			}
		}
		return false;
	}

	
	function repairCurrentSection():Void
	{
		if (_song == null || _song.notes == null)
			return;

		var lo = Std.int(Math.max(0, curSec - 2));
		var hi = Std.int(Math.min(_song.notes.length - 1, curSec + 2));

		// Pre-oblicz granice sekcji raz
		var sectionStarts:Array<Float> = [];
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0..._song.notes.length)
		{
			sectionStarts.push(daPos);
			if (_song.notes[i] != null && _song.notes[i].changeBPM)
				daBPM = _song.notes[i].bpm;
			daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
		}
		sectionStarts.push(daPos);

		var snapTolerance:Float = 8.0;

		var displaced:Array<Dynamic> = [];
		for (i in lo...(hi + 1))
		{
			if (_song.notes[i] == null || _song.notes[i].sectionNotes == null)
				continue;
			var keep:Array<Dynamic> = [];
			for (note in _song.notes[i].sectionNotes)
			{
				var t:Float = note[0];

				// System snapowania do granic sekcji
				for (start in sectionStarts)
				{
					if (Math.abs(t - start) < snapTolerance)
					{
						note[0] = start;
						t = start;
						break;
					}
				}

				if (isNoteInSection(t, i))
				{
					keep.push(note);
				}
				else
				{
					displaced.push(note);
				}
			}
			_song.notes[i].sectionNotes = keep;
		}

		if (displaced.length == 0)
			return;

		for (note in displaced)
		{
			var t:Float = note[0];
			var target:Int = _song.notes.length - 1;
			for (j in 0..._song.notes.length)
			{
				if (t >= sectionStarts[j] && t < sectionStarts[j + 1])
				{
					target = j;
					break;
				}
			}
			if (_song.notes[target] != null)
				_song.notes[target].sectionNotes.push(note);
		}

		updateGrid();
	}

	function resortNotes():Void
	{
		// Step 1: Pre-compute the START time of every section using the
		// exact same logic as sectionStartTime(), so boundaries are consistent.
		var sectionStarts:Array<Float> = [];
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0..._song.notes.length)
		{
			sectionStarts.push(daPos);
			if (_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					daBPM = _song.notes[i].bpm;
				}
				daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
			}
		}
		// Sentinel: total song end time (used as upper bound for last section)
		sectionStarts.push(daPos);

		// Step 2: Pull every note out of every section into a flat list.
		var allNotes:Array<Dynamic> = [];
		for (sec in _song.notes)
		{
			if (sec != null && sec.sectionNotes != null)
			{
				for (note in sec.sectionNotes)
				{
					allNotes.push(note);
				}
				sec.sectionNotes = [];
			}
		}

		var snapTolerance:Float = 8.0;

		// Step 3: Place each note into the correct section based on its
		// absolute strumTime, and snap to boundary if it's very close!
		for (note in allNotes)
		{
			var strumTime:Float = note[0];

			for (start in sectionStarts)
			{
				if (Math.abs(strumTime - start) < snapTolerance)
				{
					note[0] = start;
					strumTime = start;
					break;
				}
			}

			var targetSec:Int = _song.notes.length - 1; // fallback: last section

			for (i in 0..._song.notes.length)
			{
				if (strumTime >= sectionStarts[i] && strumTime < sectionStarts[i + 1])
				{
					targetSec = i;
					break;
				}
			}

			if (targetSec < 0)
				targetSec = 0;
			if (targetSec >= _song.notes.length)
				targetSec = _song.notes.length - 1;

			if (_song.notes[targetSec] != null)
			{
				_song.notes[targetSec].sectionNotes.push(note);
			}
		}

		// Step 4: Sort notes within each section by ascending strumTime.
		for (sec in _song.notes)
		{
			if (sec != null && sec.sectionNotes != null && sec.sectionNotes.length > 1)
			{
				sec.sectionNotes.sort(function(a:Dynamic, b:Dynamic):Int
				{
					return Std.int(a[0] - b[0]);
				});
			}
		}

		updateGrid();
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null):Void
	{
		pushUndoSnapshot();
		var noteStrum = getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false) + sectionStartTime();

		var noteData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) - 1;

		var noteSus = 0;
		var daAlt = false;
		var daType = currentType;

		if (strum != null)
			noteStrum = strum;
		if (data != null)
			noteData = data;
		if (type != null)
			daType = type;

		if (noteData > -1)
		{
			var logicalNoteData = (data != null) ? noteData : visualToLogicalColumn(noteData);

			_song.notes[curSec].sectionNotes.push([noteStrum, logicalNoteData, noteSus, noteTypeIntMap.get(daType)]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
		}
		else
		{
			var event = eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
			var text1 = value1InputText.text;
			var text2 = value2InputText.text;
			_song.events.push([noteStrum, [[event, text1, text2]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
		}
		changeEventSelected();

		if (FlxG.keys.pressed.CONTROL && noteData > -1)
		{
			var mirroredData:Int = noteData;
			var totalCols:Int = getAmountOfColumns();

			if (noteData < 4)
			{
				mirroredData = (totalCols - 4) + (noteData % 4);
			}
			else if (noteData >= totalCols - 4)
			{
				mirroredData = noteData % 4;
			}

			mirroredData = visualToLogicalColumn(mirroredData);

			var canPush = true;
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i[0] == noteStrum && i[1] == mirroredData)
					canPush = false;
			}

			if (canPush)
				_song.notes[curSec].sectionNotes.push([noteStrum, mirroredData, noteSus, noteTypeIntMap.get(daType)]);
		}

		// trace(noteData + ', ' + noteStrum + ', ' + curSec);
		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();
	}

	// will figure this out l8r
	function redo()
	{
		// _song = redos[curRedoIndex];
	}

	function pushUndoSnapshot():Void
	{
		var notesCopy:Array<Array<Dynamic>> = [];
		for (n in _song.notes[curSec].sectionNotes)
		{
			var clone:Array<Dynamic> = [];
			for (val in (cast(n, Array<Dynamic>))) clone.push(val);
			notesCopy.push(clone);
		}
		undoHistory.push({sec: curSec, notes: notesCopy});
		if (undoHistory.length > 50) undoHistory.shift();
	}

	function undo()
	{
		if (undoHistory.length == 0) return;
		var snapshot = undoHistory.pop();
		if (snapshot.sec >= 0 && snapshot.sec < _song.notes.length)
		{
			_song.notes[snapshot.sec].sectionNotes = snapshot.notes;
			if (snapshot.sec != curSec) changeSection(snapshot.sec);
		}
		selectedNotes = [];
		curSelectedNote = null;
		updateGrid();
		updateNoteUI();
	}

	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if (!doZoomCalc)
			leZoom = 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if (!doZoomCalc)
			leZoom = 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
	}

	function getYfromStrumNotes(strumTime:Float, beats:Float):Float
	{
		var value:Float = strumTime / (beats * 4 * Conductor.stepCrochet);
		return GRID_SIZE * beats * 4 * zoomList[curZoom] * value + gridBG.y;
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String):Void
	{
		// shitty null fix, i fucking hate it when this happens
		// make it look sexier if possible
		if (CoolUtil.difficulties[PlayState.storyDifficulty] != CoolUtil.defaultDifficulty)
		{
			if (CoolUtil.difficulties[PlayState.storyDifficulty] == null)
			{
				PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
			}
			else
			{
				PlayState.SONG = Song.loadFromJson(song.toLowerCase() + "-" + CoolUtil.difficulties[PlayState.storyDifficulty], song.toLowerCase());
			}
		}
		else
		{
			PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
		}
		MusicBeatState.resetState();
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	function clearEvents()
	{
		_song.events = [];
		updateGrid();
	}

	private function saveLevel()
	{
		if (_song.events != null && _song.events.length > 1)
			_song.events.sort(sortByTime);
		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			#if linux
			var process = new sys.io.Process("zenity", [
				"--file-selection",
				"--save",
				"--title=Save Chart",
				"--filename=" + Paths.formatToSongPath(_song.song) + ".json"
			]);
			process.exitCode(true);
			var path = process.stdout.readAll().toString().trim();
			process.close();
			if (path != null && path.length > 0)
			{
				sys.io.File.saveContent(path, data.trim());
				FlxG.log.notice("Successfully saved LEVEL DATA.");
			}
			#else
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
			#end
		}
	}

	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveEvents()
	{
		if (_song.events != null && _song.events.length > 1)
			_song.events.sort(sortByTime);
		var eventsSong:Dynamic = {
			events: _song.events
		};
		var json = {
			"song": eventsSong
		}

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			#if linux
			var process = new sys.io.Process("zenity", ["--file-selection", "--save", "--title=Save Events", "--filename=events.json"]);
			process.exitCode(true);
			var path = process.stdout.readAll().toString().trim();
			process.close();
			if (path != null && path.length > 0)
			{
				sys.io.File.saveContent(path, data.trim());
				FlxG.log.notice("Successfully saved EVENTS.");
			}
			#else
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
			#end
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}

	function getSectionBeats(?section:Null<Int> = null)
	{
		if (section == null)
			section = curSec;
		var val:Null<Float> = null;

		if (_song.notes[section] != null)
			val = _song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	function normalizeOasisChart():Void
	{
		for (sec in _song.notes)
		{
			var secDynamic:Dynamic = sec;
			if (secDynamic.camFocus == null)
			{
				secDynamic.camFocus = sec.mustHitSection ? 1 : 0;

				// OASIS ENGINE CHART ALIGNMENT:
				// If mustHitSection was true, in the old Psych format columns 0-3 meant BF,
				// so we shift them by 4 columns to map into the new Oasis BF strum line (4-7)
				if (sec.mustHitSection)
				{
					for (note in sec.sectionNotes)
					{
						if (note[1] < 8)
						{
							note[1] = (note[1] + 4) % 8;
						}
					}
				}
			}

			// Synchronize mustHitSection with focusID instead of forcing it blindly
			sec.mustHitSection = (secDynamic.camFocus == 1);
		}
	}

	function getSectionCamFocus(sec:Section.SwagSection):Int
	{
		// SAFETY FALLBACK: If section is null, immediately return default auto focus (0)
		if (sec == null)
		{
			return 0;
		}

		var secDynamic:Dynamic = sec;

		if (secDynamic.camFocus != null && secDynamic.camFocus >= 0)
		{
			return secDynamic.camFocus;
		}

		return sec.mustHitSection ? 1 : 0;
	}

	var chartBfOffsets:Map<String, Array<Float>> = [
		'idle' => [-5.0, 0.0],
		'left' => [32.0, -1.0],
		'down' => [12.0, -28.0],
		'up' => [-3.0, 45.0],
		'right' => [-14.0, -8.0]
	];

	var chartDudeOffsets:Map<String, Array<Float>> = [
		'idle' => [-5.0, 0.0],
		'left' => [60.0, -13.0],
		'down' => [-12.0, -48.0],
		'up' => [7.0, 49.0],
		'right' => [-27.0, -25.0]
	];

	function playChartCharAnim(sprite:FlxSprite, anim:String, isBf:Bool)
	{
		if (sprite == null)
			return;
		sprite.animation.play(anim, true);
		var offsets = isBf ? chartBfOffsets.get(anim) : chartDudeOffsets.get(anim);
		if (offsets != null)
		{
			sprite.offset.set(offsets[0] * sprite.scale.x, offsets[1] * sprite.scale.y);
		}
		else
		{
			sprite.offset.set(0, 0);
		}
	}

	function playVisualAnim(isBf:Bool, anim:String)
	{
		var charSprite = isBf ? visualBf : visualDad;
		if (charSprite == null)
			return;
		playChartCharAnim(charSprite, anim, isBf);
	}

	function rebuildVisualCharacters():Void
	{
		// Clean up existing characters
		if (visualDad != null)
		{
			visualCharsGroup.remove(visualDad);
			visualDad.destroy();
			visualDad = null;
		}
		if (visualBf != null)
		{
			visualCharsGroup.remove(visualBf);
			visualBf.destroy();
			visualBf = null;
		}

		if (showVisualChars == null || !showVisualChars.checked)
		{
			return; // Do nothing if showVisualChars is disabled
		}

		// Center characters symmetrically under UI box (center of UI_box is 1060)
		var dadX:Float = UI_box.x + 30; // Centered symmetrically under UI box
		var bfX:Float = UI_box.x + 200; // Centered symmetrically under UI box

		// Load custom "cool" characters from assets/preload/images/charteditor
		try
		{
			var dadSprite = new FlxSprite(dadX, 0);
			dadSprite.frames = Paths.getSparrowAtlas('charteditor/chartdude');
			dadSprite.animation.addByPrefix('idle', 'idle', 120, true);
			dadSprite.animation.addByPrefix('left', 'left', 24, false);
			dadSprite.animation.addByPrefix('down', 'down', 24, false);
			dadSprite.animation.addByPrefix('up', 'up', 24, false);
			dadSprite.animation.addByPrefix('right', 'right', 24, false);
			dadSprite.scale.set(0.46, 0.46); // Scale to ~200px height (555 * 0.36)
			dadSprite.origin.set(0, 0); // Scale from top-left for precise positioning
			dadSprite.scrollFactor.set();
			dadSprite.y = FlxG.height - (dadSprite.frameHeight * dadSprite.scale.y) - 50; // window height - scaled height - margin 15px
			visualDad = dadSprite;
			playChartCharAnim(visualDad, 'idle', false);

			var bfSprite = new FlxSprite(bfX, 0);
			bfSprite.frames = Paths.getSparrowAtlas('charteditor/chartbf');
			bfSprite.animation.addByPrefix('idle', 'idle', 120, true);
			bfSprite.animation.addByPrefix('left', 'left', 24, false);
			bfSprite.animation.addByPrefix('down', 'down', 24, false);
			bfSprite.animation.addByPrefix('up', 'up', 24, false);
			bfSprite.animation.addByPrefix('right', 'right', 24, false);
			bfSprite.scale.set(0.46, 0.46); // Scale to ~200px height (429 * 0.46)
			bfSprite.origin.set(0, 0); // Scale from top-left for precise positioning
			bfSprite.scrollFactor.set();
			bfSprite.flipX = true; // Flip BF horizontally so he faces left/opponent
			bfSprite.y = FlxG.height - (bfSprite.frameHeight * bfSprite.scale.y) - 30; // window height - scaled height - margin 15px
			visualBf = bfSprite;
			playChartCharAnim(visualBf, 'idle', true);

			visualCharsGroup.add(visualDad);
			visualCharsGroup.add(visualBf);
		}
		catch (e:Dynamic)
		{
			FlxG.log.error("Failed to load custom charteditor characters: " + e);
		}
	}

	override function beatHit()
	{
		super.beatHit();

		if (showVisualChars != null && showVisualChars.checked)
		{
			if (visualDad != null
				&& !dadSungInSection
				&& (visualDad.animation.curAnim == null
					|| visualDad.animation.curAnim.name == 'idle'
					|| visualDad.animation.curAnim.finished))
			{
				playChartCharAnim(visualDad, 'idle', false);
			}
			if (visualBf != null
				&& !bfSungInSection
				&& (visualBf.animation.curAnim == null
					|| visualBf.animation.curAnim.name == 'idle'
					|| visualBf.animation.curAnim.finished))
			{
				playChartCharAnim(visualBf, 'idle', true);
			}
		}
	}
}

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true)
	{
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}
