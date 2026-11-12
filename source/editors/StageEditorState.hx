package editors;

using StringTools;

typedef BackgroundItem = {
    var path:String;
    var x:Float;
    var y:Float;
    var sizeX:Float;
    var sizeY:Float;
    var scrollFactorX:Float;
    var scrollFactorY:Float;
    var alpha:Float;
    var zIndex:Int;
}

class StageEditorState extends MusicBeatState {
    var player: Character = null;
    var opponent:Character = null;
    
    // BTW "var gf:Character?". 3 miesiące kotlina spowodowały regres mentalny...
    var gf:Character = null;

    private var backgroundItems:Array<BackgroundItem> = [];
    
    override function create() {
        
    }
}

    