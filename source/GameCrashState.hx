package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import editors.ChartingState;

class GameCrashState extends MusicBeatState
{
	var error:String = "";

	public function new(error:String)
	{
		super();
		this.error = error;
	}

	override function create()
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var titleText:FlxText = new FlxText(0, 80, FlxG.width, "CRITICAL SONG LOADING ERROR!", 32);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		var errorText:FlxText = new FlxText(50, 180, FlxG.width - 100, "Error details:\n" + error, 18);
		errorText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		errorText.borderSize = 1.5;
		add(errorText);

		var infoText:FlxText = new FlxText(0, FlxG.height - 150, FlxG.width, "Press ENTER to open the Chart Editor (Charting State)\nPress ESCAPE to return to the Menu", 20);
		infoText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 2;
		add(infoText);

		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.ACCEPT)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			MusicBeatState.switchState(new ChartingState());
		}
		else if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new FreeplayState());
		}
	}
}
