package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class FreeplayWeekSubstate extends MusicBeatSubstate
{
	var weekNames:Array<String>;
	var curSelected:Int;
	var onSelect:Int->Void;
	
	var grpWeeks:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;

	public function new(weeks:Array<String>, current:Int, onSelectCallback:Int->Void)
	{
		super();
		this.weekNames = weeks;
		this.curSelected = current;
		this.onSelect = onSelectCallback;

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		add(bg);
		FlxTween.tween(bg, {alpha: 0.6}, 0.2, {ease: FlxEase.quartInOut});

		grpWeeks = new FlxTypedGroup<Alphabet>();
		add(grpWeeks);

		var title = new FlxText(0, 20, FlxG.width, "SELECT WEEK", 64);
		title.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 4;
		title.alpha = 0;
		add(title);
		FlxTween.tween(title, {alpha: 1}, 0.2, {ease: FlxEase.quartInOut});

		for (i in 0...weekNames.length)
		{
			var weekName:String = weekNames[i];
			var leWeek:WeekData = WeekData.weeksLoaded.get(weekName);
			var nameToUse = (leWeek != null) ? leWeek.weekName : weekName;

			var weekText:Alphabet = new Alphabet(0, (FlxG.height / 2) - 30, nameToUse, true);
			weekText.isMenuItem = true;
			weekText.targetY = i - curSelected;
			weekText.changeX = false;
			weekText.screenCenter(X);
			weekText.distancePerItem.y = 60;
			weekText.alpha = 0;
			grpWeeks.add(weekText);
			var targetAlpha:Float = (i == curSelected) ? 1.0 : 0.6;
			FlxTween.tween(weekText, {alpha: targetAlpha}, 0.2, {ease: FlxEase.quartInOut});
		}

		changeSelection(0);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			changeSelection(1);
		}

		if (controls.ACCEPT)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
			close();
			if (onSelect != null)
				onSelect(curSelected);
		}
		else if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			close();
		}
	}

	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, weekNames.length - 1);

		var bullShit:Int = 0;
		for (item in grpWeeks.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}
}
