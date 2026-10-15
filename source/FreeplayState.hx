package;

#if desktop
import Discord.DiscordClient;
#end
import editors.ChartingState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import StickersFadeTransition;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.ui.FlxBar;
import lime.utils.Assets;
import flixel.system.FlxSound;
import openfl.utils.Assets as OpenFlAssets;
import WeekData;
import Song;
#if MODS_ALLOWED
import sys.FileSystem;
#end

using StringTools;

enum FreeplaySelectionState
{
	CATEGORY;
	SONG;
	DIFFICULTY;
}

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var tabHintText:FlxText;
	var leftArrow:Alphabet;
	var rightArrow:Alphabet;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Int = -1;

	private var mainIcon:HealthIcon;

	var bg:FlxSprite;
	var intendedColor:Int = 0;
	var colorTween:FlxTween;

	private var fullWeekMap:Map<String, Array<SongMetadata>> = new Map();
	private var fullWeekNames:Array<String> = [];

	private var weekMap:Map<String, Array<SongMetadata>> = new Map();
	private var weekNames:Array<String> = [];

	private var curWeek:Int = 0;
	private var curSong:Int = 0;
	private var weekNameText:Alphabet;

	public static var vocals:FlxSound = null;

	private var curState:FreeplaySelectionState = CATEGORY;
	private var grpCategories:FlxTypedGroup<FlxBasic>;
	private var catStory:FlxSprite;
	private var catOthers:FlxSprite;
	private var catSelectText:FlxText;
	private var curCategory:Int = 0;

	private var grpDifficultySelect:FlxTypedGroup<FlxBasic>;
	private var difficultyTitle:Alphabet;
	private var grpDifficultyChoices:FlxTypedGroup<Alphabet>;
	private var curDifficulty:Int = 2;

	private static var lastDifficultyName:String = 'Hard';
	private static var lastCategory:Int = 0;
	public static var cameFromPlay:Bool = false;
	public static var stickerTransitionNext:Bool = false;

	var textBG:FlxSprite;
	var text:FlxText;

	// New playback system 'cause 0.6.3 one is futureless
	var playbackSongBG:FlxSprite;
	var playbackSongTxt:FlxText;
	var playbackTimeBar:FlxBar;
	var playbackTimeTxt:FlxText;
	var playbackRateTxt:FlxText;

	var playbackRate:Float = 1.0;

	public var songPercent:Float = 0;

	private var isTransitioning:Bool = false;
	var isConfirming:Bool = false;

	// Variables for syncing background JSON parse and UI tween
	var songLoaded:Bool = false;
	var tweenFinished:Bool = false;
	var transitionTriggered:Bool = false;

    var noSongsText:FlxText;

	// Layers for error screen
	private var songLayer:FlxGroup;
	private var errorLayer:FlxGroup;

	private var grpErrorScreen:FlxTypedGroup<FlxBasic>;
	private var errorIcon:HealthIcon;
	private var errorSubTitle:FlxText;
	private var isError:Bool = false;

	private var widthCache:Map<String, Float> = new Map();

	override function create()
	{
		#if LUA_ALLOWED
		FunkinLua.clearScriptCache();
		#end
		Song.clearChartCache();

		// Load songs
		curWeek = ClientPrefs.freePlayWeek;
		curSong = ClientPrefs.freePlaySong;

		super.create();

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if desktop
		DiscordClient.changePresence("In the Menus", null);
		#end

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;
			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			cacheWidth(leWeek.weekName.toUpperCase());
			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
					colors = [146, 113, 253];
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
				cacheWidth(song[0].toUpperCase());
			}
		}
		WeekData.loadTheFirstEnabledMod();

		for (song in songs)
		{
			var weekFile:String = WeekData.weeksList[song.week];
			if (weekFile == null)
				weekFile = '';
			if (!fullWeekMap.exists(weekFile))
			{
				fullWeekNames.push(weekFile);
				fullWeekMap.set(weekFile, []);
			}
			fullWeekMap.get(weekFile).push(song);
		}

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.color = 0xFF8700D4;
		add(bg);
		bg.screenCenter();

		// Layers
		songLayer = new FlxGroup();
		add(songLayer);

		errorLayer = new FlxGroup();
		add(errorLayer);

		mainIcon = new HealthIcon('bf');
		mainIcon.alpha = 0;
		songLayer.add(mainIcon);

		grpDifficultySelect = new FlxTypedGroup<FlxBasic>();
		grpDifficultySelect.visible = false;
		songLayer.add(grpDifficultySelect);

		var blackBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		blackBG.alpha = 0.6;
		grpDifficultySelect.add(blackBG);
		difficultyTitle = new Alphabet(0, 80, "SONG", true);
		grpDifficultySelect.add(difficultyTitle);
		grpDifficultyChoices = new FlxTypedGroup<Alphabet>();
		grpDifficultySelect.add(grpDifficultyChoices);

		grpCategories = new FlxTypedGroup<FlxBasic>();
		songLayer.add(grpCategories);

		catStory = new FlxSprite(0, 0);
		catStory.antialiasing = ClientPrefs.globalAntialiasing;
		grpCategories.add(catStory);

		catOthers = new FlxSprite(640, 0);
		catOthers.antialiasing = ClientPrefs.globalAntialiasing;
		grpCategories.add(catOthers);

		catSelectText = new FlxText(0, 50, FlxG.width, "SELECT A CATEGORY", 48);
		catSelectText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		catSelectText.borderSize = 3;
		grpCategories.add(catSelectText);

		// Score text
		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0;
		scoreText.alpha = 0;
		songLayer.add(scoreBG);
		songLayer.add(scoreText);

		// Info bar
		textBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		textBG.alpha = 0;
		songLayer.add(textBG);

		tabHintText = new FlxText(0, 0, FlxG.width, "Press TAB to open faster week selector", 20);
		tabHintText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tabHintText.alpha = 0;
		songLayer.add(tabHintText);

        noSongsText = new FlxText(0, 0, FlxG.width, "There's no content in here!\nTry to download some mods.", 20);
        noSongsText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        noSongsText.alpha = 0;
        noSongsText.screenCenter(X);
        noSongsText.screenCenter(Y);
        songLayer.add(noSongsText);

		leftArrow = new Alphabet(20, 30, "<", true);
		leftArrow.screenCenter(Y);
		leftArrow.alpha = 0;
		songLayer.add(leftArrow);
		
		rightArrow = new Alphabet(FlxG.width - 60, 30, ">", true);
		rightArrow.screenCenter(Y);
		rightArrow.alpha = 0;
		songLayer.add(rightArrow);

		text = new FlxText(0, FlxG.height - 22, FlxG.width, "", 18);
		text.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, RIGHT);
		text.alpha = 0;
		songLayer.add(text);

		

		createErrorScreen();

		super.create();
		curCategory = lastCategory;
		updateCategoryVisuals(true);

		if (cameFromPlay)
		{
			cameFromPlay = false;

			curWeek = ClientPrefs.freePlayWeek;
			curSong = ClientPrefs.freePlaySong;

			rebuildSongList(0);
			changeSong(0);
			selectCategory();
		}
		else
		{
			curWeek = 0;
			curSong = 0;
		}

		if (stickerTransitionNext)
		{
			stickerTransitionNext = false;
			var intro:StickerFadeTransition = new StickerFadeTransition(true);
			openSubState(intro);
		}
	}

	function cacheWidth(text:String)
	{
		if (widthCache.exists(text))
			return;
		var tempAlpha:Alphabet = new Alphabet(0, 0, text, true);
		widthCache.set(text, tempAlpha.width);
		tempAlpha.destroy();
	}

	function updateBottomText()
	{
		if (text != null)
		{
			if (curPlaying == -1)
				text.text = "SPACE: Listen / ENTER: Select / CTRL: Modifiers / RESET: Reset Score  ";
			else
				text.text = "UP/DOWN: Speed / LEFT/RIGHT: Seek 5s / ESC or SPACE: Stop  ";
		}
	}

	function createErrorScreen()
	{
		grpErrorScreen = new FlxTypedGroup<FlxBasic>();
		grpErrorScreen.visible = false;

		var errBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		errBG.alpha = 0.8;
		grpErrorScreen.add(errBG);

		var errTitle = new Alphabet(0, 80, "Ups! We couldn't find song files", true);
		errTitle.scaleX = 0.55;
		errTitle.scaleY = 0.55;
		errTitle.screenCenter(X);
		grpErrorScreen.add(errTitle);

		errorSubTitle = new FlxText(0, 175, FlxG.width, "[SONG NAME]", 34);
		errorSubTitle.setFormat(Paths.font("vcr.ttf"), 34, FlxColor.CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorSubTitle.borderSize = 2;
		grpErrorScreen.add(errorSubTitle);

		errorIcon = new HealthIcon('face');
		errorIcon.screenCenter();
		errorIcon.y += 40;
		grpErrorScreen.add(errorIcon);

		var errBtm = new FlxText(0, FlxG.height - 110, FlxG.width, "Press any key to back to song list.", 26);
		errBtm.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		grpErrorScreen.add(errBtm);

		errorLayer.add(grpErrorScreen);
	}

	function createSongSelectUI(fromLeft:Bool = true)
	{
		// Better category sorting system.

		weekMap = new Map<String, Array<SongMetadata>>();
		weekNames = [];

		for (weekFile in fullWeekNames)
		{
			var leWeek:WeekData = WeekData.weeksLoaded.get(weekFile);

			if (leWeek != null)
			{
				if (leWeek.freeplayCategory == curCategory)
				{
					weekNames.push(weekFile);
					weekMap.set(weekFile, fullWeekMap.get(weekFile));
				}
			}
		}

		grpSongs = new FlxTypedGroup<Alphabet>();
		songLayer.add(grpSongs);

		weekNameText = new Alphabet(0, 75, "Week", true);
		weekNameText.alpha = 0;
		songLayer.add(weekNameText);

		playbackSongBG = new FlxSprite(0, 0).makeGraphic(450, 115, FlxColor.BLACK);
		playbackSongBG.alpha = 0;
		songLayer.add(playbackSongBG);

		playbackSongTxt = new FlxText(15, 12, 420, "Now Playing: ");
		playbackSongTxt.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		playbackSongTxt.alpha = 0;
		songLayer.add(playbackSongTxt);

		playbackTimeTxt = new FlxText(15, 45, 420, "0:00 / 0:00");
		playbackTimeTxt.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		playbackTimeTxt.alpha = 0;
		songLayer.add(playbackTimeTxt);

		playbackRateTxt = new FlxText(15, 72, 420, "SPEED: 1.00x");
		playbackRateTxt.setFormat(Paths.font("vcr.ttf"), 20, 0xFFFFD700, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		playbackRateTxt.borderSize = 1.5;
		playbackRateTxt.alpha = 0;
		songLayer.add(playbackRateTxt);

		playbackTimeBar = new FlxBar(0, 111, LEFT_TO_RIGHT, 450, 4, this, 'songPercent', 0, 1);
		playbackTimeBar.createFilledBar(0xFF111111, FlxColor.CYAN);
		playbackTimeBar.alpha = 0;
		songLayer.add(playbackTimeBar);

		updateBottomText();
		var offScreenX = fromLeft ? -FlxG.width : FlxG.width;

		text.alpha = 0;
		textBG.alpha = 0;
		text.x = offScreenX;
		textBG.x = offScreenX;
		scoreText.x = (offScreenX > 0) ? FlxG.width + 10 : -FlxG.width;

		FlxTween.tween(text, {x: 0, alpha: 1}, 0.35, {ease: FlxEase.expoOut});
		FlxTween.tween(textBG, {x: 0, alpha: 0.6}, 0.35, {ease: FlxEase.expoOut});
		FlxTween.tween(scoreText, {alpha: 1}, 0.35, {ease: FlxEase.expoOut});
		FlxTween.tween(scoreBG, {alpha: 0.6}, 0.35, {ease: FlxEase.expoOut});
		if (tabHintText != null) FlxTween.tween(tabHintText, {alpha: 1}, 0.35, {ease: FlxEase.expoOut});
		if (leftArrow != null) FlxTween.tween(leftArrow, {alpha: 1}, 0.35, {ease: FlxEase.expoOut});
		if (rightArrow != null) FlxTween.tween(rightArrow, {alpha: 1}, 0.35, {ease: FlxEase.expoOut});

		intendedColor = 0;
		if (weekNames.length > 0)
			rebuildSongList(0);
	}

	override function update(elapsed:Float)
	{
		MainThreadDispatcher.pump();

		if (isError)
		{
			if (FlxG.keys.justPressed.ANY)
			{
				isError = false;
				grpErrorScreen.visible = false;
				setUIGhosts(false);
				FlxG.sound.play(Paths.sound('cancelMenu'));
				if (FlxG.sound.music != null)
					FlxG.sound.music.volume = 0.7;
			}
			super.update(elapsed);
			return;
		}

		if (FlxG.sound.music.volume < 0.7 && curPlaying == -1)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		// Personal best
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));
		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		if (scoreText != null && scoreText.alpha > 0)
		{
			var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
			if (ratingSplit.length < 2)
				ratingSplit.push('');
			while (ratingSplit[1].length < 2)
				ratingSplit[1] += '0';
			scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
			positionHighscore();
		}

		if (curPlaying != -1 && FlxG.sound.music != null)
		{
			if (!FlxG.sound.music.playing || FlxG.sound.music.time >= FlxG.sound.music.length - 200)
			{
				stopSongPreview();
			}
			else
			{
				Conductor.songPosition = FlxG.sound.music.time;
				songPercent = FlxG.sound.music.time / FlxG.sound.music.length;
				var curTime = Math.floor(FlxG.sound.music.time / 1000);
				var duration = Math.floor(FlxG.sound.music.length / 1000);
				playbackTimeTxt.text = Std.string(Math.floor(curTime / 60)) + ":" + (curTime % 60 < 10 ? "0" : "") + Std.string(curTime % 60) + " / "
					+ Std.string(Math.floor(duration / 60)) + ":" + (duration % 60 < 10 ? "0" : "") + Std.string(duration % 60);

				if (vocals != null && vocals.playing)
				{
					if (Math.abs(vocals.time - FlxG.sound.music.time) > 20)
						vocals.time = FlxG.sound.music.time;
				}
			}
		}

		if (!isTransitioning)
		{
			if (weekNameText != null && weekNameText.alpha > 0.01)
			{
				var w = widthCache.get(weekNameText.text);
				if (w != null)
					weekNameText.x = (FlxG.width - w) / 2;
			}
		}
		else
		{
			if (!transitionTriggered && songLoaded && tweenFinished)
			{
				transitionTriggered = true;
				if (FlxG.sound.music != null)
					FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxTransitionableState.skipNextTransIn = false;
				FlxTransitionableState.skipNextTransOut = false;
				new FlxTimer().start(0.016, function(_)
				{
					MusicBeatState.switchState(LoadingState.getNextState(new PlayState()));
				});
			}
		}

		switch (curState)
		{
			case CATEGORY:
				if (controls.UI_LEFT_P)
					changeCategory(-1);
				else if (controls.UI_RIGHT_P)
					changeCategory(1);
				if (controls.ACCEPT)
					selectCategory();
				else if (controls.BACK)
				{
					if (colorTween != null)
						colorTween.cancel();
					FlxG.sound.play(Paths.sound('cancelMenu'));
					MusicBeatState.switchState(new MainMenuState());
				}

			case SONG:
				if (weekNames.length == 0)
				{
                    noSongsText.alpha = 1;

					if (controls.BACK) {
                        noSongsText.alpha = 0;
						goBackToCategory();
                    }
					super.update(elapsed);
					return;
				}

				if (grpSongs != null && !isTransitioning)
				{
					for (i in 0...grpSongs.members.length)
					{
						var item = grpSongs.members[i];
						if (item == null)
							continue;
						item.y = FlxMath.lerp(item.y, (FlxG.height * 0.45) + ((i - curSong) * 140), CoolUtil.boundTo(elapsed * 12, 0, 1));
						var sw = widthCache.get(item.text);
						if (sw != null)
							item.x = (FlxG.width - sw) / 2;

						var targetAlpha = (i == curSong ? 1.0 : 0.6);
						item.alpha = FlxMath.lerp(item.alpha, isError ? 0.05 : targetAlpha, CoolUtil.boundTo(elapsed * 10, 0, 1));
					}
				}

				if (curPlaying > -1)
				{
					var oldRate = playbackRate;
					if (controls.UI_UP_P)
						playbackRate += 0.05;
					if (controls.UI_DOWN_P)
						playbackRate -= 0.05;
					playbackRate = FlxMath.bound(playbackRate, 0.5, 3.0);
					playbackRate = FlxMath.roundDecimal(playbackRate, 2);

					if (oldRate != playbackRate)
					{
						playbackRate = flixel.math.FlxMath.roundDecimal(playbackRate, 2);

						playbackRateTxt.text = "SPEED: " + playbackRate + "x";

						playbackRateTxt.scale.set(1.2, 1.2);
						playbackRateTxt.color = 0xFFFFFFFF;

						FlxTween.cancelTweensOf(playbackRateTxt);
						FlxTween.tween(playbackRateTxt.scale, {x: 1, y: 1}, 0.15);
						FlxTween.color(playbackRateTxt, 0.15, 0xFFFFFFFF, 0xFFFFD700);
					}

					FlxG.sound.music.pitch = playbackRate;
					if (vocals != null && vocals.playing)
						vocals.pitch = playbackRate;

					if (controls.UI_LEFT_P)
					{
						FlxG.sound.music.time -= 5000;
						if (vocals != null)
							vocals.time = FlxG.sound.music.time;
					}
					if (controls.UI_RIGHT_P)
					{
						FlxG.sound.music.time += 5000;
						if (vocals != null)
							vocals.time = FlxG.sound.music.time;
					}
					if (controls.BACK || FlxG.keys.justPressed.SPACE)
						stopSongPreview();
				}
				else if (subState == null && !isTransitioning)
				{
					if (controls.UI_LEFT_P)
						changeWeek(-1);
					else if (controls.UI_RIGHT_P)
						changeWeek(1);
					if (controls.UI_UP_P)
						changeSong(-1);
					else if (controls.UI_DOWN_P)
						changeSong(1);

					ClientPrefs.freePlayWeek = curWeek;
					ClientPrefs.freePlaySong = curSong;

					if (FlxG.keys.justPressed.ENTER)
					{
						var curSongData:SongMetadata = weekMap.get(weekNames[curWeek])[curSong];
						var songLowercase:String = Paths.formatToSongPath(curSongData.songName);
						FlxG.sound.play(Paths.sound('confirmMenu'));

						updateDifficulties();
						
						if (CoolUtil.difficulties.length > 1) {
							curState = DIFFICULTY;
							openDifficultyMenu();
							return;
						} else if (CoolUtil.difficulties.length == 1) {
							curDifficulty = 0;
							lastDifficultyName = CoolUtil.difficulties[0];
						} else {
							curDifficulty = 0; // Fallback
						}

						cameFromPlay = true;
						isTransitioning = true;
						isConfirming = true;
						songLoaded = false;
						tweenFinished = false;

						var capturedRate:Float = playbackRate;
						var diffToUse:Int = curDifficulty;

						#if sys
						sys.thread.Thread.create(function()
						{
							try
							{
								var loadedSong = Song.loadFromJson(Highscore.formatSong(songLowercase, diffToUse), songLowercase);

								LoadingState.startBackgroundPreload(loadedSong);

								MainThreadDispatcher.runOnMain(function()
								{
									PlayState.SONG = loadedSong;
									try
									{
										Reflect.setField(PlayState, "playbackRate", capturedRate);
									}
									catch (e:Dynamic)
									{
									}

									songLoaded = true;
								});
							}
							catch (e:Dynamic)
							{
								trace("Background load failed: " + e);

								MainThreadDispatcher.runOnMain(function()
								{
									isTransitioning = false;
									isConfirming = false;
									showErrorScreen(curSongData.songCharacter, curSongData.songName);
								});
							}
						});
						#else
						try
						{
							PlayState.SONG = Song.loadFromJson(Highscore.formatSong(songLowercase, diffToUse), songLowercase);
							try
							{
								Reflect.setField(PlayState, "playbackRate", capturedRate);
							}
							catch (e:Dynamic)
							{
							}
							LoadingState.startBackgroundPreload(PlayState.SONG);
							songLoaded = true;
						}
						catch (e:Dynamic)
						{
							isTransitioning = false;
							isConfirming = false;
							showErrorScreen(curSongData.songCharacter, curSongData.songName);
						}
						#end

						// Przygaszenie muzyki
						if (FlxG.sound.music != null)
							FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.5);
						if (vocals != null)
							FlxTween.tween(vocals, {volume: 0}, 0.5);

						// Znikanie UI
						var fadeTime:Float = 0.35;
						if (scoreText != null)
							FlxTween.tween(scoreText, {alpha: 0}, fadeTime);
						if (tabHintText != null)
							FlxTween.tween(tabHintText, {alpha: 0}, fadeTime);
						if (leftArrow != null)
							FlxTween.tween(leftArrow, {alpha: 0}, fadeTime);
						if (rightArrow != null)
							FlxTween.tween(rightArrow, {alpha: 0}, fadeTime);
						if (scoreBG != null)
							FlxTween.tween(scoreBG, {alpha: 0}, fadeTime);
						if (textBG != null)
							FlxTween.tween(textBG, {alpha: 0}, fadeTime);
						if (text != null)
							FlxTween.tween(text, {alpha: 0}, fadeTime);
						if (weekNameText != null)
							FlxTween.tween(weekNameText, {alpha: 0}, fadeTime);
						if (mainIcon != null)
							FlxTween.tween(mainIcon, {alpha: 0}, fadeTime);
						if (playbackSongBG != null)
							playbackSongBG.alpha = 0;
						if (playbackSongTxt != null)
							playbackSongTxt.alpha = 0;
						if (playbackTimeBar != null)
							playbackTimeBar.alpha = 0;
						if (playbackTimeTxt != null)
							playbackTimeTxt.alpha = 0;
						if (playbackRateTxt != null)
							playbackRateTxt.alpha = 0;

						if (grpSongs != null)
						{
							for (i in 0...grpSongs.members.length)
							{
								var item = grpSongs.members[i];
								if (item == null)
									continue;
								if (i != curSong)
									FlxTween.tween(item, {alpha: 0}, fadeTime, {ease: FlxEase.expoOut});
							}
						}

						var selectedItem = (grpSongs != null) ? grpSongs.members[curSong] : null;
						if (selectedItem != null)
						{
							var targetX:Float = (FlxG.width - selectedItem.width) / 2;
							var targetY:Float = (FlxG.height - selectedItem.height) / 2;
							FlxTween.tween(selectedItem, {x: targetX, y: targetY, alpha: 0}, 0.55, {
								ease: FlxEase.expoIn,
								onComplete: function(_)
								{
									tweenFinished = true;
								}
							});
						}
						else
						{
							tweenFinished = true;
						}
					}
					else if (controls.BACK)
						goBackToCategory();
					else if (FlxG.keys.justPressed.SPACE)
						startSongPreview();
					else if (FlxG.keys.justPressed.CONTROL)
						openSubState(new GameplayChangersSubstate());
				} // <-- Added closing brace for 'else if (subState == null && !isTransitioning)'

				if (subState == null && !isTransitioning && FlxG.keys.justPressed.TAB)
				{
					openSubState(new FreeplayWeekSubstate(weekNames, curWeek, function(newWeek:Int) {
						if (newWeek != curWeek) {
							var diff = newWeek - curWeek;
							changeWeek(diff);
						}
					}));
				}

				// Difficulty choosing has been removed from this mod, so I'll remove that later.
				case DIFFICULTY:
						if (subState == null)
						{
							if (controls.UI_UP_P)
								changeDiff(-1);
							else if (controls.UI_DOWN_P)
								changeDiff(1);
							if (controls.ACCEPT)
							{
								var curSongData:SongMetadata = weekMap.get(weekNames[curWeek])[curSong];
								var songLowercase:String = Paths.formatToSongPath(curSongData.songName);
								try
								{
									PlayState.SONG = Song.loadFromJson(Highscore.formatSong(songLowercase, curDifficulty), songLowercase);
									try
									{
										Reflect.setField(PlayState, "playbackRate", playbackRate);
									}
									catch (e:Dynamic)
									{
									}
									cameFromPlay = true;
									stopSongPreview(true);
									FlxTransitionableState.skipNextTransIn = false;
									FlxTransitionableState.skipNextTransOut = false;
									LoadingState.loadAndSwitchState(new PlayState());
								}
								catch (e:Dynamic)
								{
									showErrorScreen(curSongData.songCharacter, curSongData.songName);
								}
							}
							else if (controls.BACK)
							{
								FlxG.sound.play(Paths.sound('cancelMenu'));
								curState = SONG;
								closeDifficultyMenu();
							}
						}
				}

				if (curState == SONG && weekNames.length > 0 && weekNames[curWeek] != null)
				{
					if (!isConfirming)
					{
						mainIcon.alpha = FlxMath.lerp(mainIcon.alpha, isError ? 0.05 : 1, elapsed * 15);
						mainIcon.x = 40;
						mainIcon.y = FlxG.height - mainIcon.height - 40;
						var mult:Float = FlxMath.lerp(1, mainIcon.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
						mainIcon.scale.set(mult, mult);
					}
				}
				else
				{
					mainIcon.alpha = 0;
				}

				super.update(elapsed);
		}

		override function beatHit()
		{
			super.beatHit();
			if (curState == SONG && !isError)
				mainIcon.scale.set(1.2, 1.2);
		}

		function startSongPreview()
		{
			var songData = weekMap.get(weekNames[curWeek])[curSong];
			if (songData == null)
				return;
			var songLowercase = Paths.formatToSongPath(songData.songName);

			destroyFreeplayVocals();
			FlxG.sound.music.stop();
			Paths.currentModDirectory = songData.folder;

			try
			{
				PlayState.SONG = Song.loadFromJson(songLowercase + '-hard', songLowercase);
				Conductor.mapBPMChanges(PlayState.SONG);
				Conductor.changeBPM(PlayState.SONG.bpm);
			}
			catch (e:Dynamic)
			{
				showErrorScreen(songData.songCharacter, songData.songName);
				return;
			}

			if (PlayState.SONG.needsVoices)
				vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
			else
				vocals = new FlxSound();

			FlxG.sound.list.add(vocals);
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7, false);

			vocals.play();
			vocals.persist = true;
			vocals.looped = false;
			vocals.volume = 0.7;
			vocals.pitch = playbackRate;
			FlxG.sound.music.pitch = playbackRate;

			curPlaying = songs.indexOf(songData);

			playbackSongTxt.text = "Now Playing: " + songData.songName.toUpperCase();
			playbackRateTxt.text = "SPEED: " + (Math.floor(playbackRate * 100) / 100) + "x";

			playbackTimeBar.color = songData.color;
			playbackTimeTxt.color = songData.color;

			FlxTween.tween(playbackSongBG, {alpha: 0.65}, 0.2);
			FlxTween.tween(playbackSongTxt, {alpha: 1}, 0.2);
			FlxTween.tween(playbackTimeTxt, {alpha: 1}, 0.2);
			FlxTween.tween(playbackRateTxt, {alpha: 1}, 0.2);
			FlxTween.tween(playbackTimeBar, {alpha: 1}, 0.2);

			updateBottomText();
		}

		function showErrorScreen(char:String, songName:String)
		{
			isError = true;
			grpErrorScreen.visible = true;
			errorIcon.changeIcon(char);
			errorIcon.animation.curAnim.curFrame = 1;
			errorSubTitle.text = "Song File: " + songName.toUpperCase() + "-HARD.JSON";

			setUIGhosts(true);
			destroyFreeplayVocals();
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);

			playbackSongBG.alpha = 0;
			playbackSongTxt.alpha = 0;
			playbackTimeBar.alpha = 0;
			playbackTimeTxt.alpha = 0;
			playbackRateTxt.alpha = 0;
			curPlaying = -1;

			FlxG.sound.play(Paths.sound('missnote' + FlxG.random.int(1, 3)), 0.5);
		}

		function setUIGhosts(ghost:Bool)
		{
			var alphaVal = ghost ? 0.05 : 1.0;
			if (weekNameText != null)
				weekNameText.alpha = alphaVal;
			if (scoreText != null)
				scoreText.alpha = alphaVal;
			if (tabHintText != null)
				tabHintText.alpha = alphaVal;
			if (leftArrow != null)
				leftArrow.alpha = alphaVal;
			if (rightArrow != null)
				rightArrow.alpha = alphaVal;
			if (scoreBG != null)
				scoreBG.alpha = ghost ? 0.05 : 0.6;
			if (text != null)
				text.alpha = alphaVal;
			if (textBG != null)
				textBG.alpha = ghost ? 0.05 : 0.6;
		}

		function stopSongPreview(isStartingSong:Bool = false)
		{
			if (curPlaying == -1)
				return;

			curPlaying = -1;
			destroyFreeplayVocals();

			if (!isStartingSong)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
				FlxG.sound.music.pitch = 1.0;
			}
			else
			{
				if (FlxG.sound.music != null)
					FlxG.sound.music.stop();
			}

			if (playbackSongBG != null)
				playbackSongBG.alpha = 0;
			if (playbackSongTxt != null)
				playbackSongTxt.alpha = 0;
			if (playbackTimeBar != null)
				playbackTimeBar.alpha = 0;
			if (playbackTimeTxt != null)
				playbackTimeTxt.alpha = 0;
			if (playbackRateTxt != null)
				playbackRateTxt.alpha = 0;

			updateBottomText();
		}

		function selectCategory()
		{
			lastCategory = curCategory;
			FlxG.sound.play(Paths.sound('confirmMenu'));
			curState = SONG;
			FlxTween.tween(catSelectText, {alpha: 0, y: catSelectText.y - 60}, 0.35, {ease: FlxEase.quartIn});
			FlxTween.tween(catStory, {x: -640, alpha: 0}, 0.35, {ease: FlxEase.quartIn});
			FlxTween.tween(catOthers, {x: FlxG.width, alpha: 0}, 0.35, {
				ease: FlxEase.quartIn,
				onComplete: function(twn:FlxTween)
				{
					if (grpCategories != null)
						grpCategories.kill();
				}
			});
			createSongSelectUI(curCategory == 0);
		}

		function goBackToCategory()
		{
			stopSongPreview();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			curState = CATEGORY;
			colorTween = FlxTween.color(bg, 0.4, bg.color, 0xFF8700D4);
			destroySongSelectUI((curCategory == 0), function()
			{
				if (grpCategories != null)
				{
					grpCategories.revive();
					updateCategoryVisuals(true);

					catStory.x = -640;
					catStory.alpha = 0;
					catOthers.x = FlxG.width;
					catOthers.alpha = 0;
					catSelectText.y = -10;
					catSelectText.alpha = 0;

					FlxTween.tween(catStory, {x: 0, alpha: 1}, 0.35, {ease: FlxEase.expoOut});
					FlxTween.tween(catOthers, {x: 640, alpha: 1}, 0.35, {ease: FlxEase.expoOut});
					FlxTween.tween(catSelectText, {alpha: 1, y: 50}, 0.35, {ease: FlxEase.expoOut});
				}
			});
		}

		function destroySongSelectUI(exitToLeft:Bool = true, onFinish:Void->Void)
		{
			var offScreenX = exitToLeft ? -FlxG.width : FlxG.width;
			if (weekNameText != null)
				FlxTween.tween(weekNameText, {x: weekNameText.x + offScreenX, alpha: 0}, 0.2);
			if (grpSongs != null)
				grpSongs.forEach(function(spr:Alphabet) FlxTween.tween(spr, {x: spr.x + offScreenX, alpha: 0}, 0.2));

			if (text != null)
				FlxTween.tween(text, {alpha: 0}, 0.2);
			if (textBG != null)
				FlxTween.tween(textBG, {alpha: 0}, 0.2);
			if (scoreText != null)
				FlxTween.tween(scoreText, {alpha: 0}, 0.2);
			if (tabHintText != null)
				FlxTween.tween(tabHintText, {alpha: 0}, 0.2);
			if (leftArrow != null)
				FlxTween.tween(leftArrow, {alpha: 0}, 0.2);
			if (rightArrow != null)
				FlxTween.tween(rightArrow, {alpha: 0}, 0.2);
			if (scoreBG != null)
				FlxTween.tween(scoreBG, {alpha: 0}, 0.2);

			if (playbackSongBG != null)
				playbackSongBG.alpha = 0;
			if (playbackSongTxt != null)
				playbackSongTxt.alpha = 0;
			if (playbackTimeBar != null)
				playbackTimeBar.alpha = 0;
			if (playbackTimeTxt != null)
				playbackTimeTxt.alpha = 0;
			if (playbackRateTxt != null)
				playbackRateTxt.alpha = 0;

			new FlxTimer().start(0.2, function(tmr:FlxTimer)
			{
				if (grpSongs != null)
				{
					grpSongs.destroy();
					grpSongs = null;
				}
				if (weekNameText != null)
				{
					weekNameText.destroy();
					weekNameText = null;
				}
				if (onFinish != null)
					onFinish();
			});
		}

		public static function destroyFreeplayVocals()
		{
			if (vocals != null)
			{
				vocals.stop();
				vocals.destroy();
			}
			vocals = null;
		}

		function changeWeek(change:Int = 0)
		{
			if (weekNames.length <= 1 || isTransitioning)
				return;
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			isTransitioning = true;
			var slideOutX = (change > 0) ? -FlxG.width : FlxG.width;
			if (grpSongs != null)
				grpSongs.forEach(function(s:Alphabet) FlxTween.tween(s, {x: s.x + slideOutX, alpha: 0}, 0.2, {ease: FlxEase.expoIn}));
			if (weekNameText != null)
				FlxTween.tween(weekNameText, {x: weekNameText.x + slideOutX, alpha: 0}, 0.2, {ease: FlxEase.expoIn});
			new FlxTimer().start(0.2, function(tmr:FlxTimer)
			{
				curWeek = FlxMath.wrap(curWeek + change, 0, weekNames.length - 1);
				curSong = 0;
				rebuildSongList(change);
			});
		}

		function changeSong(change:Int = 0)
		{
			if (weekNames.length == 0 || weekMap.get(weekNames[curWeek]) == null)
				return;
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			curSong = FlxMath.wrap(curSong + change, 0, weekMap.get(weekNames[curWeek]).length - 1);
			updateSelection();
		}

		function rebuildSongList(direction:Int = 0)
		{
			if (grpSongs == null)
				return;
			while (grpSongs.members.length > 0)
			{
				var s = grpSongs.members[0];
				grpSongs.remove(s, true);
				s.destroy();
			}

			var currentWeekName = weekNames[curWeek];
			var songsInWeek = weekMap.get(currentWeekName);
			if (songsInWeek == null)
			{
				isTransitioning = false;
				return;
			}

			var slideInX = (direction > 0) ? FlxG.width : (direction < 0 ? -FlxG.width : 0);
			var leWeek:WeekData = WeekData.weeksLoaded.get(currentWeekName);
			var nameToUse = (leWeek != null) ? leWeek.weekName.toUpperCase() : currentWeekName.toUpperCase();

			if (leftArrow != null) leftArrow.visible = (weekNames.length > 1);
			if (rightArrow != null) rightArrow.visible = (weekNames.length > 1);

			cacheWidth(nameToUse);
			weekNameText.text = nameToUse;
			weekNameText.alpha = 0;

			var w = widthCache.get(nameToUse);
			var weekCenter = (FlxG.width - w) / 2;
			weekNameText.x = weekCenter + slideInX;
			FlxTween.tween(weekNameText, {x: weekCenter, alpha: 1}, 0.25, {ease: FlxEase.expoOut});

			for (i in 0...songsInWeek.length)
			{
				var songText:Alphabet = new Alphabet(0, 0, songsInWeek[i].songName, true);
				songText.alpha = 0;
				var songNameU = songsInWeek[i].songName.toUpperCase();
				cacheWidth(songNameU);
				var sw = widthCache.get(songNameU);
				var songCenter = (FlxG.width - sw) / 2;
				songText.x = songCenter + slideInX;
				songText.y = (FlxG.height * 0.45) + ((i - curSong) * 140);
				grpSongs.add(songText);
				var staggerDelay:Float = (direction == 0) ? (i * 0.04) : 0;
				FlxTween.tween(songText, {x: songCenter, alpha: (i == curSong ? 1.0 : 0.6)}, 0.3, {
					ease: FlxEase.expoOut,
					startDelay: staggerDelay
				});
			}
			updateSelection();
			var maxDelay:Float = (direction == 0) ? (0.3 + (songsInWeek.length * 0.04)) : 0.3;
			new FlxTimer().start(maxDelay, function(t:FlxTimer)
			{
				isTransitioning = false;
			});
		}

		function updateSelection()
		{
			if (weekNames.length == 0 || weekMap.get(weekNames[curWeek]) == null)
				return;
			var songData = weekMap.get(weekNames[curWeek])[curSong];
			if (songData == null)
				return;

			Paths.currentModDirectory = songData.folder;
			if (mainIcon != null)
				try
				{
					mainIcon.changeIcon(songData.songCharacter);
				}
				catch (e:Dynamic)
				{
				}

			if (songData.color != intendedColor)
			{
				if (colorTween != null)
					colorTween.cancel();
				intendedColor = songData.color;
				colorTween = FlxTween.color(bg, 0.5, bg.color, intendedColor);
			}

			updateDifficulties();
			var checkDiff = (curDifficulty < 0) ? 0 : curDifficulty;
			intendedScore = Highscore.getScore(songData.songName, checkDiff);
			intendedRating = Highscore.getRating(songData.songName, checkDiff);
		}

		function updateCategoryVisuals(instant:Bool = false)
		{
			if (curCategory == 0)
			{
				catStory.loadGraphic(Paths.image('freeplaysprites/story_active'));
				catOthers.loadGraphic(Paths.image('freeplaysprites/freeplay_unactive'));
			}
			else
			{
				catStory.loadGraphic(Paths.image('freeplaysprites/story_unactive'));
				catOthers.loadGraphic(Paths.image('freeplaysprites/freeplay_active'));
			}

			catStory.x = 0;
			catStory.y = 0;
			catStory.alpha = 1;
			catStory.scale.set(1, 1);

			catOthers.x = 640;
			catOthers.y = 0;
			catOthers.alpha = 1;
			catOthers.scale.set(1, 1);
		}

		function openDifficultyMenu()
		{
			grpDifficultySelect.visible = true;
			setSongUIVisible(false);
			var selectedSong:SongMetadata = weekMap.get(weekNames[curWeek])[curSong];
			var songUpper = selectedSong.songName.toUpperCase();
			cacheWidth(songUpper);
			difficultyTitle.text = songUpper;

			var w = widthCache.get(songUpper);
			if (w != null)
				difficultyTitle.x = (FlxG.width - w) / 2;

			while (grpDifficultyChoices.members.length > 0)
			{
				var c = grpDifficultyChoices.members[0];
				grpDifficultyChoices.remove(c, true);
				c.destroy();
			}
			updateDifficulties();
			for (i in 0...CoolUtil.difficulties.length)
			{
				var diffName = CoolUtil.difficulties[i].toUpperCase();
				cacheWidth(diffName);
				var choiceText:Alphabet = new Alphabet(0, 0, diffName, true);
				var dw = widthCache.get(diffName);
				if (dw != null)
					choiceText.x = (FlxG.width - dw) / 2;
				choiceText.y = difficultyTitle.y + 110 + (i * 90);
				grpDifficultyChoices.add(choiceText);
			}
			curDifficulty = Math.round(Math.max(0, CoolUtil.difficulties.indexOf(lastDifficultyName)));
			changeDiff(0);
		}

		function closeDifficultyMenu()
		{
			if (grpDifficultySelect != null)
				grpDifficultySelect.visible = false;
			setSongUIVisible(true);
		}

		function changeDiff(change:Int = 0)
		{
			curDifficulty = FlxMath.wrap(curDifficulty + change, 0, CoolUtil.difficulties.length - 1);
			lastDifficultyName = CoolUtil.difficulties[curDifficulty];
			if (grpDifficultyChoices != null)
			{
				for (i in 0...grpDifficultyChoices.length)
				{
					if (grpDifficultyChoices.members[i] != null)
						grpDifficultyChoices.members[i].alpha = (i == curDifficulty) ? 1 : 0.6;
				}
			}
			// Updating the highscore text during change a diff - Now it's just useless cause difficulty selection has been deleted
			var songData = weekMap.get(weekNames[curWeek])[curSong];
			intendedScore = Highscore.getScore(songData.songName, curDifficulty);
			intendedRating = Highscore.getRating(songData.songName, curDifficulty);
		}

		function updateDifficulties()
		{
			var songData = weekMap.get(weekNames[curWeek])[curSong];
			var songLowercase = Paths.formatToSongPath(songData.songName);
			CoolUtil.difficulties = CoolUtil.getAvailableDifficulties(songLowercase);

			var weekFile:String = weekNames[curWeek];
			if (weekFile == null || !WeekData.weeksLoaded.exists(weekFile))
				return;
			var diffStr:String = WeekData.weeksLoaded.get(weekFile).difficulties;
			if (diffStr != null && diffStr.trim().length > 0)
			{
				var diffs:Array<String> = diffStr.split(',');
				var i:Int = diffs.length - 1;
				while (i >= 0)
				{
					diffs[i] = diffs[i].trim();
					if (diffs[i].length < 1)
						diffs.remove(diffs[i]);
					i--;
				}
				if (diffs.length > 0)
					CoolUtil.difficulties = diffs;
			}
		}

		private function positionHighscore()
		{
			scoreText.x = FlxG.width - scoreText.width - 6;
			scoreBG.scale.x = FlxG.width - scoreText.x + 6;
			scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		}

		function changeCategory(change:Int = 0)
		{
			curCategory = FlxMath.wrap(curCategory + change, 0, 1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			updateCategoryVisuals();
		}

		function setSongUIVisible(visible:Bool)
		{
			if (grpSongs != null)
				grpSongs.visible = visible;
			if (weekNameText != null)
				weekNameText.visible = visible;
			if (scoreText != null)
				scoreText.visible = visible;
			if (tabHintText != null)
				tabHintText.visible = visible;
			if (leftArrow != null)
				leftArrow.visible = visible;
			if (rightArrow != null)
				rightArrow.visible = visible;
			if (scoreBG != null)
				scoreBG.visible = visible;
		}

		public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
		{
			songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
		}

		function weekIsLocked(name:String):Bool
		{
			var leWeek:WeekData = WeekData.weeksLoaded.get(name);
			return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
		}

		override function destroy()
		{
			destroyFreeplayVocals();
			Paths.clearStoredMemory();
			Paths.clearUnusedMemory();
			super.destroy();
		}
	}

	class SongMetadata
	{
		public var songName:String = "";
		public var week:Int = 0;
		public var songCharacter:String = "";
		public var color:Int = -7179779;
		public var folder:String = "";

		public function new(song:String, week:Int, songCharacter:String, color:Int)
		{
			this.songName = song;
			this.week = week;
			this.songCharacter = songCharacter;
			this.color = color;
			this.folder = Paths.currentModDirectory;
			if (this.folder == null)
				this.folder = '';
		}
	}
