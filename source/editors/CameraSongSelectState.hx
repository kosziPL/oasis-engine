package editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import WeekData;
import Song;

using StringTools;

// Local song metadata — mirrors FreeplayState.SongMetadata
class CamSongMeta
{
	public var songName:String;
	public var week:Int;
	public var songCharacter:String;
	public var color:Int;
	public var folder:String;

	public function new(songName:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName      = songName;
		this.week          = week;
		this.songCharacter = songCharacter;
		this.color         = color;
		this.folder        = (Paths.currentModDirectory != null) ? Paths.currentModDirectory : '';
	}
}

class CameraSongSelectState extends MusicBeatState
{
	// ── Song list ─────────────────────────────────────────────────────────────
	var songs:Array<CamSongMeta> = [];

	// ── UI ───────────────────────────────────────────────────────────────────
	var bg:FlxSprite;
	var grpSongs:FlxTypedGroup<Alphabet>;
	var icon:HealthIcon;

	var titleText:FlxText;
	var tipText:FlxText;

	var curSelected:Int = 0;
	var intendedColor:Int = 0;
	var colorTween:FlxTween;

	// ── Create ────────────────────────────────────────────────────────────────
	override function create()
	{
		#if desktop
		Discord.DiscordClient.changePresence("Camera Editor - Select Song", null);
		#end

		// Background (same colour as freeplay)
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF8700D4;
		bg.scrollFactor.set();
		add(bg);

		// Title
		titleText = new FlxText(0, 18, FlxG.width, "CAMERA EDITOR - SELECT SONG", 26);
		titleText.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		titleText.scrollFactor.set();
		add(titleText);

		// Scrollable song list
		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		// Health icon (bottom-left, like freeplay)
		icon = new HealthIcon('bf');
		icon.alpha = 0;
		icon.x = 40;
		add(icon);

		// Tip bar (bottom)
		tipText = new FlxText(0, FlxG.height - 26, FlxG.width,
			"UP / DOWN: Select  |  ENTER: Open Editor  |  ESC: Cancel", 16);
		tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.scrollFactor.set();
		add(tipText);

		// Collect songs exactly as FreeplayState does
		WeekData.reloadWeekFiles(false);

		for (i in 0...WeekData.weeksList.length)
		{
			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
					colors = [146, 113, 253];
				var meta = new CamSongMeta(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
				songs.push(meta);
			}
		}
		WeekData.loadTheFirstEnabledMod();

		if (songs.length == 0)
			songs.push(new CamSongMeta("tutorial", 0, "bf", 0xFF8659D3));

		// Build alphabet list
		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);
			songText.snapToPosition();
		}

		changeSelection();
		super.create();
	}

	// ── Update ────────────────────────────────────────────────────────────────
	override function update(elapsed:Float)
	{
		// Icon bob (same as freeplay)
		icon.y = FlxG.height - icon.height - 40;
		var mult:Float = FlxMath.lerp(1, icon.scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));
		icon.scale.set(mult, mult);

		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new editors.MasterEditorMenu());
		}

		if (controls.ACCEPT)
			confirmSong();

		super.update(elapsed);
	}

	override function beatHit()
	{
		super.beatHit();
		icon.scale.set(1.2, 1.2);
	}

	// ── Confirm / Load Song ───────────────────────────────────────────────────
	function confirmSong():Void
	{
		var meta:CamSongMeta = songs[curSelected];
		var songLowercase:String = Paths.formatToSongPath(meta.songName);

		// Restore the mod directory the song was found in
		Paths.currentModDirectory = meta.folder;

		// Try loading with difficulty fallback: hard -> normal -> no suffix
		var loaded:Bool = false;
		for (suffix in ["-hard", "-normal", ""])
		{
			try
			{
				PlayState.SONG = Song.loadFromJson(songLowercase + suffix, songLowercase);
				loaded = true;
				break;
			}
			catch (e:Dynamic) {}
		}

		if (!loaded)
		{
			trace("CameraSongSelectState: could not load song '" + meta.songName + "'");
			FlxG.sound.play(Paths.sound('missnote' + FlxG.random.int(1, 3)), 0.5);
			return;
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));

		// Stop menu music before switching
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;
		#if PRELOAD_ALL
		FreeplayState.destroyFreeplayVocals();
		#end

		LoadingState.loadAndSwitchState(new editors.CameraEditorState(), false);
	}

	// ── Change Selection ──────────────────────────────────────────────────────
	function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;
		if (curSelected < 0)  curSelected = songs.length - 1;
		if (curSelected >= songs.length) curSelected = 0;

		// Update alphabet positions
		var bullShit:Int = 0;
		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;
			item.alpha = (item.targetY == 0) ? 1.0 : 0.6;
		}

		// Update icon
		var meta:CamSongMeta = songs[curSelected];
		Paths.currentModDirectory = meta.folder;
		try { icon.changeIcon(meta.songCharacter); } catch (e:Dynamic) {}
		icon.alpha = 1;

		// Tween background colour
		if (meta.color != intendedColor)
		{
			if (colorTween != null) colorTween.cancel();
			intendedColor = meta.color;
			colorTween = FlxTween.color(bg, 0.5, bg.color, intendedColor);
		}
	}
}
