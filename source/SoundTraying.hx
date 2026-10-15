package;

import openfl.Lib;
import openfl.display.Bitmap;
import flixel.system.ui.FlxSoundTray;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxG;

class SoundTraying extends FlxSoundTray
{
    public static var displayDuration:Float = 1.5;          
    public static var easeDuration:Float = 0.5;
    public static var trayScale:Float = 0.55;

    public var volumeBox:Bitmap;
    public var activeBars:Bitmap;
    public var bgBars:Bitmap;

    private var tween:FlxTween;
    private var _lastVolume:Int = -1;
    private var _initialized:Bool = false;

    public function new()
    {
        super();
        
        _lastVolume = Math.round(FlxG.sound.volume * 10);
        if (FlxG.sound.muted) {
            _lastVolume = 0;
        }
    }

    private function initTray():Void
    {
        if (_initialized) return;
        _initialized = true;

        while (numChildren > 0) {
            removeChildAt(0);
        }

        var boxData = Paths.image('soundtray/volumebox').bitmap;
        volumeBox = new Bitmap(boxData);
        
        var grayTransform = new openfl.geom.ColorTransform();
        grayTransform.redOffset = 40;
        grayTransform.greenOffset = 40;
        grayTransform.blueOffset = 40;
        volumeBox.transform.colorTransform = grayTransform;
        
        addChild(volumeBox);

        var bgBarsData = Paths.image('soundtray/bars_10').bitmap;
        bgBars = new Bitmap(bgBarsData);
        
        bgBars.x = (volumeBox.width - bgBars.width) / 2;
        bgBars.y = (90 - bgBars.height) / 2;
        
        var darkenTransform = new openfl.geom.ColorTransform(0.2, 0.2, 0.2, 1.0);
        bgBars.transform.colorTransform = darkenTransform;
        addChild(bgBars);

        activeBars = new Bitmap();
        activeBars.x = bgBars.x;
        activeBars.y = bgBars.y;
        addChild(activeBars);

        screenCenter();
        y = -volumeBox.height * scaleY;
    }

    override public function screenCenter():Void
    {
        scaleX = trayScale;
        scaleY = trayScale;
        
        if (volumeBox != null && (volumeBox.bitmapData == null || volumeBox.bitmapData.width == 0)) {
            var boxGraphic = Paths.image('soundtray/volumebox');
            if (boxGraphic != null && boxGraphic.bitmap != null) {
                volumeBox.bitmapData = boxGraphic.bitmap;
            }
        }
        
        var gameScaleX:Float = FlxG.game != null ? FlxG.game.scaleX : 1.0;
        
        if (volumeBox != null && volumeBox.bitmapData != null && volumeBox.bitmapData.width > 0) {
            x = (0.5 * (Lib.current.stage.stageWidth - volumeBox.width * scaleX * gameScaleX) - FlxG.game.x) / gameScaleX;
        } else {
            x = (0.5 * (Lib.current.stage.stageWidth - 80 * scaleX * gameScaleX) - FlxG.game.x) / gameScaleX;
        }
    }

    override public function show(Silent:Bool = false):Void
    {
        initTray();

        var boxGraphic = Paths.image('soundtray/volumebox');
        if (boxGraphic != null && boxGraphic.bitmap != null) {
            volumeBox.bitmapData = boxGraphic.bitmap;
        }
        
        var bgBarsGraphic = Paths.image('soundtray/bars_10');
        if (bgBarsGraphic != null && bgBarsGraphic.bitmap != null) {
            bgBars.bitmapData = bgBarsGraphic.bitmap;
        }

        var globalVolume:Int = Math.round(FlxG.sound.volume * 10);

        if (FlxG.sound.muted) {
            globalVolume = 0;
        }

        if (globalVolume > 0) {
            var activeGraphic = Paths.image('soundtray/bars_' + globalVolume);
            if (activeGraphic != null && activeGraphic.bitmap != null) {
                activeBars.bitmapData = activeGraphic.bitmap;
            }
            activeBars.visible = true;
        } else {
            activeBars.visible = false;
        }

        if (volumeBox.bitmapData != null && bgBars.bitmapData != null) {
            bgBars.x = (volumeBox.width - bgBars.width) / 2;
            bgBars.y = (90 - bgBars.height) / 2;
            activeBars.x = bgBars.x;
            activeBars.y = bgBars.y;
        }

        var up:Bool = false;
        if (_lastVolume == -1) {
            _lastVolume = globalVolume;
        } else {
            if (globalVolume > _lastVolume) {
                up = true;
            } else if (globalVolume < _lastVolume) {
                up = false;
            } else {
                if (FlxG.keys.anyJustReleased(FlxG.sound.volumeUpKeys)) {
                    up = true;
                } else if (FlxG.keys.anyJustReleased(FlxG.sound.volumeDownKeys)) {
                    up = false;
                }
            }
        }

        if (FlxG.sound.muted || Silent || globalVolume == 0) {
            
        } 
        else if (_lastVolume == globalVolume && !FlxG.keys.anyJustReleased(FlxG.sound.volumeUpKeys) && !FlxG.keys.anyJustReleased(FlxG.sound.volumeDownKeys)) {
            
        }
        else if (FlxG.keys.anyJustReleased(FlxG.sound.muteKeys)) {
            FlxG.sound.play(Paths.sound('Volup'));
        } 
        else if (up) {
            if (globalVolume >= 10) {
                FlxG.sound.play(Paths.sound('VolMAX'));
            } else {
                FlxG.sound.play(Paths.sound('Volup'));
            }
        } 
        else {
            FlxG.sound.play(Paths.sound('Voldown'));
        }

        _lastVolume = globalVolume;

        _timer = displayDuration;
        visible = true;
        active = true;

        if (tween != null) tween.cancel();

        tween = FlxTween.tween(this, {y: 0}, easeDuration, {ease: FlxEase.cubeOut});
    }

    override public function update(MS:Float):Void
    {
        if (_timer > 0) {
            _timer -= MS / 1000;
            if (_timer <= 0) {
                hideTray();
            }
        }
    }

    private function hideTray():Void
    {
        if (tween != null) tween.cancel();

        var targetY:Float = volumeBox != null ? -volumeBox.height * scaleY : -60.0;

        tween = FlxTween.tween(this, {y: targetY}, easeDuration, {
            ease: FlxEase.cubeOut,
            onComplete: function(twn:FlxTween) {
                visible = false;
                active = false;
                
                FlxG.save.data.mute = FlxG.sound.muted;
                FlxG.save.data.volume = FlxG.sound.volume;
                FlxG.save.flush();
            }
        });
    }
}