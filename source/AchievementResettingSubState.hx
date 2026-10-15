package;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import Achievements;

using StringTools;

class AchievementResettingSubState extends MusicBeatSubstate {
	public static var callback:Void->Void = null;

	var bg:FlxSprite;
	var alphabetArray:Array<Alphabet> = [];
	var yesSelection:Alphabet;
	var noSelection:Alphabet;
	var allAchievesResetSelection:Alphabet;

	var achieveName:String;
	var achieve:String;
	var achieveIcon:FlxSprite;

	var deletingElementText:Alphabet;
	
	var currentSelection:Int = 1; // Safety: default to 'No'

	public function new(achieve:String) {
		this.achieve = achieve;
		super();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var id:Int = Achievements.getAchievementIndex(achieve);
		var nameStr:String = "Unknown";
		if (id > -1) {
			nameStr = Achievements.achievementsStuff[id][0];
		}
		achieveName = nameStr;
		
		var infoText:Alphabet = new Alphabet(0, 100, "Reset this achievement(s)?", true);
		infoText.screenCenter(X);
		infoText.alpha = 0;
		alphabetArray.push(infoText);
		add(infoText);

		achieveIcon = new FlxSprite();
		if (id > -1) {
			achieveIcon.loadGraphic(Paths.image("achievements/" + achieve));
		} else {
			achieveIcon.loadGraphic(Paths.image("achievements/lockedachievement"));
		}
		achieveIcon.setGraphicSize(120, 120);
		achieveIcon.updateHitbox();
		achieveIcon.screenCenter(X);
		achieveIcon.y = infoText.y + 110;
		achieveIcon.alpha = 0;
		add(achieveIcon);

		var tooLong:Float = (achieveName.length > 18) ? 0.75 : 1.0;
		deletingElementText = new Alphabet(0, achieveIcon.y + 140, achieveName, true);
		deletingElementText.scaleX = tooLong;
		deletingElementText.screenCenter(X);
		deletingElementText.alpha = 0;
		alphabetArray.push(deletingElementText);
		add(deletingElementText);

		yesSelection = new Alphabet(0, deletingElementText.y + 130, "Yes", true);
		yesSelection.screenCenter(X);
		yesSelection.x -= 220;
		add(yesSelection);

		noSelection = new Alphabet(0, deletingElementText.y + 130, "No", true);
		noSelection.screenCenter(X);
		noSelection.x += 220;
		add(noSelection);

		allAchievesResetSelection = new Alphabet(0, yesSelection.y + 100, "Reset all achievements", true);
		allAchievesResetSelection.screenCenter(X);
		add(allAchievesResetSelection);

		updateOptions();
	}

	override function update(elapsed:Float) {
		bg.alpha += elapsed * 1.5;
		if(bg.alpha > 0.6) bg.alpha = 0.6;

		for (i in 0...alphabetArray.length) {
			var spr = alphabetArray[i];
			spr.alpha += elapsed * 2.5;
		}

		if (achieveIcon != null) {
			achieveIcon.alpha += elapsed * 2.5;
			if(achieveIcon.alpha > 1) achieveIcon.alpha = 1;
		}

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			if (currentSelection == 0 || currentSelection == 1) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 1);
				currentSelection = (currentSelection == 0) ? 1 : 0;
				updateOptions();
			}
		}

		if (controls.UI_DOWN_P) {
			if (currentSelection == 0 || currentSelection == 1) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 1);
				currentSelection = 2;
				updateOptions();
			}
		}

		if (controls.UI_UP_P) {
			if (currentSelection == 2) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 1);
				currentSelection = 1; // Default back to No
				updateOptions();
			}
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		} else if (controls.ACCEPT) {
			if (currentSelection == 0) { // Yes, reset this achievement
				Achievements.achievementsMap.remove(achieve);
				ClientPrefs.saveSettings();
				if (callback != null) callback();
			} else if (currentSelection == 2) { // Reset all achievements
				for (ach in Achievements.achievementsStuff) {
					Achievements.achievementsMap.remove(ach[2]);
				}
				ClientPrefs.saveSettings();
				if (callback != null) callback();
			}
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		}

		super.update(elapsed);
	}

	function updateOptions() {
		var scales:Array<Float> = [0.75, 1.0];
		var alphas:Array<Float> = [0.6, 1.25];

		var yesSelected:Int = (currentSelection == 0) ? 1 : 0;
		yesSelection.alpha = alphas[yesSelected];
		yesSelection.scale.set(scales[yesSelected], scales[yesSelected]);

		var noSelected:Int = (currentSelection == 1) ? 1 : 0;
		noSelection.alpha = alphas[noSelected];
		noSelection.scale.set(scales[noSelected], scales[noSelected]);

		var allSelected:Int = (currentSelection == 2) ? 1 : 0;
		allAchievesResetSelection.alpha = alphas[allSelected];
		allAchievesResetSelection.scale.set(scales[allSelected], scales[allSelected]);
	}
}