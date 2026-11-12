package editors;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import FlxUIDropDownMenuCustom;
import FlxUIDropDownMenuCustom.FlxUIDropDownHeader;
import haxe.Json;

using StringTools;

/** One marker owns several independent camera channels. Durations are PlayState.SONG seconds (v2). */
typedef CameraKeyframe = {
	var step:Float;
	var settings:Array<CameraSetting>;
}

typedef CameraSetting = {
	var kind:String;
	var ease:String;
	var duration:Float;
	@:optional var target:String;
	@:optional var targetId:Int;
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var value:Float;
	@:optional var motion:String;
	@:optional var reset:Bool;
	// Only retained when importing an old camera.json.
	@:optional var standalone:Bool;
}

/**
 * Actual transition math, also used by gameplay. No frame sampling and no second lerp.
 * For Default, duration means time to cover 99% of the distance, just like target follow.
 * Keeping the exponential tail makes the automatic duration exactly the normal follow.
 */
class CameraTransition
{
	public static inline var SETTLE:Float = 4.605170185988091;
	public var from:Float;
	public var to:Float;
	public var start:Float = 0;
	public var duration:Float = 0;
	public var ease:String = 'instant';

	public function new(value:Float)
	{
		from = to = value;
	}

	public function begin(value:Float, target:Float, time:Float, seconds:Float, functionName:String):Void
	{
		from = value;
		to = target;
		start = time;
		duration = seconds;
		ease = functionName;
	}

	public function at(time:Float):Float
	{
		return from + (to - from) * progress(ease, (time - start) / 1000, duration);
	}

	public static function progress(name:String, seconds:Float, duration:Float):Float
	{
		if (name == 'instant' || duration <= 0) return 1;
		if (seconds <= 0) return 0;
		if (name == 'default') return 1 - Math.exp(-SETTLE * seconds / duration);
		if (seconds >= duration) return 1;
		var t = seconds / duration;
		// Explicit calls keep all ease functions alive on native targets (Reflect + inline doesn't).
		return switch (name) {
			case 'quadIn': FlxEase.quadIn(t);
			case 'quadOut': FlxEase.quadOut(t);
			case 'quadInOut': FlxEase.quadInOut(t);
			case 'cubeIn': FlxEase.cubeIn(t);
			case 'cubeOut': FlxEase.cubeOut(t);
			case 'cubeInOut': FlxEase.cubeInOut(t);
			case 'quartIn': FlxEase.quartIn(t);
			case 'quartOut': FlxEase.quartOut(t);
			case 'quartInOut': FlxEase.quartInOut(t);
			case 'quintIn': FlxEase.quintIn(t);
			case 'quintOut': FlxEase.quintOut(t);
			case 'quintInOut': FlxEase.quintInOut(t);
			case 'sineIn': FlxEase.sineIn(t);
			case 'sineOut': FlxEase.sineOut(t);
			case 'sineInOut': FlxEase.sineInOut(t);
			case 'expoIn': FlxEase.expoIn(t);
			case 'expoOut': FlxEase.expoOut(t);
			case 'expoInOut': FlxEase.expoInOut(t);
			case 'circIn': FlxEase.circIn(t);
			case 'circOut': FlxEase.circOut(t);
			case 'circInOut': FlxEase.circInOut(t);
			case 'backIn': FlxEase.backIn(t);
			case 'backOut': FlxEase.backOut(t);
			case 'backInOut': FlxEase.backInOut(t);
			case 'bounceIn': FlxEase.bounceIn(t);
			case 'bounceOut': FlxEase.bounceOut(t);
			case 'bounceInOut': FlxEase.bounceInOut(t);
			case 'elasticIn': FlxEase.elasticIn(t);
			case 'elasticOut': FlxEase.elasticOut(t);
			case 'elasticInOut': FlxEase.elasticInOut(t);
			default: t;
		};
	}
}

/** Runtime and editor use this very same director, on the real PlayState cameras. */
@:access(PlayState)
class CameraDirector
{
	public static var eases(default, null):Array<String> = ['default', 'instant', 'linear',
		'quadIn', 'quadOut', 'quadInOut', 'cubeIn', 'cubeOut', 'cubeInOut',
		'quartIn', 'quartOut', 'quartInOut', 'quintIn', 'quintOut', 'quintInOut',
		'sineIn', 'sineOut', 'sineInOut', 'expoIn', 'expoOut', 'expoInOut',
		'circIn', 'circOut', 'circInOut', 'backIn', 'backOut', 'backInOut',
		'bounceIn', 'bounceOut', 'bounceInOut', 'elasticIn', 'elasticOut', 'elasticInOut'];
	public var frames:Array<CameraKeyframe> = [];
	public var baseZoom:Float;
	var baseAngle:Float;
	public var position:CameraSetting;
	public var zoom:CameraSetting;
	public var rotation:CameraSetting;
	public var x:Float;
	public var y:Float;
	public var z:Float;
	public var angle:Float;
	var state:PlayState;
	var tx:CameraTransition;
	var ty:CameraTransition;
	var tz:CameraTransition;
	var ta:CameraTransition;
	var cursor:Int = 0;
	var lastTime:Float = 0;
	var replaying:Bool = false;
	var moments:Array<Float> = [];
	var chartNotes:Array<Array<Dynamic>> = [];
	var sectionSteps:Array<Float> = [];

	public function new(state:PlayState, frames:Array<CameraKeyframe>)
	{
		this.state = state;
		this.frames = frames;
		baseZoom = state.defaultCamZoom;
		x = state.camFollowPos.x;
		y = state.camFollowPos.y;
		z = baseZoom;
		angle = baseAngle = state.camGame.angle;
		tx = new CameraTransition(x);
		ty = new CameraTransition(y);
		tz = new CameraTransition(z);
		ta = new CameraTransition(angle);
		lastTime = Math.min(0, Conductor.songPosition);
		buildMoments();
	}

	public static function secondsFor(kind:String, speed:Float = 1, decay:Float = 1):Float
	{
		return CameraTransition.SETTLE / Math.max(0.001, kind == 'zoom' ? 3.125 * decay : 2.4 * speed);
	}

	public static function prepareBPMMap():Void
	{
		// Conductor's fallback BPM is mutable; pin beat zero so backwards seeks stay correct.
		if (Conductor.bpmChangeMap.length == 0 || Conductor.bpmChangeMap[0].stepTime > 0)
			Conductor.bpmChangeMap.unshift({stepTime: 0, songTime: 0, bpm: PlayState.SONG.bpm, stepCrochet: 15000 / PlayState.SONG.bpm});
	}

	public static function stepTime(step:Float):Float
	{
		return Conductor.beatToSeconds(step / 4);
	}

	static function number(v:Dynamic, fallback:Float):Float
	{
		var n = Std.parseFloat(Std.string(v));
		return Math.isFinite(n) ? n : fallback;
	}

	/** Validate at the disk boundary. Old entries at the same step become a single marker. */
	public static function decode(data:Dynamic):Array<CameraKeyframe>
	{
		var result:Array<CameraKeyframe> = [];
		if (data == null) throw 'Empty camera file';
		if (data.version != null && number(data.version, 0) > 2) throw 'Unsupported camera file version';
		var modern:Bool = data.camera_timeline != null;
		var source:Dynamic = modern ? data.camera_timeline : data.camera_events;
		if (!Std.isOfType(source, Array)) throw 'Missing camera_timeline / camera_events array';
		for (entry in (source:Array<Dynamic>))
		{
			if (entry == null) continue;
			var step = Math.max(0, number(entry.step, 0));
			var settings:Array<CameraSetting> = [];
			if (modern)
			{
				if (!Std.isOfType(entry.settings, Array)) throw 'Invalid camera settings at step ' + step;
				for (raw in (entry.settings:Array<Dynamic>))
				{
					if (raw == null || ['position', 'zoom', 'rotation'].indexOf(raw.kind) < 0)
						throw 'Unknown camera setting at step ' + step;
					var s:CameraSetting = {
						kind: raw.kind, ease: eases.indexOf(raw.ease) >= 0 ? raw.ease : 'default',
						duration: Math.max(0, number(raw.duration, secondsFor(raw.kind))),
						target: raw.target == null ? 'global' : raw.target, targetId: Std.int(number(raw.targetId, 0)),
						x: number(raw.x, 0), y: number(raw.y, 0), value: number(raw.value, raw.kind == 'zoom' ? 1 : 0),
						motion: raw.motion == 'fixed' ? 'fixed' : 'notes', reset: raw.reset == true,
						standalone: raw.standalone == true
					};
					if (s.kind == 'position' && ['global', 'dad', 'bf', 'gf', 'midpoint', 'extra_char', 'default'].indexOf(s.target) < 0)
						throw 'Unknown camera target at step ' + step;
					if (s.kind == 'zoom') s.value = Math.max(0.05, s.value);
					settings.push(s);
				}
			}
			else
			{
				var duration = Math.max(0, (stepTime(step + number(entry.duration, 0) * 4) - stepTime(step)) / 1000);
				var ease = eases.indexOf(entry.ease) >= 0 ? entry.ease : 'linear';
				var target:String = entry.target_type == null ? 'global' : entry.target_type;
				if (target != 'zoom') settings.push({kind: 'position', target: target == 'midpoint' || entry.is_relative == true || target == 'default' ? target : 'global',
					targetId: Std.int(number(entry.target_id, 0)), x: number(entry.x, 0), y: number(entry.y, 0),
					ease: ease, duration: duration, motion: entry.lock_note_movement == true ? 'fixed' : 'notes', standalone: entry.standalone == true});
				if (number(entry.zoom, -1) > 0 || target == 'default') settings.push({kind: 'zoom', ease: ease,
					duration: duration, value: Math.max(0.05, number(entry.zoom, 1)), reset: target == 'default'});
			}
			if (settings.length == 0) continue;
			var frame:CameraKeyframe = null;
			for (existing in result) if (Math.abs(existing.step - step) < 0.00001) { frame = existing; break; }
			if (frame == null) { frame = {step: step, settings: []}; result.push(frame); }
			for (s in settings)
			{
				// A channel has one destination per marker; different channels remain independent.
				frame.settings = frame.settings.filter(function(old) return old.kind != s.kind);
				frame.settings.push(s);
			}
		}
		result.sort(function(a, b) return Reflect.compare(a.step, b.step));
		return result;
	}

