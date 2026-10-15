package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

using StringTools;

class StrumNote extends FlxSprite
{
    private var colorSwap:ColorSwap;
    public var resetAnim:Float = 0;
    private var noteData:Int = 0;
    public var direction:Float = 90;
    public var downScroll:Bool = false;
    public var sustainReduce:Bool = true;
    public var player:Int = 0;
    
    // OASIS ENGINE SYSTEM ID
    public var charID:Int = 0;      // Who sings (used by notes for routing)
    public var sideIndex:Int = 0;   // The stream index on this side (for X positioning)

    public var texture(default, set):String = null;
    private function set_texture(value:String):String {
        if(texture != value) {
            texture = value;
            reloadNote();
        }
        return value;
    }

    // Added charID and sideIndex as optional constructor parameters (defaults to 0)
    public function new(x:Float, y:Float, leData:Int, player:Int, charID:Int = 0, sideIndex:Int = 0) {
        colorSwap = new ColorSwap();
        shader = colorSwap.shader;
        noteData = leData;
        this.player = player;
        this.charID = charID;
        this.sideIndex = sideIndex; // Assign local side queue index
        super(x, y);

        var skin:String = texture;
        if(texture == null || texture.length < 1) {
            skin = PlayState.SONG.arrowSkin;
            if(skin == null || skin.length < 1) {
                skin = CustomPrefs.default_note_asset_name;
            }
        }
        texture = skin; 

        scrollFactor.set();
    }

    public function reloadNote()
    {
        var lastAnim:String = null;
        if(animation.curAnim != null) lastAnim = animation.curAnim.name;

        if(PlayState.isPixelStage)
        {
            loadGraphic(Paths.image('pixelUI/' + texture));
            width = width / 4;
            height = height / 5;
            loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

            antialiasing = false;
            setGraphicSize(Std.int(width * PlayState.daPixelZoom));

            animation.add('static', [noteData]);
            animation.add('pressed', [noteData + 4, noteData + 8], 12, false);
            animation.add('confirm', [noteData + 12, noteData + 16], 24, false);
        }
        else
        {
            frames = Paths.getSparrowAtlas(texture);
            antialiasing = ClientPrefs.globalAntialiasing;
            setGraphicSize(Std.int(width * 0.7));

            var dir:String = '';
            switch (noteData) {
                case 0: dir = 'LEFT';
                case 1: dir = 'DOWN';
                case 2: dir = 'UP';
                case 3: dir = 'RIGHT';
            }

            animation.addByPrefix('static', 'arrow' + dir);
            animation.addByPrefix('pressed', dir.toLowerCase() + ' press', 24, false);
            animation.addByPrefix('confirm', dir.toLowerCase() + ' confirm', 24, false);
        }
        updateHitbox();

        if(lastAnim != null)
        {
            playAnim(lastAnim, true);
        }
    }

    public function postAddedToGroup() {
        playAnim('static');
        
        // 1. Each arrow starts from the left edge of the screen
        x += Note.swagWidth * noteData;
        x += 50;
        
        // 2. isPlayer (converted to player 0 or 1) distributes the base to Left/Right
        x += ((FlxG.width / 2) * player);
        
        ID = noteData;

        // 3. Pure Oasis logic based on sideIndex.
        // If this is a companion/extra character stream on the same side (e.g. sideIndex = 1),
        // we shift it by a constant value (e.g. 160 pixels) to avoid overlapping the main strum line.
        if (sideIndex > 0) {
            x += 160 * sideIndex; 
        }
    }

    override function update(elapsed:Float) {
        if(resetAnim > 0) {
            resetAnim -= elapsed;
            if(resetAnim <= 0) {
                playAnim('static');
                resetAnim = 0;
            }
        }

        super.update(elapsed);
    }

    public function playAnim(anim:String, ?force:Bool = false) {
        animation.play(anim, force);
        centerOffsets();
        centerOrigin();
        if(animation.curAnim == null || animation.curAnim.name == 'static') {
            colorSwap.hue = 0;
            colorSwap.saturation = 0;
            colorSwap.brightness = 0;
        } else {
            colorSwap.hue = ClientPrefs.arrowHSV[noteData % 4][0] / 360;
            colorSwap.saturation = ClientPrefs.arrowHSV[noteData % 4][1] / 100;
            colorSwap.brightness = ClientPrefs.arrowHSV[noteData % 4][2] / 100;

            if(animation.curAnim.name == 'confirm' && !PlayState.isPixelStage) {
                centerOrigin();
            }
        }
    }
}