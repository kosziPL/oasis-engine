package options;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;
import openfl.Lib;

using StringTools;

class OasisSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Oasis Settings';
		rpcTitle = 'Oasis Settings Menu';

		// Rates and Combo on camGame (Moved from Visuals & UI)

		var option:Option = new Option('Judgement Camera',
            "if checked, combo and rates goes to Game Camera",
            'comboOnGameCam',
            'bool');
        addOption(option);

		var option:Option = new Option('Camera moves on arrow hit',
			'If checked, camera will move on arrow hit.',
			'camMove',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Camera moves strength',
			'How much the camera moves on arrow hit.\nHigher values will make the camera move more.',
			'camMoveStrength',
			'int',
			32);
		addOption(option);

		var option:Option = new Option('Show Rates Count',
			'If unchecked, right UI element (counter of every rate) won\'t be showed in game',
			'showingCounter',
			'bool');
		addOption(option);

		var option:Option = new Option('Oasis UI Layout',
			'If unchecked, UI will be shown in Legacy (Psych Engine) Layout',
			'legacyUILayout',
			'bool');
		addOption(option);
		super();
	}
}