	function buildMoments():Void
	{
		var step:Float = 0;
		for (section in PlayState.SONG.notes)
		{
			sectionSteps.push(step);
			moments.push(stepTime(step));
			for (note in section.sectionNotes)
			{
				if (note[3] == 'No Animation') continue;
				var id = Std.int(number(note[1], 0) / 4);
				while (chartNotes.length <= id) chartNotes.push([]);
				if (section.gfSection && id == 0 && state.gf != null) id = state.extraChars.length;
				while (chartNotes.length <= id) chartNotes.push([]);
				var char = id == state.extraChars.length ? state.gf : id < state.extraChars.length ? state.extraChars[id] : null;
				var hold = Conductor.getCrotchetAtTime(note[0]) * 0.25 * 1.1 * (char == null ? 4 : char.singDuration);
				var end = number(note[0], 0) + Math.max(0, number(note[2], 0)) + hold;
				chartNotes[id].push({time: number(note[0], 0), end: end, direction: Std.int(number(note[1], 0)) % 4});
				moments.push(note[0]);
				moments.push(end);
			}
			step += (section.sectionBeats > 0 ? section.sectionBeats : 4) * 4;
		}
		for (notes in chartNotes) notes.sort(function(a, b) return Reflect.compare(a.time, b.time));
		moments.sort(function(a, b) return Reflect.compare(a, b));
	}

	function sectionAt(time:Float):Int
	{
		var step = Conductor.getStep(time);
		var i = 0;
		while (i + 1 < sectionSteps.length && sectionSteps[i + 1] <= step) i++;
		return i;
	}

	function focusAt(time:Float):Character
	{
		var section = PlayState.SONG.notes[sectionAt(time)];
		if (section == null) return state.dad;
		if (section.gfSection) return state.gf;
		var id:Int = section.camFocus == null ? (section.mustHitSection ? 1 : 0) : section.camFocus;
		return id >= 0 && id < state.extraChars.length ? state.extraChars[id] : state.dad;
	}

	function noteOffset(char:Character, time:Float):FlxPoint
	{
		var p = FlxPoint.get();
		if (!ClientPrefs.camMove || state.inCutscene || char == null) return p;
		var direction = -1;
		if (replaying)
		{
			var id = char == state.gf ? state.extraChars.length : state.extraChars.indexOf(char);
			if (id >= 0 && id < chartNotes.length)
			{
				var notes = chartNotes[id];
				var lo = 0;
				var hi = notes.length;
				while (lo < hi) { var mid = (lo + hi) >> 1; if (notes[mid].time <= time) lo = mid + 1; else hi = mid; }
				if (lo > 0 && time < notes[lo - 1].end) direction = notes[lo - 1].direction;
			}
		}
		else if (char.animation.curAnim != null)
		{
			var name = char.animation.curAnim.name;
			if (name.startsWith('singLEFT')) direction = 0;
			else if (name.startsWith('singDOWN')) direction = 1;
			else if (name.startsWith('singUP')) direction = 2;
			else if (name.startsWith('singRIGHT')) direction = 3;
		}
		switch (direction) {
			case 0: p.x = -ClientPrefs.camMoveStrength;
			case 1: p.y = ClientPrefs.camMoveStrength;
			case 2: p.y = -ClientPrefs.camMoveStrength;
			case 3: p.x = ClientPrefs.camMoveStrength;
		}
		return p;
	}

	public function target(s:CameraSetting, time:Float):FlxPoint
	{
		var type = s == null ? 'default' : s.target;
		var char:Character = null;
		var p:FlxPoint;
		if (s == null && !replaying) return FlxPoint.get(state.camFollow.x, state.camFollow.y);
		if (type == 'default')
		{
			char = focusAt(time);
			p = state.getCameraTargetPosition(char == state.gf ? 'gf' : 'extra_char', state.extraChars.indexOf(char));
			if (!replaying && state.isCameraOnForcedPos) p.set(state.camFollow.x, state.camFollow.y);
		}
		else if (type == 'global') p = FlxPoint.get(s.x, s.y);
		else if (type == 'midpoint')
		{
			var a = state.dad.getMidpoint();
			var b = state.boyfriend.getMidpoint();
			p = FlxPoint.get((a.x + b.x) / 2 + s.x, (a.y + b.y) / 2 + s.y);
			a.put(); b.put();
		}
		else
		{
			p = state.getCameraTargetPosition(type, s.targetId == null ? 0 : s.targetId);
			p.add(s.x, s.y);
			char = switch (type) {
				case 'dad': state.dad;
				case 'bf': state.boyfriend;
				case 'gf': state.gf;
				case 'extra_char': s.targetId >= 0 && s.targetId < state.extraChars.length ? state.extraChars[s.targetId] : null;
				default: null;
			};
		}
		if (s == null || s.motion != 'fixed')
		{
			var offset = noteOffset(char == null ? focusAt(time) : char, time);
			if (!state.isCameraOnForcedPos || type != 'default') p.add(offset.x, offset.y);
			offset.put();
		}
		return p;
	}

	function evaluate(time:Float, ?targetTime:Float):Void
	{
		var dt = Math.max(0, time - lastTime) / 1000;
		var p = target(position, targetTime == null ? time : targetTime);
		if (position == null || position.ease == 'default')
		{
			var rate = position == null ? 2.4 * state.cameraSpeed : CameraTransition.SETTLE / Math.max(0.000001, position.duration);
			var alpha = position != null && position.duration <= 0 ? 1 : 1 - Math.exp(-rate * dt);
			x += (p.x - x) * alpha;
			y += (p.y - y) * alpha;
		}
		else
		{
			tx.to = p.x; ty.to = p.y;
			x = tx.at(time); y = ty.at(time);
		}
		p.put();
		if (zoom != null) z = zoom.reset == true && time >= tz.start + tz.duration * 1000 ? baseZoom : tz.at(time);
		if (rotation != null) angle = ta.at(time);
		lastTime = time;
	}

	function begin(frame:CameraKeyframe, time:Float):Void
	{
		for (s in frame.settings)
		{
			switch (s.kind) {
				case 'position':
					position = s;
					var p = target(s, time);
					tx.begin(x, p.x, time, s.duration, s.ease);
					ty.begin(y, p.y, time, s.duration, s.ease);
					p.put();
				case 'zoom':
					if (!ownsZoom() && !replaying) z = state.camGame.zoom / state.smartCamZoomMult;
					zoom = s;
					tz.begin(z, s.reset == true ? baseZoom : s.value, time, s.duration, s.ease);
				case 'rotation':
					if (rotation == null && !replaying) angle = state.camGame.angle;
					rotation = s;
					ta.begin(angle, s.value, time, s.duration, s.ease);
			}
		}
	}

	public function update(time:Float):Void
	{
		if (time < lastTime - 1) { seek(time); return; }
		while (cursor < frames.length && stepTime(frames[cursor].step) <= time)
		{
			var frame = frames[cursor++];
			var at = stepTime(frame.step);
			evaluate(at);
			begin(frame, at);
		}
		evaluate(time);
		apply();
	}

	/** Replay discontinuities, never fake 30 FPS frames. Named eases are evaluated at exact song time. */
	public function seek(time:Float):Void
	{
		replaying = true;
		position = zoom = rotation = null;
		cursor = 0;
		lastTime = 0;
		state.defaultCamZoom = baseZoom;
		state.camGame.angle = baseAngle;
		var radians = Math.abs(baseAngle) * Math.PI / 180;
		state.smartCamZoomMult = state.smartCamera ? Math.abs(Math.cos(radians)) + (FlxG.width / FlxG.height) * Math.abs(Math.sin(radians)) : 1;
		state.camGame.zoom = baseZoom * state.smartCamZoomMult;
		var p = target(null, 0);
		x = p.x; y = p.y; z = baseZoom; angle = baseAngle;
		p.put();
		var i = 0;
		while (i < moments.length && moments[i] <= time)
		{
			var at = moments[i++];
			// Use the previous target up to a discontinuity, then activate the new target.
			if (at > lastTime) updateReplay(at);
		}
		updateReplay(Math.max(0, time));
		evaluate(Math.max(0, time));
		if (position == null)
		{
			var baseline = target(null, Math.max(0, time));
			state.camFollow.set(baseline.x, baseline.y);
			baseline.put();
		}
		replaying = false;
		apply();
	}

