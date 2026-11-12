package;

import flixel.system.FlxAssets.FlxShader;

/** Clips an atlas glyph to a horizontal text viewport with soft edges. */
class AlphabetMarqueeShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header
		uniform vec2 glyphUV;
		uniform vec2 glyphPosition;
		uniform vec2 viewport;
		uniform float fadeWidth;
		uniform float maskStrength;
		void main()
		{
			float localX = (openfl_TextureCoordv.x - glyphUV.x) / glyphUV.y;
			float x = glyphPosition.x + localX * glyphPosition.y;
			float mask = smoothstep(viewport.x, viewport.x + fadeWidth, x)
				* (1.0 - smoothstep(viewport.y - fadeWidth, viewport.y, x));
			gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv) * mix(1.0, mask, maskStrength);
		}
	')
	public function new()
	{
		super();
	}
}
