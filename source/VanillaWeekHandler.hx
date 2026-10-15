package;
import CutsceneHandler;
import Note.EventNote;
import Achievements;
import flixel.util.FlxSort;
import PhillyGlow.PhillyGlowParticle;
import PhillyGlow.PhillyGlowGradient;

import animateatlas.AtlasFrameMaker;

import PhillyGlow;

using StringTools;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class VanillaWeekHandler {
    
    public var game:PlayState;
	public var trainMoving:Bool = false;
	public var trainFrameTiming:Float = 0;
	public var trainCars:Int = 8;
	public var trainFinishing:Bool = false;
	public var trainCooldown:Int = 0;
	public var tankX:Float = 400;

	public var carTimer:flixel.util.FlxTimer;



	public var fastCarCanDrive:Bool = true;


	public var phillyGlowGradient:PhillyGlowGradient;
	public var blammedLightsBlack:flixel.FlxSprite;
	public var phillyWindowEvent:flixel.util.FlxTimer;
	public var phillyGlowParticles:flixel.group.FlxGroup.FlxTypedGroup<PhillyGlowParticle>;
	public var bgGhouls:BGSprite;
	public var heyTimer:Float = 0;
	public var halloweenBG:BGSprite;
	public var halloweenWhite:flixel.FlxSprite;

    
    // Philly
    public var phillyCityLights:FlxTypedGroup<FlxSprite>;
    public var phillyTrain:BGSprite;
    public var phillyStreet:BGSprite;
    public var trainSound:FlxSound;
    public var curLight:Int = 0;
    public var phillyLightsColors:Array<FlxColor> = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];
    public var phillyWindow:BGSprite;

    // Limo
    public var limoKillingState:Int = 0;
    public var limo:BGSprite;
    public var limoMetalPole:BGSprite;
    public var limoLight:BGSprite;
    public var limoCorpse:BGSprite;
    public var limoCorpseTwo:BGSprite;
    public var bgLimo:BGSprite;
    public var grpLimoParticles:FlxTypedGroup<BGSprite>;
    public var grpLimoDancers:FlxTypedGroup<BackgroundDancer>;
    public var fastCar:BGSprite;
    public var limoSpeed:Float = 0;

    // Mall
    public var upperBoppers:BGSprite;
    public var bottomBoppers:BGSprite;
    public var santa:BGSprite;

    // School
    public var bgGirls:BackgroundGirls;

    // Tank
    public var tankWatchtower:BGSprite;
    public var tankGround:BGSprite;
    public var tankmanRun:FlxTypedGroup<FlxSprite>;
    public var foregroundSprites:FlxTypedGroup<BGSprite>;
    public var tankAngle:Float = FlxG.random.int(-90, 45);
    public var tankSpeed:Float = FlxG.random.float(5, 7);

    public function new(game:PlayState) {
        this.game = game;
    }

    public function initStage(curStage:String):Void {
        switch (curStage)
        {
            case 'stage':
                var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
                game.add(bg);
                var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
                stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
                stageFront.updateHitbox();
                game.add(stageFront);
                if (!ClientPrefs.lowQuality) {
                    var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
                    stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
                    stageCurtains.updateHitbox();
                    game.add(stageCurtains);
                }

            case 'spooky':
                halloweenBG = new BGSprite('halloween_bg', -200, -100, 1, 1, ['halloweem bg0', 'halloweem bg lightning strike']);
                halloweenBG.animation.play('halloweem bg0');
                game.add(halloweenBG);
                halloweenWhite = new flixel.FlxSprite(-800, -400);
                halloweenWhite.makeGraphic(Std.int(flixel.FlxG.width * 2), Std.int(flixel.FlxG.height * 2), flixel.util.FlxColor.WHITE);
                halloweenWhite.alpha = 0;
                halloweenWhite.blend = ADD;
                game.add(halloweenWhite);

            case 'philly':
                if (!ClientPrefs.lowQuality) {
                    var bg:BGSprite = new BGSprite('philly/sky', -100, 0, 0.1, 0.1);
                    game.add(bg);
                }
                var city:BGSprite = new BGSprite('philly/city', -10, 0, 0.3, 0.3);
                city.setGraphicSize(Std.int(city.width * 0.85)); city.updateHitbox();
                game.add(city);
                phillyWindow = new BGSprite('philly/window', city.x, city.y, 0.3, 0.3);
                phillyWindow.setGraphicSize(Std.int(phillyWindow.width * 0.85)); phillyWindow.updateHitbox();
                game.add(phillyWindow); phillyWindow.alpha = 0;
                if (!ClientPrefs.lowQuality) {
                    var streetBehind:BGSprite = new BGSprite('philly/behindTrain', -40, 50);
                    game.add(streetBehind);
                }
                phillyTrain = new BGSprite('philly/train', 2000, 360); game.add(phillyTrain);
                trainSound = new FlxSound().loadEmbedded(Paths.sound('train_passes')); FlxG.sound.list.add(trainSound);
                phillyStreet = new BGSprite('philly/street', -40, 50); game.add(phillyStreet);

            case 'limo':
                var skyBG:BGSprite = new BGSprite('limo/limoSunset', -120, -50, 0.1, 0.1); game.add(skyBG);
                if (!ClientPrefs.lowQuality) {
                    limoMetalPole = new BGSprite('gore/metalPole', -500, 220, 0.4, 0.4); game.add(limoMetalPole);
                    bgLimo = new BGSprite('limo/bgLimo', -150, 480, 0.4, 0.4, ['background limo pink'], true); game.add(bgLimo);
                    limoCorpse = new BGSprite('gore/noooooo', -500, limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true); game.add(limoCorpse); limoCorpse.visible = false;
                    limoCorpseTwo = new BGSprite('gore/noooooo', -500, limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true); game.add(limoCorpseTwo); limoCorpseTwo.visible = false;
                    grpLimoDancers = new FlxTypedGroup<BackgroundDancer>(); game.add(grpLimoDancers);
                    for (i in 0...5) {
                        var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + 170, bgLimo.y - 400); dancer.scrollFactor.set(0.4, 0.4);
                        grpLimoDancers.add(dancer);
                    }
                    limoLight = new BGSprite('gore/coldHeartKiller', limoMetalPole.x - 180, limoMetalPole.y - 80, 0.4, 0.4); game.add(limoLight);
                    grpLimoParticles = new FlxTypedGroup<BGSprite>(); game.add(grpLimoParticles);
                    var particle:BGSprite = new BGSprite('gore/stupidBlood', -400, -400, 0.4, 0.4, ['blood'], false); particle.alpha = 0.01;
                    grpLimoParticles.add(particle);
                }
                limo = new BGSprite('limo/limoDrive', -120, 550, 1, 1, ['Limo stage'], true);
                fastCar = new BGSprite('limo/fastCarLol', -300, 160); fastCar.active = true;

            case 'mall':
                var bg:BGSprite = new BGSprite('christmas/bgWalls', -1000, -500, 0.2, 0.2);
                bg.setGraphicSize(Std.int(bg.width * 0.8)); bg.updateHitbox(); game.add(bg);
                if (!ClientPrefs.lowQuality) {
                    upperBoppers = new BGSprite('christmas/upperBop', -240, -90, 0.33, 0.33, ['Upper Crowd Bob']);
                    upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85)); upperBoppers.updateHitbox(); game.add(upperBoppers);
                    var bgEscalator:BGSprite = new BGSprite('christmas/bgEscalator', -1100, -600, 0.3, 0.3);
                    bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9)); bgEscalator.updateHitbox(); game.add(bgEscalator);
                }
                var tree:BGSprite = new BGSprite('christmas/christmasTree', 370, -250, 0.40, 0.40); game.add(tree);
                bottomBoppers = new BGSprite('christmas/bottomBop', -300, 140, 0.9, 0.9, ['Bottom Level Boppers Idle']);
                bottomBoppers.animation.addByPrefix('hey', 'Bottom Level Boppers HEY', 24, false);
                bottomBoppers.setGraphicSize(Std.int(bottomBoppers.width * 1)); bottomBoppers.updateHitbox(); game.add(bottomBoppers);
                var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -600, 700); game.add(fgSnow);
                santa = new BGSprite('christmas/santa', -840, 150, 1, 1, ['santa idle in fear']); game.add(santa);

            case 'mallEvil':
                var bg:BGSprite = new BGSprite('christmas/evilBG', -400, -500, 0.2, 0.2);
                bg.setGraphicSize(Std.int(bg.width * 0.8)); bg.updateHitbox(); game.add(bg);
                var evilTree:BGSprite = new BGSprite('christmas/evilTree', 300, -300, 0.2, 0.2); game.add(evilTree);
                var evilSnow:BGSprite = new BGSprite('christmas/evilSnow', -200, 700); game.add(evilSnow);

            case 'school':
                var bgSky:BGSprite = new BGSprite('weeb/weebSky', 0, 0, 0.1, 0.1); game.add(bgSky); bgSky.antialiasing = false;
                var repositionShit = -200;
                var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionShit, 0, 0.6, 0.90); game.add(bgSchool); bgSchool.antialiasing = false;
                var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionShit, 0, 0.95, 0.95); game.add(bgStreet); bgStreet.antialiasing = false;
                var widShit = Std.int(bgSky.width * 6);
                if (!ClientPrefs.lowQuality) {
                    var fgTrees:BGSprite = new BGSprite('weeb/weebTreesBack', repositionShit + 170, 130, 0.9, 0.9);
                    fgTrees.setGraphicSize(Std.int(widShit * 0.8)); fgTrees.updateHitbox(); game.add(fgTrees); fgTrees.antialiasing = false;
                }
                var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800);
                bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
                bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
                bgTrees.animation.play('treeLoop'); bgTrees.scrollFactor.set(0.85, 0.85); game.add(bgTrees); bgTrees.antialiasing = false;
                if (!ClientPrefs.lowQuality) {
                    var treeLeaves:BGSprite = new BGSprite('weeb/petals', repositionShit, -40, 0.85, 0.85, ['PETALS ALL'], true);
                    treeLeaves.setGraphicSize(widShit); treeLeaves.updateHitbox(); game.add(treeLeaves); treeLeaves.antialiasing = false;
                }
                bgSky.setGraphicSize(widShit); bgSchool.setGraphicSize(widShit); bgStreet.setGraphicSize(widShit); bgTrees.setGraphicSize(Std.int(widShit * 1.4));
                bgSky.updateHitbox(); bgSchool.updateHitbox(); bgStreet.updateHitbox(); bgTrees.updateHitbox();
                if (!ClientPrefs.lowQuality) {
                    bgGirls = new BackgroundGirls(-100, 190); bgGirls.scrollFactor.set(0.9, 0.9);
                    bgGirls.setGraphicSize(Std.int(bgGirls.width * PlayState.daPixelZoom)); bgGirls.updateHitbox(); game.add(bgGirls);
                }

            case 'schoolEvil':
                var posX = 400;
                var posY = 200;
                if (!ClientPrefs.lowQuality) {
                    var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool', posX, posY, 0.8, 0.9, ['background 2'], true);
                    bg.scale.set(6, 6);
                    bg.antialiasing = false;
                    game.add(bg);

                    bgGhouls = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
                    bgGhouls.setGraphicSize(Std.int(bgGhouls.width * PlayState.daPixelZoom));
                    bgGhouls.updateHitbox();
                    bgGhouls.visible = false;
                    bgGhouls.antialiasing = false;
                    bgGhouls.animation.finishCallback = function(name:String) {
                        bgGhouls.visible = false;
                    };
                    game.add(bgGhouls);
                } else {
                    var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool_low', posX, posY, 0.8, 0.9);
                    bg.scale.set(6, 6);
                    bg.antialiasing = false;
                    game.add(bg);
                }

            case 'tank':
                var sky:BGSprite = new BGSprite('tankSky', -400, -400, 0, 0); game.add(sky);
                if (!ClientPrefs.lowQuality) {
                    var clouds:BGSprite = new BGSprite('tankClouds', FlxG.random.int(-700, -100), FlxG.random.int(-20, 20), 0.1, 0.1);
                    clouds.active = true; clouds.velocity.x = FlxG.random.float(5, 15); game.add(clouds);
                    var mountains:BGSprite = new BGSprite('tankMountains', -300, -20, 0.2, 0.2);
                    mountains.setGraphicSize(Std.int(1.2 * mountains.width)); mountains.updateHitbox(); game.add(mountains);
                    var buildings:BGSprite = new BGSprite('tankBuildings', -200, 0, 0.3, 0.3);
                    buildings.setGraphicSize(Std.int(1.1 * buildings.width)); buildings.updateHitbox(); game.add(buildings);
                }
                var ruins:BGSprite = new BGSprite('tankRuins', -200, 0, .35, .35);
                ruins.setGraphicSize(Std.int(1.1 * ruins.width)); ruins.updateHitbox(); game.add(ruins);
                if (!ClientPrefs.lowQuality) {
                    var smokeLeft:BGSprite = new BGSprite('smokeLeft', -200, -100, 0.4, 0.4, ['SmokeBlurLeft'], true); game.add(smokeLeft);
                    var smokeRight:BGSprite = new BGSprite('smokeRight', 1100, -100, 0.4, 0.4, ['SmokeRight'], true); game.add(smokeRight);
                    tankWatchtower = new BGSprite('tankWatchtower', 100, 50, 0.5, 0.5, ['watchtower gradient color']); game.add(tankWatchtower);
                }
                tankGround = new BGSprite('tankRolling', 300, 300, 0.5, 0.5, ['BG tank w lighting'], true); game.add(tankGround);
                
                var tankGroundReal:BGSprite = new BGSprite('tankGround', -420, -150);
                tankGroundReal.setGraphicSize(Std.int(1.15 * tankGroundReal.width)); tankGroundReal.updateHitbox(); game.add(tankGroundReal);

                tankmanRun = new flixel.group.FlxGroup.FlxTypedGroup<FlxSprite>();
                game.add(tankmanRun);

                foregroundSprites = new flixel.group.FlxGroup.FlxTypedGroup<BGSprite>();
                var tank0 = new BGSprite('tank0', -500, 650, 1.7, 1.5, ['fg']); foregroundSprites.add(tank0);
                if (!ClientPrefs.lowQuality) {
                    var tank1 = new BGSprite('tank1', -300, 750, 2, 0.2, ['fg']); foregroundSprites.add(tank1);
                    var tank2 = new BGSprite('tank2', 450, 940, 1.5, 1.5, ['foreground']); foregroundSprites.add(tank2);
                    var tank4 = new BGSprite('tank4', 1300, 900, 1.5, 1.5, ['fg']); foregroundSprites.add(tank4);
                    var tank5 = new BGSprite('tank5', 1620, 700, 1.5, 1.5, ['fg']); foregroundSprites.add(tank5);
                    var tank3 = new BGSprite('tank3', 1300, 1200, 3.5, 2.5, ['fg']); foregroundSprites.add(tank3);
                }
        }
    }

    public function update(elapsed:Float):Void {
        if (heyTimer > 0) {
            heyTimer -= elapsed * game.playbackRate;
            if (heyTimer <= 0) {
                heyTimer = 0;
            }
        }
        // Limo, train update logic
    }

    public function beatHit(curStage:String, curBeat:Int):Void {
        // Dance logic
    }
    
    // Cutscenes
    
    
    

	// --- EKSTRAKCJA FUNKCJI Z PLAYSTATE ---

	public function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}



	public function fastCarDrive()
	{
		// trace('Car drive');
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			resetFastCar();
			carTimer = null;
		});
	}

	public function trainStart():Void
	{
		trainMoving = true;
		if (!trainSound.playing)
			trainSound.play(true);
	}

	var startedMoving:Bool = false;

	function updateTrainPos():Void
	{
		if (trainSound.time >= 4700)
		{
			startedMoving = true;
			if (game.gf != null)
			{
				game.gf.playAnim('hairBlow');
				game.gf.specialAnim = true;
			}
		}

		if (startedMoving)
		{
			phillyTrain.x -= 400;

			if (phillyTrain.x < -2000 && !trainFinishing)
			{
				phillyTrain.x = -1150;
				trainCars -= 1;

				if (trainCars <= 0)
					trainFinishing = true;
			}

			if (phillyTrain.x < -4000 && trainFinishing)
				trainReset();
		}
	}

	function trainReset():Void
	{
		if (game.gf != null)
		{
			game.gf.danced = false; // Sets head to the correct position once the animation ends
			game.gf.playAnim('hairFall');
			game.gf.specialAnim = true;
		}
		phillyTrain.x = FlxG.width + 200;
		trainMoving = false;
		// trainSound.stop();
		// trainSound.time = 0;
		trainCars = 8;
		trainFinishing = false;
		startedMoving = false;
	}

	public function lightningStrikeShit():Void
	{
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		if (!ClientPrefs.lowQuality)
			halloweenBG.animation.play('halloweem bg lightning strike');

		game.lightningStrikeBeat = game.getCurBeat();
		game.lightningOffset = FlxG.random.int(8, 24);

		if (game.boyfriend.animOffsets.exists('scared'))
		{
			game.boyfriend.playAnim('scared', true);
		}

		if (game.gf != null && game.gf.animOffsets.exists('scared'))
		{
			game.gf.playAnim('scared', true);
		}

		if (ClientPrefs.camZooms)
		{
			FlxG.camera.zoom += 0.015;
			game.camHUD.zoom += 0.03;

			if (!game.camZooming)
			{ // Just a way for preventing it to be permanently zoomed until Skid & Pump hits a note
				FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom}, 0.5);
				FlxTween.tween(game.camHUD, {zoom: 1}, 0.5);
			}
		}

		if (ClientPrefs.flashing)
		{
			halloweenWhite.alpha = 0.4;
			FlxTween.tween(halloweenWhite, {alpha: 0.5}, 0.075);
			FlxTween.tween(halloweenWhite, {alpha: 0}, 0.25, {startDelay: 0.15});
		}
	}

	public function killHenchmen():Void
	{
		if (!ClientPrefs.lowQuality && ClientPrefs.violence && PlayState.curStage == 'limo')
		{
			if (limoKillingState < 1)
			{
				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpseTwo.visible = false;
				limoKillingState = 1;

				#if ACHIEVEMENTS_ALLOWED
				Achievements.henchmenDeath++;
				FlxG.save.data.henchmenDeath = Achievements.henchmenDeath;
				var achieve:String = game.checkForAchievement(['roadkill_enthusiast']);
				if (achieve != null)
				{
					game.startAchievement(achieve);
				}
				else
				{
					FlxG.save.flush();
				}
				FlxG.log.add('Deaths: ' + Achievements.henchmenDeath);
				#end
			}
		}
	}

	function resetLimoKill():Void
	{
		if (PlayState.curStage == 'limo')
		{
			limoMetalPole.x = -500;
			limoMetalPole.visible = false;
			limoLight.x = -500;
			limoLight.visible = false;
			limoCorpse.x = -500;
			limoCorpse.visible = false;
			limoCorpseTwo.x = -500;
			limoCorpseTwo.visible = false;
		}
	}


	function moveTank(?elapsed:Float = 0):Void
	{
		if (!game.inCutscene)
		{
			tankAngle += elapsed * tankSpeed;
			tankGround.angle = tankAngle - 90 + 15;
			tankGround.x = tankX + 1500 * Math.cos(Math.PI / 180 * (1 * tankAngle + 180));
			tankGround.y = 1300 + 1100 * Math.sin(Math.PI / 180 * (1 * tankAngle + 180));
		}
	}


	// --- EKSTRAKCJA CUTSCENEK Z PLAYSTATE ---
	public function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		game.inCutscene = true;
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		game.add(black);

		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();

		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.getSparrowAtlas('weeb/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();
		senpaiEvil.x += 300;

		var songName:String = Paths.formatToSongPath(PlayState.SONG.song);
		if (songName == 'roses' || songName == 'thorns')
		{
			game.remove(black);

			if (songName == 'thorns')
			{
				game.add(red);
				game.camHUD.visible = false;
			}
		}

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;

			if (black.alpha > 0)
			{
				tmr.reset(0.3);
			}
			else
			{
				if (dialogueBox != null)
				{
					if (Paths.formatToSongPath(PlayState.SONG.song) == 'thorns')
					{
						game.add(senpaiEvil);
						senpaiEvil.alpha = 0;
						new FlxTimer().start(0.3, function(swagTimer:FlxTimer)
						{
							senpaiEvil.alpha += 0.15;
							if (senpaiEvil.alpha < 1)
							{
								swagTimer.reset();
							}
							else
							{
								senpaiEvil.animation.play('idle');
								FlxG.sound.play(Paths.sound('Senpai_Dies'), 1, false, null, true, function()
								{
									game.remove(senpaiEvil);
									game.remove(red);
									FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
									{
										game.add(dialogueBox);
										game.camHUD.visible = true;
									}, true);
								});
								new FlxTimer().start(3.2, function(deadTime:FlxTimer)
								{
									FlxG.camera.fade(FlxColor.WHITE, 1.6, false);
								});
							}
						});
					}
					else
					{
						game.add(dialogueBox);
					}
				}
				else
					game.startCountdown();

				game.remove(black);
			}
		});
	}

	public function tankIntro()
	{
		var cutsceneHandler:CutsceneHandler = new CutsceneHandler();

		var songName:String = Paths.formatToSongPath(PlayState.SONG.song);
		game.dadGroup.alpha = 0.00001;
		game.camHUD.visible = false;
		// game.inCutscene = true; //this would stop the camera movement, oops

		var tankman:FlxSprite = new FlxSprite(-20, 320);
		tankman.frames = Paths.getSparrowAtlas('cutscenes/' + songName);
		if (tankman.frames == null)
		{
			game.startCountdown();
			return;
		}
		tankman.antialiasing = ClientPrefs.globalAntialiasing;
		game.addBehindDad(tankman);
		cutsceneHandler.push(tankman);

		var tankman2:FlxSprite = new FlxSprite(16, 312);
		tankman2.antialiasing = ClientPrefs.globalAntialiasing;
		tankman2.alpha = 0.000001;
		cutsceneHandler.push(tankman2);
		var gfDance:FlxSprite = new FlxSprite(game.gf.x - 107, game.gf.y + 140);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(gfDance);
		var gfCutscene:FlxSprite = new FlxSprite(game.gf.x - 104, game.gf.y + 122);
		gfCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(gfCutscene);
		var picoCutscene:FlxSprite = new FlxSprite(game.gf.x - 849, game.gf.y - 264);
		picoCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(picoCutscene);
		var boyfriendCutscene:FlxSprite = new FlxSprite(game.boyfriend.x + 5, game.boyfriend.y + 20);
		boyfriendCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(boyfriendCutscene);

		cutsceneHandler.finishCallback = function()
		{
			var timeForStuff:Float = Conductor.crochet / 1000 * 4.5;
			FlxG.sound.music.fadeOut(timeForStuff);
			FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom}, timeForStuff, {ease: FlxEase.quadInOut});
			game.moveCamera(true);
			game.startCountdown();

			game.dadGroup.alpha = 1;
			game.camHUD.visible = true;
			game.boyfriend.animation.finishCallback = null;
			game.gf.animation.finishCallback = null;
			game.gf.dance();
		};

		game.snapCamFollowToPos(game.dad.x + 280, game.dad.y + 170);
		switch (songName)
		{
			case 'ugh':
				cutsceneHandler.endTime = 12;
				cutsceneHandler.music = 'DISTORTO';
				game.precacheList.set('wellWellWell', 'sound');
				game.precacheList.set('killYou', 'sound');
				game.precacheList.set('bfBeep', 'sound');

				var wellWellWell:FlxSound = new FlxSound().loadEmbedded(Paths.sound('wellWellWell'));
				FlxG.sound.list.add(wellWellWell);

				tankman.animation.addByPrefix('wellWell', 'TANK TALK 1 P1', 24, false);
				tankman.animation.addByPrefix('killYou', 'TANK TALK 1 P2', 24, false);
				tankman.animation.play('wellWell', true);
				FlxG.camera.zoom *= 1.2;

				// Well well well, what do we got here?
				cutsceneHandler.timer(0.1, function()
				{
					wellWellWell.play(true);
				});

				// Move camera to BF
				cutsceneHandler.timer(3, function()
				{
					game.camFollow.x += 750;
					game.camFollow.y += 100;
				});

				// Beep!
				cutsceneHandler.timer(4.5, function()
				{
					game.boyfriend.playAnim('singUP', true);
					game.boyfriend.specialAnim = true;
					FlxG.sound.play(Paths.sound('bfBeep'));
				});

				// Move camera to Tankman
				cutsceneHandler.timer(6, function()
				{
					game.camFollow.x -= 750;
					game.camFollow.y -= 100;

					// We should just kill you but... what the hell, it's been a boring day... let's see what you've got!
					tankman.animation.play('killYou', true);
					FlxG.sound.play(Paths.sound('killYou'));
				});

			case 'guns':
				cutsceneHandler.endTime = 11.5;
				cutsceneHandler.music = 'DISTORTO';
				tankman.x += 40;
				tankman.y += 10;
				game.precacheList.set('tankSong2', 'sound');

				var tightBars:FlxSound = new FlxSound().loadEmbedded(Paths.sound('tankSong2'));
				FlxG.sound.list.add(tightBars);

				tankman.animation.addByPrefix('tightBars', 'TANK TALK 2', 24, false);
				tankman.animation.play('tightBars', true);
				game.boyfriend.animation.curAnim.finish();

				cutsceneHandler.onStart = function()
				{
					tightBars.play(true);
					FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom * 1.2}, 4, {ease: FlxEase.quadInOut});
					FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom * 1.2 * 1.2}, 0.5, {ease: FlxEase.quadInOut, startDelay: 4});
					FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom * 1.2}, 1, {ease: FlxEase.quadInOut, startDelay: 4.5});
				};

				cutsceneHandler.timer(4, function()
				{
					game.gf.playAnim('sad', true);
					game.gf.animation.finishCallback = function(name:String)
					{
						game.gf.playAnim('sad', true);
					};
				});

			case 'stress':
				cutsceneHandler.endTime = 35.5;
				tankman.x -= 54;
				tankman.y -= 14;
				game.gfGroup.alpha = 0.00001;
				game.boyfriendGroup.alpha = 0.00001;
				game.snapCamFollowToPos(game.dad.x + 400, game.dad.y + 170);
				FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2}, 1, {ease: FlxEase.quadInOut});
				foregroundSprites.forEach(function(spr:BGSprite)
				{
					spr.y += 100;
				});
				game.precacheList.set('stressCutscene', 'sound');

				tankman2.frames = Paths.getSparrowAtlas('cutscenes/stress2');
				game.addBehindDad(tankman2);

				if (!ClientPrefs.lowQuality)
				{
					gfDance.frames = Paths.getSparrowAtlas('characters/gfTankmen');
					gfDance.animation.addByPrefix('dance', 'GF Dancing at Gunpoint', 24, true);
					gfDance.animation.play('dance', true);
					game.addBehindGF(gfDance);
				}

				gfCutscene.frames = Paths.getSparrowAtlas('cutscenes/stressGF');
				gfCutscene.animation.addByPrefix('dieBitch', 'GF STARTS TO TURN PART 1', 24, false);
				gfCutscene.animation.addByPrefix('getRektLmao', 'GF STARTS TO TURN PART 2', 24, false);
				gfCutscene.animation.play('dieBitch', true);
				gfCutscene.animation.pause();
				game.addBehindGF(gfCutscene);
				if (!ClientPrefs.lowQuality)
				{
					gfCutscene.alpha = 0.00001;
				}

				picoCutscene.frames = AtlasFrameMaker.construct('cutscenes/stressPico');
				picoCutscene.animation.addByPrefix('anim', 'Pico Badass', 24, false);
				game.addBehindGF(picoCutscene);
				picoCutscene.alpha = 0.00001;

				boyfriendCutscene.frames = Paths.getSparrowAtlas('characters/BOYFRIEND');
				boyfriendCutscene.animation.addByPrefix('idle', 'BF idle dance', 24, false);
				boyfriendCutscene.animation.play('idle', true);
				boyfriendCutscene.animation.curAnim.finish();
				game.addBehindBF(boyfriendCutscene);

				var cutsceneSnd:FlxSound = new FlxSound().loadEmbedded(Paths.sound('stressCutscene'));
				FlxG.sound.list.add(cutsceneSnd);

				tankman.animation.addByPrefix('godEffingDamnIt', 'TANK TALK 3', 24, false);
				tankman.animation.play('godEffingDamnIt', true);

				var calledTimes:Int = 0;
				var zoomBack:Void->Void = function()
				{
					var camPosX:Float = 630;
					var camPosY:Float = 425;
					game.snapCamFollowToPos(camPosX, camPosY);
					game.camFollowPos.setPosition(camPosX, camPosY);
					FlxG.camera.zoom = 0.8;
					game.cameraSpeed = 1;

					calledTimes++;
					if (calledTimes > 1)
					{
						foregroundSprites.forEach(function(spr:BGSprite)
						{
							spr.y -= 100;
						});
					}
				}

				cutsceneHandler.onStart = function()
				{
					cutsceneSnd.play(true);
				};

				cutsceneHandler.timer(15.2, function()
				{
					FlxTween.tween(game.camFollow, {x: 650, y: 300}, 1, {ease: FlxEase.sineOut});
					FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 2.25, {ease: FlxEase.quadInOut});

					gfDance.visible = false;
					gfCutscene.alpha = 1;
					gfCutscene.animation.play('dieBitch', true);
					gfCutscene.animation.finishCallback = function(name:String)
					{
						if (name == 'dieBitch') // Next part
						{
							gfCutscene.animation.play('getRektLmao', true);
							gfCutscene.offset.set(224, 445);
						}
						else
						{
							gfCutscene.visible = false;
							picoCutscene.alpha = 1;
							picoCutscene.animation.play('anim', true);

							game.boyfriendGroup.alpha = 1;
							boyfriendCutscene.visible = false;
							game.boyfriend.playAnim('bfCatch', true);
							game.boyfriend.animation.finishCallback = function(name:String)
							{
								if (name != 'idle')
								{
									game.boyfriend.playAnim('idle', true);
									game.boyfriend.animation.curAnim.finish(); // Instantly goes to last frame
								}
							};

							picoCutscene.animation.finishCallback = function(name:String)
							{
								picoCutscene.visible = false;
								game.gfGroup.alpha = 1;
								picoCutscene.animation.finishCallback = null;
							};
							gfCutscene.animation.finishCallback = null;
						}
					};
				});

				cutsceneHandler.timer(17.5, function()
				{
					zoomBack();
				});

				cutsceneHandler.timer(19.5, function()
				{
					tankman2.animation.addByPrefix('lookWhoItIs', 'TANK TALK 3', 24, false);
					tankman2.animation.play('lookWhoItIs', true);
					tankman2.alpha = 1;
					tankman.visible = false;
				});

				cutsceneHandler.timer(20, function()
				{
					game.snapCamFollowToPos(game.dad.x + 500, game.dad.y + 170);
				});

				cutsceneHandler.timer(31.2, function()
				{
					game.boyfriend.playAnim('singUPmiss', true);
					game.boyfriend.animation.finishCallback = function(name:String)
					{
						if (name == 'singUPmiss')
						{
							game.boyfriend.playAnim('idle', true);
							game.boyfriend.animation.curAnim.finish(); // Instantly goes to last frame
						}
					};

					game.snapCamFollowToPos(game.boyfriend.x + 280, game.boyfriend.y + 200);
					game.cameraSpeed = 12;
					FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 0.25, {ease: FlxEase.elasticOut});
				});

				cutsceneHandler.timer(32.2, function()
				{
					zoomBack();
				});
		}
	}


	// --- CHECK CUTSCENE --- 
	public function checkCutscene(daSong:String, dialogueBox:DialogueBox):Bool
	{
		switch (daSong)
			{
				case "monster":
					var whiteScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
					game.add(whiteScreen);
					whiteScreen.scrollFactor.set();
					whiteScreen.blend = ADD;
					game.camHUD.visible = false;
					game.snapCamFollowToPos(game.dad.getMidpoint().x + 150, game.dad.getMidpoint().y - 100);
					game.inCutscene = true;

					FlxTween.tween(whiteScreen, {alpha: 0}, 1, {
						startDelay: 0.1,
						ease: FlxEase.linear,
						onComplete: function(twn:FlxTween)
						{
							game.camHUD.visible = true;
							game.remove(whiteScreen);
							game.startCountdown();
						}
					});
					FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
					if (game.gf != null)
						game.gf.playAnim('scared', true);
					game.boyfriend.playAnim('scared', true);

				case "winter-horrorland":
					var blackScreen:FlxSprite = new FlxSprite().makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
					game.add(blackScreen);
					blackScreen.scrollFactor.set();
					game.camHUD.visible = false;
					game.inCutscene = true;

					FlxTween.tween(blackScreen, {alpha: 0}, 0.7, {
						ease: FlxEase.linear,
						onComplete: function(twn:FlxTween)
						{
							game.remove(blackScreen);
						}
					});
					FlxG.sound.play(Paths.sound('Lights_Turn_On'));
					game.snapCamFollowToPos(400, -2050);
					FlxG.camera.focusOn(game.camFollow);
					FlxG.camera.zoom = 1.5;

					new FlxTimer().start(0.8, function(tmr:FlxTimer)
					{
						game.camHUD.visible = true;
						game.remove(blackScreen);
						FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom}, 2.5, {
							ease: FlxEase.quadInOut,
							onComplete: function(twn:FlxTween)
							{
								game.startCountdown();
							}
						});
					});
				case 'senpai' | 'roses' | 'thorns':
					if (daSong == 'roses')
						FlxG.sound.play(Paths.sound('ANGRY'));
					schoolIntro(dialogueBox);

				case 'ugh' | 'guns' | 'stress':
					tankIntro();

				default:
					return false;
			}
		return true;
	}

	// --- SET VANILLA STAGE --- 
	public function setVanillaStage(songName:String, songStage:String):String
	{
		var curStage = songStage;
	if (PlayState.SONG.stage == null || PlayState.SONG.stage.length < 1)
	{
		switch (songName)
		{
		case 'spookeez' | 'south' | 'monster':
			curStage = 'spooky';
		case 'pico' | 'blammed' | 'philly' | 'philly-nice':
			curStage = 'philly';
		case 'milf' | 'satin-panties' | 'high':
			curStage = 'limo';
		case 'cocoa' | 'eggnog':
			curStage = 'mall';
		case 'winter-horrorland':
			curStage = 'mallEvil';
		case 'senpai' | 'roses':
			curStage = 'school';
		case 'thorns':
			curStage = 'schoolEvil';
		case 'ugh' | 'guns' | 'stress':
			curStage = 'tank';
		default:
			curStage = 'stage';
		}
	}
		return curStage;
	}

	// --- SET GF VERSION --- 
	public function setVanillaGFVersion(curStage:String, songName:String, gfVersion:String):String
	{
		if (gfVersion == null || gfVersion.length < 1)
		{
			switch (curStage)
			{
				case 'limo':
					gfVersion = 'gf-car';
				case 'mall' | 'mallEvil':
					gfVersion = 'gf-christmas';
				case 'school' | 'schoolEvil':
					gfVersion = 'gf-pixel';
				case 'tank':
					gfVersion = 'gf-tankmen';
				default:
					gfVersion = 'gf';
			}

			switch (Paths.formatToSongPath(songName))
			{
				case 'stress':
					gfVersion = 'pico-speaker';
			}
		}		return gfVersion;
	}

	// --- SETUP GF TANKMEN --- 
	public function setupGF(gfVersion:String):Void
	{
			if (gfVersion == 'pico-speaker')
			{
				if (!ClientPrefs.lowQuality)
				{
					var firstTank:TankmenBG = new TankmenBG(20, 500, true);
					firstTank.resetShit(20, 600, true);
					firstTank.strumTime = 10;
					tankmanRun.add(firstTank);

					for (i in 0...TankmenBG.animationNotes.length)
					{
						if (FlxG.random.bool(16))
						{
							var tankBih:TankmenBG = cast tankmanRun.recycle(TankmenBG);
							tankBih.strumTime = TankmenBG.animationNotes[i][0];
							tankBih.resetShit(500, 200 + FlxG.random.int(50, 100), TankmenBG.animationNotes[i][1] < 2);
							tankmanRun.add(tankBih);
						}
					}
				}
			}
	}

	// --- VANILLA EVENTY --- 
	public function triggerVanillaEvent(eventName:String, value1:String, value2:String)
	{
		switch(eventName) {
			case 'Hey!':
				var value:Int = 2;
				switch (value1.toLowerCase().trim())
				{
					case 'bf' | 'game.boyfriend' | '0':
						value = 0;
					case 'game.gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if (Math.isNaN(time) || time <= 0)
					time = 0.6;

				if (value != 0)
				{
					if (game.dad.curCharacter.startsWith('game.gf'))
					{ // Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						game.dad.playAnim('cheer', true);
						game.dad.specialAnim = true;
						heyTimer = time;
					}
					else if (game.gf != null)
					{
						game.gf.playAnim('cheer', true);
						game.gf.specialAnim = true;
						game.gf.heyTimer = time;
					}

					if (PlayState.curStage == 'mall')
					{
						bottomBoppers.animation.play('hey', true);
						heyTimer = time;
					}
				}
				if (value != 1)
				{
					game.boyfriend.playAnim('hey', true);
					game.boyfriend.specialAnim = true;
					heyTimer = time;
				}

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

	
}