	function updateReplay(time:Float):Void
	{
		while (cursor < frames.length && stepTime(frames[cursor].step) <= time)
		{
			var frame = frames[cursor++];
			var at = stepTime(frame.step);
			evaluate(at, at - 0.00001);
			begin(frame, at);
		}
		evaluate(time, time - 0.00001);
	}

	public function ownsZoom():Bool
	{
		return zoom != null && !(zoom.reset == true && lastTime >= tz.start + tz.duration * 1000);
	}

	public function apply():Void
	{
		state.camFollowPos.setPosition(x, y);
		if (position != null) state.camFollow.set(x, y);
		if (rotation != null)
		{
			var previous = state.smartCamZoomMult;
			state.camGame.angle = angle;
			var radians = Math.abs(angle) * Math.PI / 180;
			state.smartCamZoomMult = state.smartCamera ? Math.abs(Math.cos(radians)) + (FlxG.width / FlxG.height) * Math.abs(Math.sin(radians)) : 1;
			if (!ownsZoom()) state.camGame.zoom *= state.smartCamZoomMult / Math.max(0.0001, previous);
		}
		if (zoom != null && !ownsZoom()) state.defaultCamZoom = baseZoom;
		if (ownsZoom())
		{
			state.defaultCamZoom = Math.max(0.05, z);
			state.camGame.zoom = Math.max(0.05, z) * state.smartCamZoomMult;
		}
	}
}

/** Compact, scrollable version of the dropdown used throughout the engine. */
@:access(FlxUIDropDownMenuCustom)
class CameraChoice extends FlxUIDropDownMenuCustom
{
	public function new(x:Float, y:Float, width:Int, choices:Array<String>, selected:String, change:String->Void)
	{
		var data = FlxUIDropDownMenuCustom.makeStrIdLabelArray(choices);
		for (item in data) item.label = switch (item.name) {
			case 'default': 'Default'; case 'global': 'World position'; case 'dad': 'Opponent';
			case 'bf': 'Boyfriend'; case 'gf': 'Girlfriend'; case 'midpoint': 'Midpoint';
			case 'extra_char': 'Character ID'; case 'position': 'Position'; case 'zoom': 'Zoom';
			case 'rotation': 'Angle'; case 'notes': 'Follow notes'; case 'fixed': 'Fixed';
			default: item.label;
		};
		super(x, y, data, change, new FlxUIDropDownHeader(width));
		selectedId = selected;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (dropPanel.visible)
		{
			var count = Std.int(Math.min(8, list.length - currentScroll));
			var room = Std.int((dropDirection == Up ? header.y - 12 : FlxG.height - header.y - header.height - 12) / 20);
			count = Std.int(Math.max(1, Math.min(count, room)));
			dropPanel.resize(header.background.width, count * 20);
			for (i in 0...list.length)
			{
				list[i].visible = i >= currentScroll && i < currentScroll + count;
				list[i].active = list[i].visible;
			}
		}
	}
}

/** All editor UI, persistence, interaction and runtime helpers intentionally live in this file. */
@:access(PlayState)
@:access(MusicBeatState)
class CameraEditorState extends PlayState
{
	var camEditor:FlxCamera;
	var chrome:FlxSpriteGroup;
	var inspector:FlxUITabMenu;
	var inspectorTab:FlxUI;
	var timeline:FlxSprite;
	var playhead:FlxSprite;
	var timelineSignature:String = '';
	var timelineLabels:FlxTypedGroup<FlxText>;
	var status:FlxText;
	var readout:FlxText;
	var playButton:FlxButton;
	var help:FlxSpriteGroup;
	var dialog:FlxSpriteGroup;
	var selected:CameraKeyframe;
	var selectedSetting:Int = 0;
	var inputs:Array<FlxUIInputText> = [];
	var choices:Array<CameraChoice> = [];
	var timelineChoice:CameraChoice;
	var addKind:String = 'zoom';
	var setters:Map<FlxUINumericStepper, Void->Void> = new Map();
	var pendingInspector:Bool = false;
	var refreshing:Bool = false;
	var ready:Bool = false;
	var uiVisible:Bool = true;
	var freeView:Bool = false;
	var savedContent:String = '';
	var loadError:Bool = false;
	var fpsVisible:Bool = false;
	var undoStack:Array<String> = [];
	var redoStack:Array<String> = [];
	var clipboard:String;
	var message:String = '';
	var messageTime:Float = 0;
	var snap:Float = 1;
	var viewStart:Float = 0;
	var viewSpan:Float = 128;
	var totalSteps:Float = 128;
	var timelineTop:Float;
	var trackX:Float = 78;
	var trackW:Float;
	var inspectorX:Float;
	var inspectorW:Float;
	var cachedW:Int = 0;
	var cachedH:Int = 0;
	var dragging:Bool = false;
	var resizing:CameraSetting;
	var scrubbing:Bool = false;
	var resumeAfterScrub:Bool = false;
	var dragOffset:Float = 0;
	var oldFrameStep:Float = 0;
	var panning:Bool = false;
	var mouseX:Float = 0;
	var mouseY:Float = 0;
	var lastClick:Float = -1000;
	var lastClickStep:Float = -1000;
	var chartEvents:Array<Note.EventNote> = [];
	var mutedKeys:Array<flixel.input.keyboard.FlxKey>;
	var mutedUp:Array<flixel.input.keyboard.FlxKey>;
	var mutedDown:Array<flixel.input.keyboard.FlxKey>;

	inline function setting():CameraSetting
	{
		return selected != null && selectedSetting >= 0 && selectedSetting < selected.settings.length ? selected.settings[selectedSetting] : null;
	}

	override public function create():Void
	{
		isCameraEditor = true;
		cpuControlled = true;
		practiceMode = true;
		PlayState.isStoryMode = false;
		PlayState.startOnTime = 0;
		super.create();
		if (camGame == null || camFollowPos == null) return;
		cpuControlled = true;
		practiceMode = true;
		canPause = canReset = false;
		debugKeysChart = [];
		debugKeysCharacter = [];
		paused = true;
		startSong();
		if (startTimer != null) startTimer.cancel();
		camHUD.visible = false;
		chartEvents = [for (event in eventNotes) Reflect.copy(event)];
		DynamicStreamLoader.kill();
		if (cameraDirector == null) cameraDirector = new CameraDirector(this, cameraTimeline);
		loadError = cameraLoadError;
		camEditor = new FlxCamera();
		camEditor.bgColor = 0;
		FlxG.cameras.add(camEditor, false);
		CustomFadeTransition.nextCamera = camEditor;
		FlxG.mouse.visible = true;
		if (Main.fpsVar != null) { fpsVisible = Main.fpsVar.visible; Main.fpsVar.visible = false; }
		mutedKeys = FlxG.sound.muteKeys;
		mutedUp = FlxG.sound.volumeUpKeys;
		mutedDown = FlxG.sound.volumeDownKeys;
		FlxG.sound.muteKeys = [];
		FlxG.sound.volumeUpKeys = [];
		FlxG.sound.volumeDownKeys = [];
		savedContent = serialize();
		totalSteps = Math.max(16, Conductor.getStep(FlxG.sound.music.length));
		viewSpan = Math.min(totalSteps, 128);
		buildUI();
		ready = true;
		seekTo(0);
		if (loadError) notify('Camera file could not be read. Save is blocked to protect it. See the log.', 12);
		#if desktop
		Discord.DiscordClient.changePresence('Camera Editor', PlayState.SONG.song);
		#end
	}

	// Load the real stage, characters, scripts and strums, without a countdown or player input.
	override public function startCountdown():Void
	{
		if (startedCountdown) return;
		inCutscene = false;
		skipArrowStartTween = true;
		generateStaticArrows(0, 0, 0);
		generateStaticArrows(1, 1, 0);
		startedCountdown = true;
		Conductor.songPosition = 0;
		callOnLuas('onStartCountdown', []);
		setOnLuas('startedCountdown', true);
		callOnLuas('onCountdownStarted', []);
	}

