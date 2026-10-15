package;

import flixel.FlxCamera;
import flixel.FlxG;
import openfl.geom.Rectangle;

class SmartCamera extends FlxCamera
{
	public var smartClipping:Bool = true;

	public function new(X:Int = 0, Y:Int = 0, Width:Int = 0, Height:Int = 0, Zoom:Float = 0)
	{
		super(X, Y, Width, Height, Zoom);
	}

	@:access(flixel.FlxCamera)
	override function updateScrollRect():Void
	{
		super.updateScrollRect();

		if (smartClipping && _scrollRect != null)
		{
			var rect:Rectangle = _scrollRect.scrollRect;
			if (rect != null)
			{
				var baseW:Float = width * initialZoom * FlxG.scaleMode.scale.x;
				var baseH:Float = height * initialZoom * FlxG.scaleMode.scale.y;

				var expandedW:Float = baseW * 2.0;
				var expandedH:Float = baseH * 2.0;
				
				rect.x = -0.5 * baseW;
				rect.y = -0.5 * baseH;
				rect.width = expandedW;
				rect.height = expandedH;
				
				_scrollRect.scrollRect = rect;
				_scrollRect.x = -1.0 * baseW;
				_scrollRect.y = -1.0 * baseH;
			}
		}
	}
}
