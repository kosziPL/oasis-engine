package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import flixel.graphics.FlxGraphic;
#if sys
import sys.FileSystem;
#end

using StringTools;

class StickerFadeTransition extends FlxSubState
{
	var stickers:FlxTypedGroup<FlxSprite>;
	var stickerPool:Array<String> = [];
	var soundPool:Array<String> = [];
	var isRevealing:Bool = false;

	public static var transitionSeed:Int = -1;

	public function new(isRevealing:Bool = false)
	{
		super();
		this.isRevealing = isRevealing;

		var targetCam = CustomFadeTransition.nextCamera != null ? CustomFadeTransition.nextCamera : FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.cameras = [targetCam];
		CustomFadeTransition.nextCamera = null;

		stickers = new FlxTypedGroup<FlxSprite>();
		add(stickers);

		#if sys
		var directories:Array<String> = [];
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			directories.push(Paths.mods(Paths.currentModDirectory + '/'));
		
		for (mod in Paths.getGlobalMods())
		{
			var p = Paths.mods(mod + '/');
			if (!directories.contains(p))
				directories.push(p);
		}
		
		directories.push("assets/fnf/");
		
		var foundStickers = false;
		var foundSounds = false;
		for (dir in directories)
		{
			var curImg = dir + "images/stickers/";
			if (!foundStickers && FileSystem.exists(curImg))
			{
				for (file in FileSystem.readDirectory(curImg))
				{
					if (file.toLowerCase().endsWith(".png"))
					{
						var n = file.substring(0, file.length - 4);
						if (!stickerPool.contains(n)) stickerPool.push(n);
						foundStickers = true;
					}
				}
			}
			
			var curSnd = dir + "sounds/stickers/";
			if (!foundSounds && FileSystem.exists(curSnd))
			{
				for (file in FileSystem.readDirectory(curSnd))
				{
					if (file.toLowerCase().endsWith(".ogg"))
					{
						var n = file.substring(0, file.length - 4);
						if (!soundPool.contains(n)) soundPool.push(n);
						foundSounds = true;
					}
				}
			}
			
			if (foundStickers && foundSounds) break;
		}
		#end

		if (stickerPool.length == 0)
			stickerPool = ['logo'];

		startTransition();
	}

	function startTransition()
	{
		if (!isRevealing)
		{
			transitionSeed = Std.int(Math.random() * 9999999);
		}
		else if (transitionSeed == -1)
		{
			transitionSeed = Std.int(Math.random() * 9999999);
		}

		FlxG.random.initialSeed = transitionSeed;

		var loadedGraphics:Array<FlxGraphic> = [];
		for (file in stickerPool)
		{
			var g = Paths.image('stickers/' + file);
			if (g == null)
				g = Paths.image(file);
			if (g != null)
				loadedGraphics.push(g);
		}
		if (loadedGraphics.length == 0)
		{
			var fallback = Paths.image('logo');
			if (fallback != null)
				loadedGraphics.push(fallback);
		}

		var xPos:Float = -100;
		var yPos:Float = -100;

		// Measure once per graphic, not once per spawned sticker. Alpha-weighted
		// area gives sparse silhouettes (hair, horns, etc.) a comparable visual size.
		var measurements = [for (graphic in loadedGraphics) measureSticker(graphic)];
		var targetSize:Float = FlxG.height * 0.3;
		var stickerSpacing:Float = targetSize * 0.28;

		while (xPos <= FlxG.width)
		{
			var stickerGraphic:FlxGraphic = null;
			var graphicIndex = 0;
			if (loadedGraphics.length > 0)
			{
				graphicIndex = FlxG.random.int(0, loadedGraphics.length - 1);
				stickerGraphic = loadedGraphics[graphicIndex];
			}

			if (stickerGraphic == null)
			{
				xPos += 100;
				continue;
			}

			var sticker = new FlxSprite(xPos, yPos).loadGraphic(stickerGraphic);
			var measurement = measurements[graphicIndex];
			var visualScale = targetSize / Math.sqrt(measurement.area);
			// Bound pathological mod assets with very little visible content.
			visualScale = Math.min(visualScale, FlxG.height / Math.max(sticker.frameWidth, sticker.frameHeight));
			sticker.scale.set(visualScale, visualScale);
			sticker.updateHitbox();
			sticker.origin.set(measurement.centerX, measurement.centerY);
			// Flixel draws relative to offset and origin; keep the visible mass on the grid.
			sticker.setPosition(xPos + sticker.offset.x - sticker.origin.x,
				yPos + sticker.offset.y - sticker.origin.y);
			sticker.antialiasing = ClientPrefs.globalAntialiasing;
			sticker.angle = FlxG.random.int(-60, 70);

			xPos += stickerSpacing;

			if (xPos >= FlxG.width)
			{
				if (yPos <= FlxG.height)
				{
					xPos = -100;
					yPos += FlxG.random.float(70, 120);
				}
				else
				{
					break;
				}
			}

			stickers.add(sticker);
		}

		FlxG.random.shuffle(stickers.members);

		for (i in 0...stickers.members.length)
		{
			var sticker = stickers.members[i];
			var timing = FlxMath.remapToRange(i, 0, stickers.members.length, 0, 0.9);

			if (!isRevealing)
			{
				sticker.visible = false;
				new FlxTimer().start(timing, function(_)
				{
					if (sticker == null)
						return;
					sticker.visible = true;
					playStickerSound();
				});
			}
			else
			{
				sticker.visible = true;
				new FlxTimer().start(timing, function(_)
				{
					if (sticker == null)
						return;
					sticker.visible = false;
					playStickerSound();
				});
			}
		}

		var closeTime:Float = isRevealing ? 1.0 : 1.5;
		new FlxTimer().start(closeTime, function(tmr:FlxTimer)
		{
			if (closeCallback != null)
			{
				closeCallback();
			}
			if (isRevealing || closeCallback == null)
			{
				close();
			}
		});
	}


	static function measureSticker(graphic:FlxGraphic):{area:Float, centerX:Float, centerY:Float}
	{
		var bitmap = graphic.bitmap;
		var width = graphic.width;
		var height = graphic.height;
		var area:Float = 0;
		var sumX:Float = 0;
		var sumY:Float = 0;
		if (bitmap != null)
		{
			// Limit CPU readback work even for high-resolution mod textures.
			var step = Std.int(Math.max(1, Math.ceil(Math.max(width, height) / 128)));
			var y = 0;
			while (y < height)
			{
				var cellHeight = Std.int(Math.min(step, height - y));
				var x = 0;
				while (x < width)
				{
					var cellWidth = Std.int(Math.min(step, width - x));
					var alpha = (bitmap.getPixel32(x + Std.int(cellWidth / 2), y + Std.int(cellHeight / 2)) >>> 24) / 255.0;
					var weight = alpha * cellWidth * cellHeight;
					area += weight;
					sumX += (x + cellWidth / 2.0) * weight;
					sumY += (y + cellHeight / 2.0) * weight;
					x += step;
				}
				y += step;
			}
		}
		if (area <= 0)
			return {area: Math.max(1.0, width * 1.0 * height), centerX: width / 2.0, centerY: height / 2.0};
		return {area: area, centerX: sumX / area, centerY: sumY / area};
	}

	function playStickerSound()
	{
		if (soundPool.length > 0)
		{
			var snd = soundPool[FlxG.random.int(0, soundPool.length - 1)];
			FlxG.sound.play(Paths.sound('stickers/' + snd), 0.3);
		}
	}
}