	override function openPauseMenu():Void {}
	override public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		if (!ready) return;
		setPlaying(false);
		seekTo(0);
	}

	override function closeSubState():Void
	{
		var pause = paused;
		paused = false;
		super.closeSubState();
		paused = pause;
	}

	function serialize():String
	{
		return Json.stringify({version: 2, camera_timeline: cameraTimeline}, null, '\t');
	}

	function remember():Void
	{
		var content = serialize();
		if (undoStack.length == 0 || undoStack[undoStack.length - 1] != content) undoStack.push(content);
		if (undoStack.length > 100) undoStack.shift();
		redoStack = [];
	}

	function restore(content:String):Void
	{
		var step = selected == null ? -1 : selected.step;
		cameraTimeline = cast Json.parse(content).camera_timeline;
		selected = null;
		for (frame in cameraTimeline) if (Math.abs(frame.step - step) < 0.0001) selected = frame;
		if (selected == null && cameraTimeline.length > 0) selected = cameraTimeline[0];
		selectedSetting = 0;
		changed(true);
	}

	function undo(redo:Bool = false):Void
	{
		var from = redo ? redoStack : undoStack;
		if (from.length == 0) return;
		(redo ? undoStack : redoStack).push(serialize());
		restore(from.pop());
		notify(redo ? 'Redo' : 'Undo');
	}

	function changed(rebuild:Bool = false):Void
	{
		cameraTimeline.sort(function(a, b) return Reflect.compare(a.step, b.step));
		cameraDirector.frames = cameraTimeline;
		if (!freeView) cameraDirector.seek(Conductor.songPosition);
		if (rebuild) pendingInspector = true;
	}

	function notify(text:String, seconds:Float = 3):Void
	{
		message = text;
		messageTime = seconds;
	}

	function addText(group:FlxSpriteGroup, x:Float, y:Float, w:Float, text:String, size:Int = 12, color:FlxColor = FlxColor.WHITE):FlxText
	{
		var label = new FlxText(x, y, w, text, size);
		label.setFormat(Paths.font('vcr.ttf'), size, color);
		label.scrollFactor.set();
		group.add(label);
		return label;
	}

	function button(group:FlxSpriteGroup, x:Float, y:Float, text:String, action:Void->Void, color:FlxColor = 0xFFD4E6F1):FlxButton
	{
		var btn = new FlxButton(x, y, text, action);
		btn.color = color;
		btn.onUp.callback = function() { if (!menuOpen()) action(); };
		group.add(btn);
		return btn;
	}

	function buildUI():Void
	{
		if (chrome != null) { remove(chrome, true); chrome.destroy(); }
		if (inspector != null) { remove(inspector, true); inspector.destroy(); inspector = null; }
		if (timelineLabels != null) { remove(timelineLabels, true); timelineLabels.destroy(); }
		cachedW = FlxG.width;
		cachedH = FlxG.height;
		timelineTop = FlxG.height - 202;
		trackW = FlxG.width - trackX - 18;
		inspectorW = Math.min(340, Math.max(286, FlxG.width * 0.265));
		inspectorX = FlxG.width - inspectorW - 12;
		chrome = new FlxSpriteGroup();
		chrome.cameras = [camEditor];
		chrome.add(new FlxSprite().makeGraphic(FlxG.width, 48, 0xEE17131F));
		addText(chrome, 14, 6, 350, 'CAMERA EDITOR  /  ' + PlayState.SONG.song, 16);
		readout = addText(chrome, 14, 27, FlxG.width - 450, '', 11, 0xFFCEC4E3);
		button(chrome, FlxG.width - 348, 13, 'Save [^S]', saveCameraConfig, 0xFF8AD490);
		button(chrome, FlxG.width - 262, 13, 'HUD [TAB]', toggleUI);
		button(chrome, FlxG.width - 176, 13, 'Help [H]', toggleHelp);
		button(chrome, FlxG.width - 90, 13, 'Exit', requestExit, 0xFFFFB1B1);
		chrome.add(new FlxSprite(0, timelineTop).makeGraphic(FlxG.width, 202, 0xF2181520));
		playButton = button(chrome, 12, timelineTop + 8, 'Play [SPC]', function() setPlaying(paused), 0xFF8AD490);
		button(chrome, 98, timelineTop + 8, '< Event', function() jumpEvent(-1));
		button(chrome, 184, timelineTop + 8, 'Event >', function() jumpEvent(1));
		button(chrome, 270, timelineTop + 8, 'New [N]', function() addFrame(), 0xFFCCB3FF);
		button(chrome, 356, timelineTop + 8, 'Capture [C]', captureView, 0xFFFFD18C);
		button(chrome, FlxG.width - 262, timelineTop + 8, 'Zoom -', function() zoomTimeline(1.5, 0.5));
		button(chrome, FlxG.width - 176, timelineTop + 8, 'Zoom +', function() zoomTimeline(1 / 1.5, 0.5));
		button(chrome, FlxG.width - 90, timelineTop + 8, 'Fit song', function() { viewStart = 0; viewSpan = totalSteps; });
		addText(chrome, 8, timelineTop + 64, 68, 'EVENTS', 10, 0xFFCEC4E3);
		addText(chrome, 8, timelineTop + 90, 68, 'POSITION', 10, 0xFF9FD7FF);
		addText(chrome, 8, timelineTop + 115, 68, 'ZOOM', 10, 0xFFFFD18C);
		addText(chrome, 8, timelineTop + 140, 68, 'ANGLE', 10, 0xFFD6B0FF);
		timeline = new FlxSprite(trackX, timelineTop + 36).makeGraphic(Std.int(trackW), 126, FlxColor.TRANSPARENT, true);
		chrome.add(timeline);
		playhead = new FlxSprite(trackX, timelineTop + 36).makeGraphic(2, 126, 0xFFFF666E);
		chrome.add(playhead);
		timelineSignature = '';
		timelineChoice = new CameraChoice(78, timelineTop + 170, 112, ['1 step', '1/2 step', '1/4 step', '1 beat', 'Off'], snapLabel(), function(value) {
			snap = switch (value) { case '1/2 step': 0.5; case '1/4 step': 0.25; case '1 beat': 4; case 'Off': 0; default: 1; };
		});
		timelineChoice.dropDirection = Up;
		chrome.add(timelineChoice);
		status = addText(chrome, 202, timelineTop + 174, FlxG.width - 212, '', 11);
		add(chrome);
		timelineLabels = new FlxTypedGroup<FlxText>();
		timelineLabels.cameras = [camEditor];
		add(timelineLabels);
		buildInspector();
		if (help != null) { remove(help, true); help.destroy(); help = null; }
		chrome.visible = timelineLabels.visible = uiVisible;
		inspector.visible = uiVisible;
	}

	function snapLabel():String
	{
		return switch (snap) { case 0.5: '1/2 step'; case 0.25: '1/4 step'; case 4: '1 beat'; case 0: 'Off'; default: '1 step'; };
	}

	function buildInspector():Void
	{
		if (inspector != null) { remove(inspector, true); inspector.destroy(); }
		inputs = [];
		choices = [];
		setters = new Map();
		refreshing = true;
		inspector = new FlxUITabMenu(null, [{name: 'Event', label: 'Camera event'}], true);
		inspector.resize(inspectorW, timelineTop - 66);
		inspector.setPosition(inspectorX, 58);
		inspector.scrollFactor.set();
		inspector.cameras = [camEditor];
		inspectorTab = new FlxUI(null, inspector);
		inspectorTab.name = 'Event';
		var tab = inspectorTab;
		if (selected == null)
		{
			addText(tab, 12, 12, inspectorW - 24, 'No event selected', 16);
			addText(tab, 12, 42, inspectorW - 24,
				'Double-click a timeline lane or press N to create an event.\n\nAn event can hold position, zoom and angle together.\n\nARROWS / IJKL: arrange camera\nQ / E: zoom\nMiddle mouse: drag view\nC: capture view\nF: return to timeline', 12, FlxColor.BLACK);
			button(tab, 12, 242, 'New event', function() addFrame(), 0xFFCCB3FF);
		}
		else
		{
			addText(tab, 12, 8, inspectorW - 24, 'EVENT  /  ' + selected.settings.length + ' settings', 13, FlxColor.BLACK);
			numeric(12, 31, 'Step', selected.step, 0, totalSteps, snap > 0 ? snap : 0.25, 3, function(v) {
				var destination = snapped(v);
				if (occupied(destination, selected)) { notify('Another event is already at that step.'); pendingInspector = true; return; }
				remember(); selected.step = destination; changed();
			});
			button(tab, inspectorW - 178, 47, 'Duplicate', duplicateFrame);
			button(tab, inspectorW - 92, 47, 'Delete', deleteFrame, 0xFFFFB1B1);
			var s = setting();
			if (s == null) { selectedSetting = 0; s = setting(); }
			addText(tab, 12, 78, inspectorW - 110, (selectedSetting + 1) + '/' + selected.settings.length + '  ' + settingName(s), 13, FlxColor.BLACK);
			var prev = button(tab, inspectorW - 94, 78, '<', function() selectSetting(-1));
			prev.setGraphicSize(36, 20); prev.updateHitbox(); prev.label.fieldWidth = 36;
			var next = button(tab, inspectorW - 52, 78, '>', function() selectSetting(1));
			next.setGraphicSize(36, 20); next.updateHitbox(); next.label.fieldWidth = 36;
			var missing = ['position', 'zoom', 'rotation'].filter(function(kind) {
				for (entry in selected.settings) if (entry.kind == kind) return false;
				return true;
			});
			if (missing.length > 0)
			{
				if (missing.indexOf(addKind) < 0) addKind = missing[0];
				choice(12, 105, Std.int(inspectorW - 192), missing, addKind, function(v) addKind = v);
				button(tab, inspectorW - 176, 105, 'Add setting', function() addSetting(addKind), 0xFF8AD490);
			}
			button(tab, inspectorW - 90, 105, 'Remove', removeSetting, 0xFFFFB1B1);
			var y:Float = 139;
			if (s.kind == 'position')
			{
				addText(tab, 12, y, 90, 'Target', 12, FlxColor.BLACK);
				choice(106, y - 1, Std.int(inspectorW - 120), ['global', 'dad', 'bf', 'gf', 'midpoint', 'extra_char', 'default'], s.target, function(v) {
					remember(); s.target = v; changed(true);
				});
				y += 35;
				if (s.target == 'extra_char')
				{
					numeric(12, y, 'Character ID', s.targetId, 0, Math.max(0, extraChars.length - 1), 1, 0, function(v) { remember(); s.targetId = Std.int(v); changed(); });
					y += 42;
				}
				if (s.target != 'default')
				{
					numeric(12, y, s.target == 'global' ? 'World X' : 'Offset X', s.x, -100000, 100000, 10, 2, function(v) { remember(); s.x = v; changed(); });
					numeric(inspectorW / 2, y, s.target == 'global' ? 'World Y' : 'Offset Y', s.y, -100000, 100000, 10, 2, function(v) { remember(); s.y = v; changed(); });
					y += 44;
				}
				addText(tab, 12, y + 3, 90, 'Sing motion', 12, FlxColor.BLACK);
				choice(106, y, Std.int(inspectorW - 120), ['notes', 'fixed'], s.motion, function(v) { remember(); s.motion = v; changed(); });
				y += 36;
			}
			else if (s.kind == 'zoom')
			{
				addText(tab, 12, y + 3, 90, 'Zoom mode', 12, FlxColor.BLACK);
				choice(106, y, Std.int(inspectorW - 120), ['Custom', 'Stage default'], s.reset == true ? 'Stage default' : 'Custom', function(v) {
					remember(); s.reset = v == 'Stage default'; changed(true);
				});
				y += 36;
				if (s.reset != true)
				{
					numeric(12, y, 'Zoom', s.value, 0.05, 10, 0.05, 3, function(v) { remember(); s.value = v; changed(); });
					y += 44;
				}
			}
			else
			{
				numeric(12, y, 'Angle (degrees)', s.value, -3600, 3600, 1, 2, function(v) { remember(); s.value = v; changed(); });
				y += 44;
			}
			addText(tab, 12, y + 3, 90, 'Ease', 12, FlxColor.BLACK);
			choice(106, y, Std.int(inspectorW - 120), CameraDirector.eases, s.ease, function(v) { remember(); s.ease = v; changed(true); });
			y += 32;
			if (s.ease != 'instant')
			{
				numeric(12, y, s.ease == 'default' ? 'Duration (s to 99%)' : 'Duration (seconds)', s.duration, 0, 600, 0.05, 4, function(v) { remember(); s.duration = v; changed(); });
				button(tab, inspectorW - 100, y + 16, 'Auto time', function() {
					remember(); s.duration = CameraDirector.secondsFor(s.kind, cameraSpeed, camZoomingDecay); changed(true);
				});
				y += 44;
			}
			button(tab, 12, y + 4, 'Preview', function() { seekTo(CameraDirector.stepTime(selected.step)); setPlaying(true); }, 0xFF8AD490);
			button(tab, 98, y + 4, 'View target', viewTarget, 0xFFFFD18C);
		}
		// Dropdowns are last so their expanded lists draw above the other fields.
		for (menu in choices) tab.add(menu);
		inspector.addGroup(tab);
		add(inspector);
		inspector.visible = uiVisible;
		inspector.active = !((help != null && help.visible) || dialog != null);
		if (help != null) { remove(help, true); add(help); }
		if (dialog != null) { remove(dialog, true); add(dialog); }
		refreshing = false;
		pendingInspector = false;
	}

	function numeric(x:Float, y:Float, label:String, value:Float, min:Float, max:Float, step:Float, decimals:Int, change:Float->Void):Void
	{
		addText(inspectorTab, x, y, inspectorW / 2 - 12, label, 11, FlxColor.BLACK);
		var input = new FlxUIInputText(0, 0, 78, Std.string(value), 12);
		inputs.push(input);
		var field = new FlxUINumericStepper(x, y + 16, step, value, min, max, decimals, FlxUINumericStepper.STACK_HORIZONTAL, input);
		setters.set(field, function() {
			if (Math.isFinite(field.value)) change(field.value);
		});
		inspectorTab.add(field);
	}

	function choice(x:Float, y:Float, w:Int, items:Array<String>, value:String, change:String->Void):Void
	{
		choices.push(new CameraChoice(x, y, w, items, value, function(v) { if (!refreshing) change(v); }));
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (!refreshing && !menuOpen() && id == FlxUINumericStepper.CHANGE_EVENT && Std.isOfType(sender, FlxUINumericStepper))
		{
			var callback = setters.get(cast sender);
			if (callback != null) callback();
		}
		super.getEvent(id, sender, data, params);
	}

	function settingName(s:CameraSetting):String
	{
		return s == null ? '' : switch (s.kind) { case 'position': 'Camera Position'; case 'zoom': 'Camera Zoom'; default: 'Camera Angle'; };
	}

	function selectSetting(direction:Int):Void
	{
		if (selected == null) return;
		selectedSetting = (selectedSetting + direction + selected.settings.length) % selected.settings.length;
		pendingInspector = true;
	}

	function occupied(step:Float, except:CameraKeyframe = null):Bool
	{
		for (frame in cameraTimeline) if (frame != except && Math.abs(frame.step - step) < 0.0001) return true;
		return false;
	}

	function newSetting(kind:String):CameraSetting
	{
		return {kind: kind, ease: 'default', duration: CameraDirector.secondsFor(kind, cameraSpeed, camZoomingDecay),
			target: 'global', targetId: 0, x: camFollowPos.x, y: camFollowPos.y, value: kind == 'zoom' ? camGame.zoom / smartCamZoomMult : camGame.angle,
			motion: 'notes', reset: false};
	}

	function addFrame(?at:Float, kind:String = 'position'):Void
	{
		var step = snapped(at == null ? Conductor.getStep(Conductor.songPosition) : at);
		for (frame in cameraTimeline) if (Math.abs(frame.step - step) < 0.0001) { selectFrame(frame); return; }
		remember();
		selected = {step: step, settings: [newSetting(kind)]};
		cameraTimeline.push(selected);
		selectedSetting = 0;
		if (kind == 'position') capturePosition(selected.settings[0]);
		freeView = false;
		changed(true);
	}

	function selectFrame(frame:CameraKeyframe):Void
	{
		selected = frame;
		selectedSetting = 0;
		pendingInspector = true;
		seekTo(CameraDirector.stepTime(frame.step));
	}

	function addSetting(kind:String):Void
	{
		if (selected == null) return;
		for (s in selected.settings) if (s.kind == kind) return;
		remember();
		selected.settings.push(newSetting(kind));
		selectedSetting = selected.settings.length - 1;
		if (kind == 'position') capturePosition(setting());
		changed(true);
	}

	function removeSetting():Void
	{
		if (setting() == null) return;
		if (selected.settings.length == 1) { deleteFrame(); return; }
		remember();
		selected.settings.splice(selectedSetting, 1);
		selectedSetting = Std.int(Math.min(selectedSetting, selected.settings.length - 1));
		changed(true);
	}

	function deleteFrame():Void
	{
		if (selected == null) return;
		remember();
		cameraTimeline.remove(selected);
		selected = null;
		selectedSetting = 0;
		changed(true);
	}

	function duplicateFrame():Void
	{
		if (selected == null) return;
		clipboard = Json.stringify(selected.settings);
		var destination = selected.step + (snap > 0 ? snap : 1);
		while (occupied(destination) && destination <= totalSteps) destination += snap > 0 ? snap : 1;
		pasteFrame(destination);
	}

	function pasteFrame(at:Float):Void
	{
		if (clipboard == null) return;
		at = snapped(at);
		if (occupied(at)) { notify('Choose an empty step before pasting.'); return; }
		remember();
		selected = {step: at, settings: cast Json.parse(clipboard)};
		cameraTimeline.push(selected);
		selectedSetting = 0;
		changed(true);
	}

	function capturePosition(s:CameraSetting):Void
	{
		s.target = 'global';
		s.targetId = 0;
		s.x = s.y = 0;
		// Capture the visible composition without adding the singing offset twice.
		var offset = cameraDirector.target(s, Conductor.songPosition);
		s.x = camFollowPos.x - offset.x;
		s.y = camFollowPos.y - offset.y;
		offset.put();
	}

	function captureView():Void
	{
		if (!paused) setPlaying(false);
		remember();
		if (selected == null)
		{
			var step = snapped(Conductor.getStep(Conductor.songPosition));
			for (frame in cameraTimeline) if (Math.abs(frame.step - step) < 0.0001) selected = frame;
			if (selected == null) { selected = {step: step, settings: []}; cameraTimeline.push(selected); }
		}
		var pos:CameraSetting = null;
		var zoom:CameraSetting = null;
		for (s in selected.settings) { if (s.kind == 'position') pos = s; if (s.kind == 'zoom') zoom = s; }
		if (pos == null) { pos = newSetting('position'); selected.settings.push(pos); }
		if (zoom == null) { zoom = newSetting('zoom'); selected.settings.push(zoom); }
		capturePosition(pos);
		zoom.value = camGame.zoom / smartCamZoomMult;
		zoom.reset = false;
		freeView = true; // Keep the composition visible until transport resumes.
		changed(true);
		notify('View captured at step ' + FlxMath.roundDecimal(selected.step, 3));
	}

	function viewTarget():Void
	{
		if (selected == null) return;
		setPlaying(false);
		for (s in selected.settings)
		{
			switch (s.kind) {
				case 'position':
					var p = cameraDirector.target(s, Conductor.songPosition);
					camFollowPos.setPosition(p.x, p.y); p.put();
				case 'zoom': camGame.zoom = (s.reset == true ? cameraDirector.baseZoom : s.value) * smartCamZoomMult;
				case 'rotation': camGame.angle = s.value;
			}
		}
		freeView = true;
	}

	inline function snapped(step:Float):Float
	{
		return FlxMath.bound(snap > 0 && !FlxG.keys.pressed.ALT ? Math.round(step / snap) * snap : step, 0, totalSteps);
	}

	inline function screenStep(x:Float):Float
	{
		return viewStart + (x - trackX) / trackW * viewSpan;
	}

	inline function stepX(step:Float):Float
	{
		return (step - viewStart) / viewSpan * trackW;
	}

	function zoomTimeline(factor:Float, anchor:Float):Void
	{
		var step = viewStart + viewSpan * anchor;
		viewSpan = FlxMath.bound(viewSpan * factor, Math.min(4, totalSteps), totalSteps);
		viewStart = FlxMath.bound(step - viewSpan * anchor, 0, Math.max(0, totalSteps - viewSpan));
	}

	function jumpEvent(direction:Int):Void
	{
		var current = Conductor.getStep(Conductor.songPosition);
		var nearest:CameraKeyframe = null;
		for (frame in cameraTimeline)
			if ((direction < 0 && frame.step < current - 0.001 && (nearest == null || frame.step > nearest.step))
				|| (direction > 0 && frame.step > current + 0.001 && (nearest == null || frame.step < nearest.step))) nearest = frame;
		if (nearest != null) { selectFrame(nearest); revealStep(nearest.step); }
	}

	function revealStep(step:Float):Void
	{
		if (step < viewStart || step > viewStart + viewSpan)
			viewStart = FlxMath.bound(step - viewSpan * 0.25, 0, Math.max(0, totalSteps - viewSpan));
	}

	function drawTimeline():Void
	{
		var playX = stepX(Conductor.getStep(Conductor.songPosition));
		playhead.x = trackX + playX;
		playhead.visible = uiVisible && playX >= 0 && playX <= trackW;
		// Only the playhead moves every frame. Avoid re-uploading the timeline bitmap during playback.
		var signature = serialize() + ':' + viewStart + ':' + viewSpan + ':' + cameraTimeline.indexOf(selected) + ':' + selectedSetting;
		if (signature == timelineSignature) return;
		timelineSignature = signature;
		timeline.pixels.fillRect(timeline.pixels.rect, 0xFF24202D);
		for (label in timelineLabels.members) if (label != null) label.visible = false;
		var labelIndex = 0;
		for (y in [23, 48, 73, 98, 125]) FlxSpriteUtil.drawLine(timeline, 0, y, trackW, y, {color: 0xFF494150, thickness: 1});
		var spacing:Float = 1;
		while (spacing / viewSpan * trackW < 36) spacing *= 2;
		var step = Math.ceil(viewStart / spacing) * spacing;
		while (step <= viewStart + viewSpan)
		{
			var x = stepX(step);
			FlxSpriteUtil.drawLine(timeline, x, 0, x, 126, {color: step % 16 == 0 ? 0xFF615171 : 0xFF38303F, thickness: 1});
			var label:FlxText;
			if (labelIndex < timelineLabels.length) label = timelineLabels.members[labelIndex];
			else
			{
				label = new FlxText(0, 0, 64, '', 10);
				label.setFormat(Paths.font('vcr.ttf'), 10, 0xFFCEC4E3);
				label.scrollFactor.set();
				timelineLabels.add(label);
			}
			labelIndex++;
			label.setPosition(trackX + x + 3, timelineTop + 38);
			label.text = Std.string(FlxMath.roundDecimal(step, 2));
			label.visible = uiVisible && x <= trackW - 30;
			step += spacing;
		}
		for (frame in cameraTimeline)
		{
			var px = stepX(frame.step);
			for (s in frame.settings)
			{
				var row = s.kind == 'position' ? 51 : s.kind == 'zoom' ? 76 : 101;
				var color:FlxColor = s.kind == 'position' ? 0xFF74B8EF : s.kind == 'zoom' ? 0xFFEDB865 : 0xFFB38BE7;
				var end = s.ease == 'instant' ? px : stepX(Conductor.getStep(CameraDirector.stepTime(frame.step) + s.duration * 1000));
				var left = Math.max(0, px);
				var right = Math.min(trackW, end);
				if (right > left) FlxSpriteUtil.drawRect(timeline, left, row + 6, right - left, 8, color & 0x66FFFFFF);
				if (frame == selected && end >= 0 && end <= trackW && s.ease != 'instant')
					FlxSpriteUtil.drawRect(timeline, end - 2, row + 2, 4, 16, color);
				if (px >= 0 && px < trackW)
				{
					FlxSpriteUtil.drawRect(timeline, Math.max(0, px - 3), row + 2, 6, 16, color);
					if (frame == selected && s == setting()) FlxSpriteUtil.drawRect(timeline, px + 5, row + 2, 3, 16, FlxColor.WHITE);
				}
			}
			if (px >= 4 && px <= trackW - 4)
			{
				FlxSpriteUtil.drawRect(timeline, px - 5, 26, 10, 18, frame == selected ? FlxColor.WHITE : 0xFFA88BC7);
				FlxSpriteUtil.drawLine(timeline, px, 44, px, 124, {color: frame == selected ? 0x88FFFFFF : 0x448D719F, thickness: 1});
			}
		}
		// Overview thumb. Dragging this strip scrolls even when the timeline is zoomed in.
		FlxSpriteUtil.drawRect(timeline, 0, 122, trackW, 4, 0xFF121016);
		FlxSpriteUtil.drawRect(timeline, viewStart / totalSteps * trackW, 122, Math.max(4, viewSpan / totalSteps * trackW), 4, 0xFFB49ACD);
		timeline.dirty = true;
	}

	function handleTimeline(mx:Float, my:Float, elapsed:Float):Void
	{
		var localY = my - timelineTop - 36;
		var over = mx >= trackX && mx <= trackX + trackW && localY >= 0 && localY <= 126;
		if (over && FlxG.mouse.wheel != 0)
		{
			if (FlxG.keys.pressed.CONTROL) zoomTimeline(Math.pow(1.25, -FlxG.mouse.wheel), FlxMath.bound((mx - trackX) / trackW, 0, 1));
			else viewStart = FlxMath.bound(viewStart - FlxG.mouse.wheel * viewSpan * 0.08, 0, Math.max(0, totalSteps - viewSpan));
		}
		if (over && FlxG.mouse.justPressed)
		{
			if (localY >= 120) panning = true;
			else
			{
				var hit:CameraKeyframe = null;
				var hitSetting = -1;
				var distance:Float = 10;
				if (selected != null && localY >= 49)
					for (s in selected.settings)
					{
						var row = s.kind == 'position' ? 51 : s.kind == 'zoom' ? 76 : 101;
						var end = trackX + stepX(Conductor.getStep(CameraDirector.stepTime(selected.step) + s.duration * 1000));
						if (s.ease != 'instant' && Math.abs(end - mx) < 7 && localY >= row && localY < row + 22)
						{
							remember(); resizing = s; setPlaying(false); break;
						}
					}
				if (resizing == null)
				{
					for (frame in cameraTimeline)
					{
						var dx = Math.abs(trackX + stepX(frame.step) - mx);
						if (dx < distance && localY >= 24)
						{
							var index = -1;
							if (localY >= 49)
							{
								var kind = localY < 74 ? 'position' : localY < 99 ? 'zoom' : 'rotation';
								for (i in 0...frame.settings.length) if (frame.settings[i].kind == kind) index = i;
								if (index < 0) continue;
							}
							hit = frame; hitSetting = index; distance = dx;
						}
					}
					if (hit != null)
					{
						setPlaying(false);
						selectFrame(hit);
						if (hitSetting >= 0) selectedSetting = hitSetting;
						remember(); dragging = true; oldFrameStep = hit.step;
						dragOffset = screenStep(mx) - hit.step;
					}
					else
					{
						var clickedStep = snapped(screenStep(mx));
						if (localY >= 24 && haxe.Timer.stamp() - lastClick < 0.32 && Math.abs(clickedStep - lastClickStep) < Math.max(1, snap))
						{
							addFrame(clickedStep, localY >= 99 ? 'rotation' : localY >= 74 ? 'zoom' : 'position');
							lastClick = -1000;
						}
						else
						{
							lastClick = haxe.Timer.stamp(); lastClickStep = clickedStep;
							resumeAfterScrub = !paused;
							setPlaying(false); scrubbing = true;
						}
					}
				}
			}
		}
		if (panning && FlxG.mouse.pressed)
			viewStart = FlxMath.bound((mx - trackX) / trackW * totalSteps - viewSpan / 2, 0, Math.max(0, totalSteps - viewSpan));
		if ((dragging || resizing != null) && FlxG.mouse.pressed)
		{
			if (mx < trackX + 16) viewStart -= viewSpan * elapsed * 0.7;
			if (mx > trackX + trackW - 16) viewStart += viewSpan * elapsed * 0.7;
			viewStart = FlxMath.bound(viewStart, 0, Math.max(0, totalSteps - viewSpan));
		}
		if (dragging && selected != null && FlxG.mouse.pressed)
		{
			selected.step = snapped(screenStep(mx) - dragOffset);
			cameraTimeline.sort(function(a, b) return Reflect.compare(a.step, b.step));
			cameraDirector.seek(CameraDirector.stepTime(selected.step));
			Conductor.songPosition = CameraDirector.stepTime(selected.step);
		}
		if (resizing != null && FlxG.mouse.pressed)
		{
			resizing.duration = Math.max(0, (CameraDirector.stepTime(snapped(screenStep(mx))) - CameraDirector.stepTime(selected.step)) / 1000);
			changed();
		}
		if (scrubbing && FlxG.mouse.pressed) seekTo(CameraDirector.stepTime(snapped(screenStep(mx))), false);
		if (FlxG.mouse.justReleased)
		{
			if (dragging)
			{
				if (occupied(selected.step, selected)) { selected.step = oldFrameStep; notify('That step is occupied.'); }
				changed(true);
				seekTo(CameraDirector.stepTime(selected.step));
			}
			if (resizing != null) pendingInspector = true;
			if (scrubbing) { seekTo(Conductor.songPosition); if (resumeAfterScrub) setPlaying(true); }
			dragging = scrubbing = panning = false;
			resizing = null;
		}
	}

	function setPlaying(play:Bool):Void
	{
		if (!ready && play) return;
		if (play)
		{
			if (freeView) cameraDirector.seek(Conductor.songPosition);
			freeView = false;
			FlxG.sound.music.play(false, Conductor.songPosition);
			if (vocals != null && PlayState.SONG.needsVoices) vocals.play(false, Conductor.songPosition);
		}
		else
		{
			FlxG.sound.music.pause();
			if (vocals != null) vocals.pause();
		}
		paused = !play;
		if (playButton != null) playButton.label.text = play ? 'Pause [SPC]' : 'Play [SPC]';
	}

	/** Seeking changes the song clock and reconstructs the same camera channels. */
	public function seekTo(time:Float, rebuildNotes:Bool = true):Void
	{
		if (FlxG.sound.music == null) return;
		time = FlxMath.bound(time, 0, Math.max(0, FlxG.sound.music.length - 1));
		Conductor.songPosition = songTime = time;
		Conductor.lastSongPos = time;
		FlxG.sound.music.time = time;
		if (vocals != null) vocals.time = Math.min(time, vocals.length);
		startingSong = false;
		endingSong = false;
		freeView = false;
		var bpm = Conductor.getBPMFromSeconds(time);
		Conductor.changeBPM(bpm.bpm);
		curDecStep = Conductor.getStep(time);
		curDecBeat = curDecStep / 4;
		curStep = Math.floor(curDecStep);
		curBeat = Math.floor(curDecBeat);
		curSection = 0;
		stepsToDo = 0;
		for (section in PlayState.SONG.notes)
		{
			stepsToDo += Math.round((section.sectionBeats > 0 ? section.sectionBeats : 4) * 4);
			if (stepsToDo > curStep) break;
			curSection++;
		}
		if (rebuildNotes)
		{
			lastStepHit = curStep;
			lastBeatHit = curBeat;
			eventNotes = [for (event in chartEvents) if (event.strumTime >= time) Reflect.copy(event)];
			rebuildChartNotes(time);
			syncSinging(time);
		}
		cameraDirector.seek(time);
		camGame.focusOn(FlxPoint.weak(camFollowPos.x, camFollowPos.y));
	}

	function syncSinging(time:Float):Void
	{
		var latest:Array<Dynamic> = [];
		for (section in PlayState.SONG.notes)
			for (note in section.sectionNotes)
			{
				var at:Float = note[0];
				if (at > time || note[3] == 'No Animation') continue;
				var id = Std.int(note[1] / 4);
				if (section.gfSection && id == 0) id = extraChars.length;
				var previousTime:Float = latest[id] == null ? -1 : latest[id].time;
				if (at >= previousTime)
					latest[id] = {time: note[0], release: note[0] + Math.max(0, note[2]), direction: Std.int(note[1]) % 4,
						alt: section.altAnim || note[3] == 'Alt Animation'};
			}
		for (id in 0...extraChars.length + 1)
		{
			var char = id == extraChars.length ? gf : extraChars[id];
			if (char == null || char.specialAnim) continue;
			var note = latest[id];
			var hold = Conductor.stepCrochet * 1.1 * char.singDuration;
			if (note != null && time < note.release + hold)
			{
				var name = 'sing' + ['LEFT', 'DOWN', 'UP', 'RIGHT'][note.direction];
				if (note.alt && char.animation.getByName(name + '-alt') != null) name += '-alt';
				if (char.animation.getByName(name) != null) char.playAnim(name, true);
				char.holdTimer = Math.max(0, time - note.release) / (1000 * playbackRate);
			}
			else { char.dance(); char.holdTimer = 0; }
		}
	}

	function rebuildChartNotes(time:Float):Void
	{
		for (note in notes.members) if (note != null) note.destroy();
		notes.clear();
		for (note in unspawnNotes) note.destroy();
		unspawnNotes = [];
		for (section in PlayState.SONG.notes)
			for (data in section.sectionNotes)
			{
				var at:Float = data[0];
				if (at + Math.max(0, data[2]) < time - 50) continue;
				var direction = Std.int(data[1]) % 4;
				var id = Std.int(data[1] / 4);
				var player = id == 1 || (id < extraChars.length && extraChars[id] != null && extraChars[id].isPlayer);
				var note = new Note(at, direction);
				note.charNoteID = id;
				note.mustPress = player;
				note.sustainLength = data[2];
				note.gfNote = section.gfSection && id == 0;
				note.noteType = Std.isOfType(data[3], String) ? data[3] : ChartingState.noteTypeList[data[3]];
				note.scrollFactor.set();
				positionNote(note);
				if (at >= time - 50) unspawnNotes.push(note);
				var length = Conductor.getBPMFromSeconds(at).stepCrochet;
				var previous = note;
				if (note.sustainLength > 0)
					for (i in 0...Math.floor(note.sustainLength / length) + 1)
					{
						var sustain = new Note(at + length * i + length / FlxMath.roundDecimal(songSpeed, 2), direction, previous, true);
						sustain.charNoteID = id;
						sustain.mustPress = player;
						sustain.gfNote = note.gfNote;
						sustain.noteType = note.noteType;
						sustain.parent = note;
						note.tail.push(sustain);
						positionNote(sustain);
						if (sustain.strumTime >= time - 50) unspawnNotes.push(sustain); else sustain.ignoreNote = true;
						previous = sustain;
					}
			}
		unspawnNotes.sort(function(a, b) return Reflect.compare(a.strumTime, b.strumTime));
	}

	function positionNote(note:Note):Void
	{
		if (note.mustPress) note.x += FlxG.width / 2;
		else if (ClientPrefs.middleScroll)
		{
			note.x += 310;
			if (note.noteData > 1) note.x += FlxG.width / 2 + 25;
		}
	}

	function textFocused():Bool
	{
		for (input in inputs) if (input.hasFocus) return true;
		return false;
	}

	function menuOpen():Bool
	{
		if (timelineChoice != null && timelineChoice.dropPanel.visible) return true;
		for (menu in choices) if (menu.dropPanel.visible) return true;
		return false;
	}

	function handleKeys(elapsed:Float):Void
	{
		var ctrl = FlxG.keys.pressed.CONTROL;
		if (ctrl && FlxG.keys.justPressed.S) saveCameraConfig();
		if (textFocused() || menuOpen()) return;
		if (ctrl)
		{
			if (FlxG.keys.justPressed.Z) undo(FlxG.keys.pressed.SHIFT);
			if (FlxG.keys.justPressed.Y) undo(true);
			if (FlxG.keys.justPressed.D) duplicateFrame();
			if (FlxG.keys.justPressed.C && selected != null) { clipboard = Json.stringify(selected.settings); notify('Event copied'); }
			if (FlxG.keys.justPressed.V) pasteFrame(Conductor.getStep(Conductor.songPosition));
			return;
		}
		if (FlxG.keys.justPressed.TAB) toggleUI();
		if (FlxG.keys.justPressed.H) toggleHelp();
		if (FlxG.keys.justPressed.ESCAPE) { requestExit(); return; }
		if (FlxG.keys.justPressed.SPACE) setPlaying(paused);
		if (FlxG.keys.justPressed.N) addFrame();
		if (FlxG.keys.justPressed.C) captureView();
		if (FlxG.keys.justPressed.F) { freeView = false; cameraDirector.seek(Conductor.songPosition); }
		if (FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) deleteFrame();
		if (FlxG.keys.justPressed.HOME) { seekTo(0); revealStep(0); }
		if (FlxG.keys.justPressed.END) { seekTo(FlxG.sound.music.length - 1); revealStep(totalSteps); }
		if (FlxG.keys.justPressed.COMMA) jumpEvent(-1);
		if (FlxG.keys.justPressed.PERIOD) jumpEvent(1);
		if (FlxG.keys.pressed.ALT)
		{
			var amount = FlxG.keys.pressed.SHIFT ? 16 : snap > 0 ? snap : 1;
			if (FlxG.keys.justPressed.LEFT) seekTo(CameraDirector.stepTime(Conductor.getStep(Conductor.songPosition) - amount));
			if (FlxG.keys.justPressed.RIGHT) seekTo(CameraDirector.stepTime(Conductor.getStep(Conductor.songPosition) + amount));
			return;
		}
		if (!paused) return;
		var dx = (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.L ? 1 : 0) - (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.J ? 1 : 0);
		var dy = (FlxG.keys.pressed.DOWN || FlxG.keys.pressed.K ? 1 : 0) - (FlxG.keys.pressed.UP || FlxG.keys.pressed.I ? 1 : 0);
		var dz = (FlxG.keys.pressed.E ? 1 : 0) - (FlxG.keys.pressed.Q ? 1 : 0);
		if (dx != 0 || dy != 0 || dz != 0)
		{
			var speed = (FlxG.keys.pressed.SHIFT ? 900 : 300) * elapsed / camGame.zoom;
			camFollowPos.x += dx * speed;
			camFollowPos.y += dy * speed;
			camGame.zoom = FlxMath.bound(camGame.zoom * Math.exp(dz * elapsed * (FlxG.keys.pressed.SHIFT ? 2 : 0.7)), 0.05, 10);
			freeView = true;
		}
	}

	override public function update(elapsed:Float):Void
	{
		if (!ready) { super.update(elapsed); return; }
		if (pendingInspector && !textFocused() && !menuOpen()) buildInspector();
		if (cachedW != FlxG.width || cachedH != FlxG.height) buildUI();
		var modal = (help != null && help.visible) || dialog != null;
		if (!paused && FlxG.sound.music.playing)
		{
			// PlayState advances its clock once below; seed it from the audio clock without double-advancing.
			Conductor.songPosition = Math.max(0, FlxG.sound.music.time - elapsed * 1000 * playbackRate);
		}
		for (field in setters.keys()) field.active = !menuOpen();
		super.update(paused ? 0 : elapsed);
		if (modal)
		{
			if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.H)
			{
				if (dialog != null) closeDialog(); else toggleHelp();
			}
			return;
		}
		handleKeys(elapsed);
		if ((help != null && help.visible) || dialog != null) return;
		var p = FlxG.mouse.getScreenPosition(camEditor);
		var mx = p.x;
		var my = p.y;
		p.put();
		if (uiVisible && !menuOpen() && !textFocused()) handleTimeline(mx, my, elapsed);
		var overScene = !uiVisible || (my > 48 && my < timelineTop && mx < inspectorX - 8);
		if (overScene && paused && !textFocused() && !menuOpen())
		{
			if (FlxG.mouse.pressedMiddle && !FlxG.mouse.justPressedMiddle)
			{
				camFollowPos.x -= (mx - mouseX) / camGame.zoom;
				camFollowPos.y -= (my - mouseY) / camGame.zoom;
				freeView = true;
			}
			if (FlxG.mouse.wheel != 0) { camGame.zoom = FlxMath.bound(camGame.zoom * Math.pow(1.1, FlxG.mouse.wheel), 0.05, 10); freeView = true; }
		}
		mouseX = mx; mouseY = my;
		if (!paused && !dragging && !scrubbing) revealStep(Conductor.getStep(Conductor.songPosition));
		messageTime -= elapsed;
		readout.text = (freeView ? 'FREE VIEW  [C capture / F return]' : paused ? 'PAUSED' : 'PLAYING')
			+ ' | ' + timecode(Conductor.songPosition) + ' / ' + timecode(FlxG.sound.music.length)
			+ ' | Step ' + FlxMath.roundDecimal(Conductor.getStep(Conductor.songPosition), 2)
			+ ' | ' + (serialize() != savedContent ? '* UNSAVED' : 'Saved');
		status.text = messageTime > 0 ? message : 'X ' + FlxMath.roundDecimal(camFollowPos.x, 1) + '  Y ' + FlxMath.roundDecimal(camFollowPos.y, 1)
			+ '  Zoom ' + FlxMath.roundDecimal(camGame.zoom, 3) + ' | ARROWS: camera  ALT+ARROWS: seek  CTRL+wheel: timeline zoom';
		if (uiVisible) drawTimeline();
	}

	static function timecode(ms:Float):String
	{
		var seconds = Std.int(ms / 1000);
		return Std.int(seconds / 60) + ':' + StringTools.lpad(Std.string(seconds % 60), '0', 2) + '.' + StringTools.lpad(Std.string(Std.int(ms % 1000)), '0', 3);
	}

	function toggleUI():Void
	{
		uiVisible = !uiVisible;
		timelineSignature = '';
		chrome.visible = inspector.visible = timelineLabels.visible = uiVisible;
		if (!uiVisible)
		{
			for (input in inputs) input.hasFocus = false;
			for (menu in choices) if (menu.dropPanel.visible) @:privateAccess menu.showList(false);
			if (timelineChoice.dropPanel.visible) @:privateAccess timelineChoice.showList(false);
		}
	}

	function toggleHelp():Void
	{
		if (help != null && help.visible) { help.visible = false; chrome.active = inspector.active = true; return; }
		setPlaying(false);
		if (help == null)
		{
			help = new FlxSpriteGroup();
			help.cameras = [camEditor];
			help.add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xF0181421));
			addText(help, 70, 48, FlxG.width - 140, 'CAMERA EDITOR', 26, 0xFFD4B6FF);
			addText(help, 70, 105, FlxG.width - 140,
				'SPACE: play/pause    HOME / END: song start/end    , / .: previous/next event\n\n'
				+ 'ARROWS or IJKL: arrange camera    SHIFT: faster    Q/E or scene wheel: zoom\n'
				+ 'Middle mouse drag: pan    C: capture position + zoom into selected event\n'
				+ 'F: discard free view and return to the timeline camera    TAB: clean runtime view\n\n'
				+ 'Timeline ruler/empty space: seek    Double-click lane / N: new event\n'
				+ 'Drag marker: move entire event    Drag channel endpoint: change its duration\n'
				+ 'Wheel: scroll timeline    CTRL+wheel: zoom at cursor    Bottom strip: overview\n'
				+ 'Snap selector: timeline grid    ALT while dragging: bypass snap\n'
				+ 'ALT+LEFT/RIGHT: seek one grid unit    ALT+SHIFT+LEFT/RIGHT: seek 16 steps\n\n'
				+ 'CTRL+S: save camera.json    CTRL+Z / CTRL+SHIFT+Z / CTRL+Y: undo / redo\n'
				+ 'CTRL+C / CTRL+V: copy/paste event    CTRL+D: duplicate    DELETE: remove event\n\n'
				+ 'Each event holds independent position, zoom and angle settings.\n'
				+ 'Position target Default returns to chart focus; Stage default resets zoom.\n'
				+ 'Sing motion: notes keeps the runtime direction offsets; fixed holds the frame.\n'
				+ 'Default ease uses normal camera follow; duration is seconds to 99% of the move.\n'
				+ 'Other ease durations are exact song seconds. Instant has no duration.\n\n'
				+ 'H / ESC: close help', 16);
			button(help, FlxG.width - 150, FlxG.height - 50, 'Close [H]', toggleHelp);
			add(help);
		}
		help.visible = true;
		chrome.active = inspector.active = false;
	}

	public function saveCameraConfig():Void
	{
		if (loadError) { notify('Save blocked: repair the existing camera.json first.', 6); return; }
		#if sys
		var path = PlayState.getCameraSavePath(PlayState.SONG.song);
		try
		{
			var content = serialize();
			var dir = haxe.io.Path.directory(path);
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			// A failed write leaves the previous file intact.
			sys.io.File.saveContent(path + '.tmp', content);
			sys.FileSystem.rename(path + '.tmp', path);
			savedContent = content;
			notify('Saved: ' + path, 5);
		}
		catch (error:Dynamic) { notify('Save failed: ' + Std.string(error), 8); }
		#else
		notify('Saving camera.json requires a desktop build.', 5);
		#end
	}

	function requestExit():Void
	{
		if (dialog != null) return;
		if (serialize() == savedContent) { exitEditor(); return; }
		setPlaying(false);
		chrome.active = inspector.active = false;
		dialog = new FlxSpriteGroup();
		dialog.cameras = [camEditor];
		dialog.add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xDC17121F));
		var x = (FlxG.width - 400) / 2;
		var y = FlxG.height / 2 - 70;
		addText(dialog, x, y, 400, 'Save camera changes before leaving?', 18);
		button(dialog, x, y + 68, 'Save & exit', function() { saveCameraConfig(); if (serialize() == savedContent) exitEditor(); }, 0xFF8AD490);
		button(dialog, x + 130, y + 68, 'Discard', exitEditor, 0xFFFFB1B1);
		button(dialog, x + 260, y + 68, 'Cancel', closeDialog);
		add(dialog);
	}

	function closeDialog():Void
	{
		if (dialog == null) return;
		remove(dialog, true);
		dialog.destroy();
		dialog = null;
		chrome.active = inspector.active = true;
	}

	public function exitEditor():Void
	{
		setPlaying(false);
		MusicBeatState.switchState(new CameraSongSelectState());
	}

	override public function destroy():Void
	{
		if (mutedKeys != null) FlxG.sound.muteKeys = mutedKeys;
		if (mutedUp != null) FlxG.sound.volumeUpKeys = mutedUp;
		if (mutedDown != null) FlxG.sound.volumeDownKeys = mutedDown;
		FlxG.mouse.visible = false;
		if (Main.fpsVar != null) Main.fpsVar.visible = fpsVisible;
		FlxUI.forceFocus(false, null);
		super.destroy();
	}
}
