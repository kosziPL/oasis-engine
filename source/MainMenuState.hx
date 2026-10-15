package;

#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import Achievements;
import editors.MasterEditorMenu;
import flixel.input.keyboard.FlxKey;

using StringTools;

class MainMenuState extends MusicBeatState
{
    public static var oasisEngineVersion:String = '0.2.8';
    public static var curSelected:Int = 0;
    public static var lastVerticalSelected:Int = 0;

    var menuItems:FlxTypedGroup<FlxSprite>;
    var menuCharacters:FlxTypedGroup<FlxSprite>;
    private var camGame:FlxCamera;
    private var camAchievement:FlxCamera;
    private var camStickers:FlxCamera;

    var optionShit:Array<String> = [
        'story_mode',
        'freeplay',
        'awards',
        'credits',
        'options'
    ];

    var magenta:FlxSprite;
    var selectedSomethin:Bool = false;
    var debugKeys:Array<FlxKey>;

    override function create()
    {
        #if MODS_ALLOWED
        Paths.pushGlobalMods();
        #end
        WeekData.loadTheFirstEnabledMod();

        #if desktop
        DiscordClient.changePresence("In the Menus", null);
        #end
        debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

        camGame = new FlxCamera();
        camAchievement = new FlxCamera();
        camAchievement.bgColor.alpha = 0;
        camStickers = new FlxCamera();
        camStickers.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camAchievement, false);
        FlxG.cameras.add(camStickers, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        transIn = null;
        transOut = null;

        persistentUpdate = persistentDraw = true;

        var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
        var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
        bg.scrollFactor.set(0, yScroll);
        bg.setGraphicSize(Std.int(bg.width * 1.175));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = ClientPrefs.globalAntialiasing;
        add(bg);

        magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
        magenta.scrollFactor.set(0, yScroll);
        magenta.setGraphicSize(Std.int(magenta.width * 1.175));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.visible = false;
        magenta.antialiasing = ClientPrefs.globalAntialiasing;
        magenta.color = 0xFFfd719b;
        add(magenta);
        
        menuCharacters = new FlxTypedGroup<FlxSprite>();
        add(menuCharacters);
        
        menuItems = new FlxTypedGroup<FlxSprite>();
        add(menuItems);

        for (i in 0...optionShit.length)
        {
            var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
            var menuItem:FlxSprite = new FlxSprite(0, (i * 130) + offset);
            
            menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
            menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
            menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
            menuItem.animation.play('idle');
            
            var scr:Float = (optionShit.length - 4) * 0.135;
            if(optionShit.length < 6) scr = 0;
            menuItem.scrollFactor.set(0, scr);
            menuItem.scale.set(0.7, 0.7);
            menuItem.updateHitbox();
            
            // POZYCJONOWANIE
            menuItem.x = 100;

            menuItem.ID = i;
            menuItems.add(menuItem);
            menuItem.antialiasing = ClientPrefs.globalAntialiasing;
        }

        // Cool version texts
        var versionShit:FlxText = new FlxText(12, FlxG.height - 44, 0, "Oasis Engine v" + oasisEngineVersion, 12);
        versionShit.scrollFactor.set();
        versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(versionShit);
        var versionShit2:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
        versionShit2.scrollFactor.set();
        versionShit2.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(versionShit2);

        var modsText:FlxText = new FlxText(FlxG.width - 12, FlxG.height - 24, 0, "Press TAB to manage mods");
        modsText.scrollFactor.set();
        modsText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        modsText.x = FlxG.width - modsText.width - 12;
        add(modsText);

        changeItem();

        #if ACHIEVEMENTS_ALLOWED
        Achievements.loadAchievements();
        var currentDate = Date.now();
        if (currentDate.getDay() == 5 && currentDate.getHours() >= 18
            && !Achievements.isAchievementUnlocked('friday_night_play'))
        {
            Achievements.unlockAchievement('friday_night_play');
            add(new AchievementObject('friday_night_play', camAchievement));
            ClientPrefs.saveSettings();
        }
        #end

        super.create();
    }

    override function update(elapsed:Float)
    {
        if (FlxG.sound.music.volume < 0.8)
            FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

        if (!selectedSomethin)
        {
            // NAWIGACJA
            if (controls.UI_UP_P) {
                FlxG.sound.play(Paths.sound('scrollMenu'));
                changeItem(-1);
            }
            if (controls.UI_DOWN_P) {
                FlxG.sound.play(Paths.sound('scrollMenu'));
                changeItem(1);
            }

            if (controls.BACK)
            {
                selectedSomethin = true;
                FlxG.sound.play(Paths.sound('cancelMenu'));
                MusicBeatState.switchState(new TitleState());
            }

            if (controls.ACCEPT)
            {
                selectedSomethin = true;
                FlxG.sound.play(Paths.sound('confirmMenu'));

                if(ClientPrefs.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

                menuItems.forEach(function(spr:FlxSprite)
                {
                    if (curSelected != spr.ID)
                    {
                        FlxTween.tween(spr, {alpha: 0}, 0.4, {
                            ease: FlxEase.quadOut,
                            onComplete: function(twn:FlxTween) { spr.kill(); }
                        });
                    }
                    else
                    {
                        FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
                        {
                            var daChoice:String = optionShit[curSelected];
                            switch (daChoice)
                            {
                                case 'story_mode': MusicBeatState.switchState(new StoryMenuState());
                                case 'freeplay':   MusicBeatState.switchState(new FreeplayState());
                                case 'awards':     MusicBeatState.switchState(new AchievementsMenuState());
                                case 'credits':    MusicBeatState.switchState(new CreditsState());
                                case 'options':    LoadingState.loadAndSwitchState(new options.OptionsState());
                            }
                        });
                    }
                });
            }
            #if desktop
            else if (FlxG.keys.anyJustPressed(debugKeys))
            {
                selectedSomethin = true;
                MusicBeatState.switchState(new MasterEditorMenu());
            }
            #end
            else if (FlxG.keys.justPressed.TAB)
            {
                selectedSomethin = true;
                MusicBeatState.switchState(new ModsMenuState());
            }
        }

        super.update(elapsed);
    }

    function changeBgColor(option:String) {
        var newColor:FlxColor;
        switch (option) {
            case 'story_mode': newColor = 0xff00a2ff;
            case 'freeplay':   newColor = 0xffff9900;
            case 'awards':     newColor = 0xffe92e2e;
            case 'credits':    newColor = 0xff00d4ff;
            case 'options':    newColor = 0xffff6ae6;
            default:           newColor = 0xFFfd719b;
        }
        FlxTween.color(magenta, 0.5, magenta.color, newColor);
    }

    function changeItem(huh:Int = 0)
    {
        curSelected += huh;
        if (curSelected >= optionShit.length) curSelected = 0;
        if (curSelected < 0) curSelected = optionShit.length - 1;

        menuItems.forEach(function(spr:FlxSprite)
        {
            var midY = spr.y + spr.height / 2;
            
            spr.animation.play('idle');
            spr.scale.set(0.7, 0.7);

            if (spr.ID == curSelected)
            {
                spr.animation.play('selected');
                spr.scale.set(0.85, 0.85);
            }
            
            spr.updateHitbox();
            spr.y = midY - spr.height / 2;
        });

        changeBgColor(optionShit[curSelected]);
    }
}