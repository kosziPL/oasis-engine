package editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.ui.FlxButton;
import PlayState.CameraEvent;
import PlayState.CameraData;
import Section.SwagSection;
import Song.SwagSong;
import Character;
import openfl.utils.Assets as OpenFlAssets;
import FlxUIDropDownMenuCustom;
import openfl.display.BitmapData;

using StringTools;

// ─── Helper pin sprite ────────────────────────────────────────────────────────
class CameraPin extends FlxSprite
{
	public var event:CameraEvent;
	public function new(event:CameraEvent)
	{
		super();
		this.event = event;
	}
}

// ─── Main Editor ─────────────────────────────────────────────────────────────
class CameraEditorState extends PlayState
{
	// Editor UI camera (draws on top of everything)
	var camEditor:FlxCamera;

	// Viewfinder and HUD overlays
	var topBar:FlxSprite;
	var bottomBar:FlxSprite;
	var guideFrame:FlxSprite;
	var infoBG:FlxSprite;
	var playbackBG:FlxSprite;
	var recStatusText:FlxText;
	var hudTimecodeText:FlxText;
	var _recBlinkTimer:Float = 0;
	var _splineDirty:Bool    = true;
	var lastMouseX:Int = 0;
	var lastMouseY:Int = 0;
	var helpPanel:FlxSpriteGroup;

	var draggingPin:CameraPin = null;
	var _isScrubbing:Bool = false;

	var infoText:FlxText;
	var playbackText:FlxText;
	var tipText:FlxText;
	var isUIVisible:Bool = true;

	// Manual-pan mode (IJKL / UO keys)
	var isManualPanning:Bool = false;

	// Camera state tracking variables for event-driven rendering
	var lastCamX:Float = 0;
	var lastCamY:Float = 0;
	var lastCamZoom:Float = 0;

	// ── Timeline ─────────────────────────────────────────────────────────────
	var timelineBG:FlxSprite;
	var timelineProgress:FlxSprite;   // Playhead bar
	var timelineTrack:FlxSprite;       // Thin coloured track fill
	var pinsGroup:FlxTypedGroup<CameraPin>;
	static inline var TL_X:Float      = 30;
	static inline var TL_Y:Float      = 648;
	static inline var TL_W:Float      = 1220;
	static inline var TL_H:Float      = 18;

	// Timeline zoom variables
	var timelineZoom:Float = 1.0;
	var timelineStartStep:Float = 0.0;
	var timelineEndStep:Float = 0.0;
	var lastStartStep:Float = -1;
	var lastEndStep:Float = -1;

	// ── Spline canvas ────────────────────────────────────────────────────────
	var splineCanvas:FlxSprite;

	// ── Inspector state ──────────────────────────────────────────────────────
	var selectedStep:Float        = -1;
	var curEventSelected:Int      = 0;
	var _suppressUIUpdate:Bool    = false;

	var selectedEvent(get, never):CameraEvent;
	inline function get_selectedEvent():CameraEvent
	{
		return getSelectedSubEvent();
	}

	// ── Inspector widgets ────────────────────────────────────────────────────
	var UI_mainbox:FlxUITabMenu;
	var selectedSubEventText:FlxText;
	var prevSubEventBtn:FlxButton;
	var nextSubEventBtn:FlxButton;
	var addSubEventBtn:FlxButton;
	var removeSubEventBtn:FlxButton;
	var targetTypeDropdown:FlxUIDropDownMenuCustom;
	var targetIdStepper:FlxUINumericStepper;
	var isRelativeCheckbox:FlxUICheckBox;
	var standaloneCheckbox:FlxUICheckBox;
	var lockNoteCheckbox:FlxUICheckBox;
	var easeDropdown:FlxUIDropDownMenuCustom;
	var durationStepper:FlxUINumericStepper;
	var zoomStepper:FlxUINumericStepper;
	var xStepper:FlxUINumericStepper;
	var yStepper:FlxUINumericStepper;
	var stepLabel:FlxText;

	var targetIdLabel:FlxText;
	var xLabel:FlxText;
	var yLabel:FlxText;
	var durationLabel:FlxText;
	var zoomLabel:FlxText;
	var easeLabel:FlxText;

	// ─────────────────────────────────────────────────────────────────────────
	override function create()
	{
		// Bot-play so notes don't require input
		cpuControlled = true;
		practiceMode  = true;

		super.create();
		isCameraEditor = true;

		// ── Hide gameplay HUD ──────────────────────────────────────────────
		if (camHUD != null)
		{
			camHUD.visible = false;
			camHUD.alpha   = 0;
		}
		cpuControlled = true;  // re-enforce after super.create()
		camZooming = false;    // prevent beat hits from bouncing the camera and messing up visualizer

		// ── Create dedicated editor UI camera ─────────────────────────────
		camEditor = new FlxCamera();
		camEditor.bgColor.alpha = 0;
		FlxG.cameras.add(camEditor, false);


		// ── Spline canvas (full-screen bitmap, drawn with FlxSpriteUtil) ──
		splineCanvas = new FlxSprite(0, 0);
		splineCanvas.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
		splineCanvas.scrollFactor.set(0, 0);
		splineCanvas.cameras = [camEditor];
		add(splineCanvas);

		// ── Cinematic bars backgrounds ────────────────────────────────────
		topBar = new FlxSprite(0, 0);
		topBar.makeGraphic(FlxG.width, 55, 0x00000000);
		FlxSpriteUtil.drawRect(topBar, 0, 0, FlxG.width, 55, 0xCC08080A);
		FlxSpriteUtil.drawLine(topBar, 0, 54, FlxG.width, 54, {color: 0x4400FFFF, thickness: 1});
		topBar.scrollFactor.set(0, 0);
		topBar.cameras = [camEditor];
		add(topBar);

		bottomBar = new FlxSprite(0, 585);
		bottomBar.makeGraphic(FlxG.width, 135, 0x00000000);
		FlxSpriteUtil.drawRect(bottomBar, 0, 0, FlxG.width, 135, 0xCC08080A);
		FlxSpriteUtil.drawLine(bottomBar, 0, 0, FlxG.width, 0, {color: 0x4400FFFF, thickness: 1});
		bottomBar.scrollFactor.set(0, 0);
		bottomBar.cameras = [camEditor];
		add(bottomBar);

		// ── Viewfinder Guides ─────────────────────────────────────────────
		guideFrame = new FlxSprite(0, 0);
		guideFrame.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
		var safeX:Float = 40;
		var safeY:Float = 55 + 30;
		var safeW:Float = FlxG.width - 80;
		var safeH:Float = (585 - 55) - 60;
		FlxSpriteUtil.drawRect(guideFrame, safeX, safeY, safeW, safeH, FlxColor.TRANSPARENT, {color: 0x22FFFFFF, thickness: 1});
		
		var cx:Float = FlxG.width * 0.5;
		var cy:Float = 55 + (585 - 55) * 0.5;
		FlxSpriteUtil.drawLine(guideFrame, cx - 15, cy, cx + 15, cy, {color: 0x33FFFFFF, thickness: 1});
		FlxSpriteUtil.drawLine(guideFrame, cx, cy - 15, cx, cy + 15, {color: 0x33FFFFFF, thickness: 1});
		guideFrame.scrollFactor.set(0, 0);
		guideFrame.cameras = [camEditor];
		add(guideFrame);

		// ── Timeline ──────────────────────────────────────────────────────
		// Background strip
		timelineBG = new FlxSprite(TL_X, TL_Y)
			.makeGraphic(Std.int(TL_W), Std.int(TL_H) + 4, 0xFF1A1A1A);
		timelineBG.scrollFactor.set(0, 0);
		timelineBG.cameras = [camEditor];
		add(timelineBG);

		// Accent line (track colour)
		timelineTrack = new FlxSprite(TL_X, TL_Y + Std.int(TL_H) - 2)
			.makeGraphic(Std.int(TL_W), 3, 0xFF5544AA);
		timelineTrack.scrollFactor.set(0, 0);
		timelineTrack.cameras = [camEditor];
		add(timelineTrack);

		// Playhead (red vertical bar — positioned by x only)
		timelineProgress = new FlxSprite(TL_X, TL_Y - 4)
			.makeGraphic(3, Std.int(TL_H) + 8, FlxColor.RED);
		timelineProgress.scrollFactor.set(0, 0);
		timelineProgress.cameras = [camEditor];
		add(timelineProgress);

		// ── Pin group ─────────────────────────────────────────────────────
		pinsGroup = new FlxTypedGroup<CameraPin>();
		add(pinsGroup);

		// ── Floating panels backgrounds ───────────────────────────────────
		infoBG = new FlxSprite(10, 70);
		infoBG.makeGraphic(240, 185, 0x00000000);
		FlxSpriteUtil.drawRect(infoBG, 0, 0, 240, 185, 0x9908080A);
		FlxSpriteUtil.drawRect(infoBG, 0, 0, 240, 185, FlxColor.TRANSPARENT, {color: 0x22FFFFFF, thickness: 1});
		infoBG.scrollFactor.set(0, 0);
		infoBG.cameras = [camEditor];
		add(infoBG);

		playbackBG = new FlxSprite(10, 270);
		playbackBG.makeGraphic(240, 115, 0x00000000);
		FlxSpriteUtil.drawRect(playbackBG, 0, 0, 240, 115, 0x9908080A);
		FlxSpriteUtil.drawRect(playbackBG, 0, 0, 240, 115, FlxColor.TRANSPARENT, {color: 0x22FFFFFF, thickness: 1});
		playbackBG.scrollFactor.set(0, 0);
		playbackBG.cameras = [camEditor];
		add(playbackBG);

		// ── Info panel (top-left, inside BG) ──────────────────────────────
		infoText = new FlxText(20, 80, 220, "", 13);
		infoText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, 0xFF000000);
		infoText.scrollFactor.set(0, 0);
		infoText.cameras = [camEditor];
		add(infoText);

		// ── Playback / time panel (below info, inside BG) ─────────────────
		playbackText = new FlxText(20, 280, 220, "", 13);
		playbackText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, 0xFF000000);
		playbackText.scrollFactor.set(0, 0);
		playbackText.cameras = [camEditor];
		add(playbackText);

		// ── Media Controls (above timeline) ───────────────────────────────
		var mcX = TL_X;
		var mcY = TL_Y - 30;
		
		var playPauseBtn = new FlxButton(mcX, mcY, "Play / Pause", function() {
			if (!paused) {
				paused = true;
				FlxG.sound.music.pause();
				if (vocals != null) vocals.pause();
			} else {
				isManualPanning = false;
				paused = false;
				if (FlxG.sound.music != null) { FlxG.sound.music.time = Conductor.songPosition; FlxG.sound.music.play(); }
				if (vocals != null) { vocals.time = Conductor.songPosition; vocals.play(); }
				previousFrameTime = FlxG.game.ticks;
			}
		});
		playPauseBtn.color = 0xFF8ECAFF; // Blue
		playPauseBtn.cameras = [camEditor];
		add(playPauseBtn);

		var prevBtn = new FlxButton(mcX + 90, mcY, "Prev Event", function() {
			var curStep = Conductor.songPosition / Conductor.stepCrochet;
			var targetStep = 0.0;
			for (i in 0...cameraEvents.length) {
				var ev = cameraEvents[cameraEvents.length - 1 - i];
				if (ev.step < curStep - 0.05) { targetStep = ev.step; break; }
			}
			seekTo(targetStep * Conductor.stepCrochet);
		});
		prevBtn.color = 0xFFCCCCCC;      // Grey
		prevBtn.cameras = [camEditor];
		add(prevBtn);

		var nextBtn = new FlxButton(mcX + 180, mcY, "Next Event", function() {
			var curStep = Conductor.songPosition / Conductor.stepCrochet;
			for (ev in cameraEvents) {
				if (ev.step > curStep + 0.05) {
					seekTo(ev.step * Conductor.stepCrochet);
					break;
				}
			}
		});
		nextBtn.color = 0xFFCCCCCC;      // Grey
		nextBtn.cameras = [camEditor];
		add(nextBtn);

		var addPinBtn = new FlxButton(mcX + 270, mcY, "Add Event", onAddEvent);
		addPinBtn.color = 0xFF8AD490;    // Green
		addPinBtn.cameras = [camEditor];
		add(addPinBtn);
		
		var helpBtn = new FlxButton(TL_X + TL_W - 80, mcY, "Help [H]", function() {
			helpPanel.visible = !helpPanel.visible;
		});
		helpBtn.color = 0xFFFFC374;      // Orange/Yellow
		helpBtn.cameras = [camEditor];
		add(helpBtn);

		// Help Panel gets added at the very end of create() to render over everything else.

		// ── Viewfinder HUD overlays ───────────────────────────────────────
		recStatusText = new FlxText(FlxG.width - 250, 16, 230, "STBY", 16);
		recStatusText.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFB300, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		recStatusText.scrollFactor.set(0, 0);
		recStatusText.cameras = [camEditor];
		add(recStatusText);

		hudTimecodeText = new FlxText(0, 15, FlxG.width, "00:00:00:00", 20);
		hudTimecodeText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hudTimecodeText.scrollFactor.set(0, 0);
		hudTimecodeText.cameras = [camEditor];
		add(hudTimecodeText);

		// ── Inspector panel (right side) ──────────────────────────────────
		buildInspector();

		// ── Initial state ─────────────────────────────────────────────────
		recreatePins();
		if (FlxG.sound.music != null && FlxG.sound.music.length > 0)
			drawTimelineTicks();

		FlxG.mouse.visible = true;

		if (cameraEvents.length > 0)
		{
			selectedStep = cameraEvents[0].step;
			curEventSelected = 0;
		}
		refreshInspector();

		// Start paused
		paused = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.pause();
		if (vocals != null)
			vocals.pause();

		// Auto-convert Psych Engine "Set Camera Pos" events to camera.json events if we have none
		if (cameraEvents.length == 0 && eventNotes != null)
		{
			for (e in eventNotes)
			{
				if (e.event == 'Set Camera Pos')
				{
					var stepF = e.strumTime / Conductor.stepCrochet;
					stepF = Math.fround(stepF * 4.0) / 4.0;
					var valX:Float = Std.parseFloat(e.value1);
					var valY:Float = Std.parseFloat(e.value2);
					var isReset:Bool = Math.isNaN(valX) || Math.isNaN(valY);

					if (!isReset)
					{
						addOrUpdateEvent(stepF, "global", 0, false, valX, valY, defaultCamZoom, "linear", 0.0, false, false);
					}
				}
			}
		}

		// ── Help Panel (hidden by default, added last to draw on top of everything) ───────────────────
		helpPanel = new FlxSpriteGroup();
		var helpBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xDD000000);
		helpPanel.add(helpBG);
		var helpTxt = new FlxText(0, 0, FlxG.width, 
			"=== CAMERA EDITOR HELP ===\n\n" +
			"[SPACE] - Play / Pause playback\n" +
			"[LEFT/RIGHT] - Seek song position by 10 seconds\n" +
			"[SHIFT] + [LEFT/RIGHT] - Seek song position by 4 beats\n" +
			"[R] - Seek to song start (0s)\n" +
			"[END] - Seek to song end\n" +
			"[H] - Toggle this Help Screen\n" +
			"[TAB] - Toggle entire HUD/UI visibility\n\n" +
			"[I / J / K / L] - Pan camera (Up / Left / Down / Right) (Hold [SHIFT] for 3x speed)\n" +
			"[U / O] - Zoom camera out / in (Hold [SHIFT] for 3x speed)\n" +
			"[Middle Mouse / Right Click Drag] - Drag to pan camera viewport manually\n\n" +
			"[C] - Capture current camera viewport values to inspector fields\n" +
			"[CTRL] + [S] - Save all camera events database to camera.json config file\n" +
			"[CTRL + Click] or [M + Click] - Teleport camera target coordinate to mouse click\n" +
			"[Scroll Wheel over Timeline] - Zoom timeline view bounds in / out (1x - 50x)\n\n" +
			"Note: Timeline scrolling freezes automatically while dragging pins or scrubbing.\n" +
			"Click anywhere or press H / ESCAPE to close this panel.", 16);
		helpTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		helpTxt.screenCenter();
		helpPanel.add(helpTxt);
		helpPanel.scrollFactor.set(0, 0);
		helpPanel.cameras = [camEditor];
		helpPanel.visible = false;
		add(helpPanel);
	}

	// ─── Bypass pause menu & song end ────────────────────────────────────────
	override function openPauseMenu() { /* blocked */ }

	override public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		seekTo(0);
	}

	// ─── Suppress base-class camera systems when paused ──────────────────────
	override function moveCameraSection():Void
	{
		if (paused) return;
		super.moveCameraSection();
	}

	override public function moveCamera(isDad:Bool):Void
	{
		if (paused) return;
		super.moveCamera(isDad);
	}

	override public function updateCameraEvents(elapsed:Float):Void
	{
		if (paused && isManualPanning) return;

		var selectedSubEvent:CameraEvent = getSelectedSubEvent();
		if (paused && selectedSubEvent != null)
		{
			// Backup original values
			var oldTargetType = selectedSubEvent.target_type;
			var oldTargetId = selectedSubEvent.target_id;
			var oldIsRelative = selectedSubEvent.is_relative;
			var oldX = selectedSubEvent.x;
			var oldY = selectedSubEvent.y;
			var oldZoom = selectedSubEvent.zoom;
			var oldEase = selectedSubEvent.ease;
			var oldDuration = selectedSubEvent.duration;
			var oldStandalone = selectedSubEvent.standalone;
			var oldLockNote = selectedSubEvent.lock_note_movement;

			// Temporarily write the UI values into the event object for previewing
			selectedSubEvent.target_type = (targetTypeDropdown != null) ? targetTypeDropdown.selectedId : oldTargetType;
			selectedSubEvent.target_id = (targetIdStepper != null) ? Std.int(targetIdStepper.value) : oldTargetId;
			selectedSubEvent.is_relative = (isRelativeCheckbox != null) ? isRelativeCheckbox.checked : oldIsRelative;
			selectedSubEvent.x = (xStepper != null) ? xStepper.value : oldX;
			selectedSubEvent.y = (yStepper != null) ? yStepper.value : oldY;
			selectedSubEvent.zoom = (zoomStepper != null) ? zoomStepper.value : oldZoom;
			selectedSubEvent.ease = (easeDropdown != null) ? easeDropdown.selectedId : oldEase;
			selectedSubEvent.duration = (durationStepper != null) ? durationStepper.value : oldDuration;
			selectedSubEvent.standalone = (standaloneCheckbox != null) ? standaloneCheckbox.checked : oldStandalone;
			selectedSubEvent.lock_note_movement = (lockNoteCheckbox != null) ? lockNoteCheckbox.checked : oldLockNote;

			super.updateCameraEvents(elapsed);

			// Restore original values
			selectedSubEvent.target_type = oldTargetType;
			selectedSubEvent.target_id = oldTargetId;
			selectedSubEvent.is_relative = oldIsRelative;
			selectedSubEvent.x = oldX;
			selectedSubEvent.y = oldY;
			selectedSubEvent.zoom = oldZoom;
			selectedSubEvent.ease = oldEase;
			selectedSubEvent.duration = oldDuration;
			selectedSubEvent.standalone = oldStandalone;
			selectedSubEvent.lock_note_movement = oldLockNote;
		}
		else
		{
			super.updateCameraEvents(elapsed);
		}
	}

	// ─── Helper method to block hasActiveCameraEvent during manual pan zoom code
	override function hasActiveCameraEvent():Bool
	{
		if (paused) return false;
		return super.hasActiveCameraEvent();
	}

	// ─────────────────────────────────────────────────────────────────────────
	//  INSPECTOR BUILD
	// ─────────────────────────────────────────────────────────────────────────
	function buildInspector():Void
	{
		var tabs = [{name: "Event", label: "Camera Event"}];
		UI_mainbox = new FlxUITabMenu(null, tabs, true);
		UI_mainbox.resize(330, 420);
		UI_mainbox.x = FlxG.width - UI_mainbox.width - 10;
		UI_mainbox.y = 65;
		UI_mainbox.scrollFactor.set(0, 0);
		UI_mainbox.cameras = [camEditor];

		var tab = new FlxUI(null, UI_mainbox);
		tab.name = "Event";

		// Step info label (cyan)
		stepLabel = new FlxText(10, 6, 310, "Step: - (no event)", 12);
		stepLabel.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.CYAN);
		tab.add(stepLabel);

		// Sub-event navigation widgets
		selectedSubEventText = new FlxText(10, 25, 130, "Sub-Event: None", 10);
		selectedSubEventText.cameras = [camEditor];
		tab.add(selectedSubEventText);

		prevSubEventBtn = new FlxButton(145, 22, "<", function() { changeSubEventSelected(-1); });
		prevSubEventBtn.color = 0xFFD4E6F1; // Lighter blue/grey
		prevSubEventBtn.setGraphicSize(35, 20);
		prevSubEventBtn.updateHitbox();
		prevSubEventBtn.label.size = 12;
		prevSubEventBtn.label.fieldWidth = 35;
		prevSubEventBtn.label.alignment = CENTER;
		for (point in prevSubEventBtn.labelOffsets) point.set(0, 3);
		prevSubEventBtn.cameras = [camEditor];
		tab.add(prevSubEventBtn);

		nextSubEventBtn = new FlxButton(190, 22, ">", function() { changeSubEventSelected(1); });
		nextSubEventBtn.color = 0xFFD4E6F1; // Lighter blue/grey
		nextSubEventBtn.setGraphicSize(35, 20);
		nextSubEventBtn.updateHitbox();
		nextSubEventBtn.label.size = 12;
		nextSubEventBtn.label.fieldWidth = 35;
		nextSubEventBtn.label.alignment = CENTER;
		for (point in nextSubEventBtn.labelOffsets) point.set(0, 3);
		nextSubEventBtn.cameras = [camEditor];
		tab.add(nextSubEventBtn);

		addSubEventBtn = new FlxButton(235, 22, "+", onAddSubEvent);
		addSubEventBtn.color = 0xFF8AD490;  // Green
		addSubEventBtn.setGraphicSize(35, 20);
		addSubEventBtn.updateHitbox();
		addSubEventBtn.label.size = 12;
		addSubEventBtn.label.fieldWidth = 35;
		addSubEventBtn.label.alignment = CENTER;
		for (point in addSubEventBtn.labelOffsets) point.set(0, 3);
		addSubEventBtn.cameras = [camEditor];
		tab.add(addSubEventBtn);

		removeSubEventBtn = new FlxButton(280, 22, "-", onRemoveSubEvent);
		removeSubEventBtn.color = 0xFFFF8F8F; // Red
		removeSubEventBtn.setGraphicSize(35, 20);
		removeSubEventBtn.updateHitbox();
		removeSubEventBtn.label.size = 12;
		removeSubEventBtn.label.fieldWidth = 35;
		removeSubEventBtn.label.alignment = CENTER;
		for (point in removeSubEventBtn.labelOffsets) point.set(0, 3);
		removeSubEventBtn.cameras = [camEditor];
		tab.add(removeSubEventBtn);

		// Target ID stepper (right side, added BEFORE its dropdown so dropdown draws on top)
		targetIdStepper = new FlxUINumericStepper(215, 70, 1, 0, 0, 99, 0);
		targetIdStepper.cameras = [camEditor];
		tab.add(targetIdStepper);
		targetIdLabel = new FlxText(215, 55, 0, "Target ID (extra):", 10);
		targetIdLabel.cameras = [camEditor];
		tab.add(targetIdLabel);

		// Checkboxes
		isRelativeCheckbox = new FlxUICheckBox(10, 105, null, null, "Relative to character?", 150);
		isRelativeCheckbox.callback = function()
		{
			if (!_suppressUIUpdate)
			{
				isManualPanning = false;
				_splineDirty = true;
			}
		};
		isRelativeCheckbox.cameras = [camEditor];
		tab.add(isRelativeCheckbox);

		standaloneCheckbox = new FlxUICheckBox(170, 105, null, null, "Standalone mode", 140);
		standaloneCheckbox.callback = function()
		{
			if (!_suppressUIUpdate)
			{
				isManualPanning = false;
				_splineDirty = true;
			}
		};
		standaloneCheckbox.cameras = [camEditor];
		tab.add(standaloneCheckbox);

		lockNoteCheckbox = new FlxUICheckBox(10, 130, null, null, "Lock note movement", 200);
		lockNoteCheckbox.callback = function()
		{
			if (!_suppressUIUpdate)
			{
				isManualPanning = false;
				_splineDirty = true;
			}
		};
		lockNoteCheckbox.cameras = [camEditor];
		tab.add(lockNoteCheckbox);

		// X / Y steppers (label directly above)
		xStepper = new FlxUINumericStepper(10,  170, 10, 0, -9999, 9999, 1);
		yStepper = new FlxUINumericStepper(170, 170, 10, 0, -9999, 9999, 1);
		xStepper.cameras = [camEditor];
		yStepper.cameras = [camEditor];
		tab.add(xStepper);
		tab.add(yStepper);
		xLabel = new FlxText(10,  155, 0, "X (pos / offset):", 10);
		yLabel = new FlxText(170, 155, 0, "Y (pos / offset):", 10);
		xLabel.cameras = [camEditor];
		yLabel.cameras = [camEditor];
		tab.add(xLabel);
		tab.add(yLabel);

		// Duration / Zoom steppers
		durationStepper = new FlxUINumericStepper(10,  215, 0.25, 0,   0,   64, 2);
		zoomStepper     = new FlxUINumericStepper(170, 215, 0.05, 1.0, 0.1,  4, 2);
		durationStepper.cameras = [camEditor];
		zoomStepper.cameras     = [camEditor];
		tab.add(durationStepper);
		tab.add(zoomStepper);
		durationLabel = new FlxText(10,  200, 0, "Duration (beats):", 10);
		zoomLabel = new FlxText(170, 200, 0, "Camera Zoom:", 10);
		durationLabel.cameras = [camEditor];
		zoomLabel.cameras = [camEditor];
		tab.add(durationLabel);
		tab.add(zoomLabel);

		// Ease label (text added before dropdown widget in Z-order is fine for text)
		easeLabel = new FlxText(10, 245, 0, "Ease:", 10);
		easeLabel.cameras = [camEditor];
		tab.add(easeLabel);

		// Action buttons
		var addBtn  = new FlxButton(10,  310, "Add Here",     onAddEvent);
		var editBtn = new FlxButton(115, 310, "Edit Selected", onEditSelected);
		var delBtn  = new FlxButton(220, 310, "Delete Event", onDeleteEvent);
		var saveBtn = new FlxButton(10,  345, "SAVE (Ctrl+S)",saveCameraConfig);
		var exitBtn = new FlxButton(170, 345, "Exit Editor",  exitEditor);
		addBtn.cameras  = [camEditor];
		editBtn.cameras = [camEditor];
		delBtn.cameras  = [camEditor];
		saveBtn.cameras = [camEditor];
		exitBtn.cameras = [camEditor];
		
		addBtn.color = 0xFF8AD490;    // Green
		editBtn.color = 0xFFFFC374;   // Orange/Yellow
		delBtn.color = 0xFFFF8F8F;    // Red
		saveBtn.color = 0xFF8ECAFF;   // Blue
		exitBtn.color = 0xFFCCCCCC;   // Light grey

		addBtn.setGraphicSize(100, 20);
		addBtn.updateHitbox();
		addBtn.label.fieldWidth = 100;
		addBtn.label.alignment = CENTER;
		for (point in addBtn.labelOffsets) point.set(0, 3);

		editBtn.setGraphicSize(100, 20);
		editBtn.updateHitbox();
		editBtn.label.fieldWidth = 100;
		editBtn.label.alignment = CENTER;
		for (point in editBtn.labelOffsets) point.set(0, 3);

		delBtn.setGraphicSize(100, 20);
		delBtn.updateHitbox();
		delBtn.label.fieldWidth = 100;
		delBtn.label.alignment = CENTER;
		for (point in delBtn.labelOffsets) point.set(0, 3);

		saveBtn.setGraphicSize(150, 20);
		saveBtn.updateHitbox();
		saveBtn.label.fieldWidth = 150;
		saveBtn.label.alignment = CENTER;
		for (point in saveBtn.labelOffsets) point.set(0, 3);

		exitBtn.setGraphicSize(150, 20);
		exitBtn.updateHitbox();
		exitBtn.label.fieldWidth = 150;
		exitBtn.label.alignment = CENTER;
		for (point in exitBtn.labelOffsets) point.set(0, 3);

		tab.add(addBtn);
		tab.add(editBtn);
		tab.add(delBtn);
		tab.add(saveBtn);
		tab.add(exitBtn);

		// ── DROPDOWNS LAST so they draw on top of all other widgets ──────
		tab.add(new FlxText(10, 55, 0, "Event Type:", 10));
		var targetLabels = [
			new flixel.addons.ui.StrNameLabel("dad", "Focus Dad"),
			new flixel.addons.ui.StrNameLabel("bf", "Focus BF"),
			new flixel.addons.ui.StrNameLabel("gf", "Focus GF"),
			new flixel.addons.ui.StrNameLabel("extra_char", "Focus Extra Char"),
			new flixel.addons.ui.StrNameLabel("global", "Focus World Pos"),
			new flixel.addons.ui.StrNameLabel("zoom", "Zoom Only"),
			new flixel.addons.ui.StrNameLabel("midpoint", "Midpoint (Dad & BF)"),
			new flixel.addons.ui.StrNameLabel("default", "Revert to Default")
		];
		targetTypeDropdown = new FlxUIDropDownMenuCustom(10, 70,
			targetLabels,
			function(target:String)
			{
				if (!_suppressUIUpdate)
				{
					isManualPanning = false;
					_splineDirty = true;
					updateWidgetVisibility();
				}
			});
		targetTypeDropdown.cameras = [camEditor];

		var easeList = [
			new flixel.addons.ui.StrNameLabel("instant", "Instant Snap"),
			new flixel.addons.ui.StrNameLabel("linear", "Linear"),
			new flixel.addons.ui.StrNameLabel("sineIn", "Sine In"),
			new flixel.addons.ui.StrNameLabel("sineOut", "Sine Out"),
			new flixel.addons.ui.StrNameLabel("sineInOut", "Sine In-Out"),
			new flixel.addons.ui.StrNameLabel("quadIn", "Quad In"),
			new flixel.addons.ui.StrNameLabel("quadOut", "Quad Out"),
			new flixel.addons.ui.StrNameLabel("quadInOut", "Quad In-Out"),
			new flixel.addons.ui.StrNameLabel("cubeIn", "Cube In"),
			new flixel.addons.ui.StrNameLabel("cubeOut", "Cube Out"),
			new flixel.addons.ui.StrNameLabel("cubeInOut", "Cube In-Out"),
			new flixel.addons.ui.StrNameLabel("quartIn", "Quart In"),
			new flixel.addons.ui.StrNameLabel("quartOut", "Quart Out"),
			new flixel.addons.ui.StrNameLabel("quartInOut", "Quart In-Out"),
			new flixel.addons.ui.StrNameLabel("quintIn", "Quint In"),
			new flixel.addons.ui.StrNameLabel("quintOut", "Quint Out"),
			new flixel.addons.ui.StrNameLabel("quintInOut", "Quint In-Out"),
			new flixel.addons.ui.StrNameLabel("expoIn", "Expo In"),
			new flixel.addons.ui.StrNameLabel("expoOut", "Expo Out"),
			new flixel.addons.ui.StrNameLabel("expoInOut", "Expo In-Out"),
			new flixel.addons.ui.StrNameLabel("backIn", "Back In"),
			new flixel.addons.ui.StrNameLabel("backOut", "Back Out"),
			new flixel.addons.ui.StrNameLabel("backInOut", "Back In-Out"),
			new flixel.addons.ui.StrNameLabel("bounceIn", "Bounce In"),
			new flixel.addons.ui.StrNameLabel("bounceOut", "Bounce Out"),
			new flixel.addons.ui.StrNameLabel("bounceInOut", "Bounce In-Out"),
			new flixel.addons.ui.StrNameLabel("circIn", "Circ In"),
			new flixel.addons.ui.StrNameLabel("circOut", "Circ Out"),
			new flixel.addons.ui.StrNameLabel("circInOut", "Circ In-Out"),
			new flixel.addons.ui.StrNameLabel("elasticIn", "Elastic In"),
			new flixel.addons.ui.StrNameLabel("elasticOut", "Elastic Out"),
			new flixel.addons.ui.StrNameLabel("elasticInOut", "Elastic In-Out")
		];
		easeDropdown = new FlxUIDropDownMenuCustom(10, 260,
			easeList,
			function(ease:String)
			{
				if (!_suppressUIUpdate)
				{
					isManualPanning = false;
					_splineDirty = true;
				}
			});
		easeDropdown.cameras = [camEditor];

		// Add dropdowns very last
		tab.add(targetTypeDropdown);
		tab.add(easeDropdown);

		UI_mainbox.addGroup(tab);
		add(UI_mainbox);
	}

	public function getSelectedSubEvent():CameraEvent
	{
		if (selectedStep < 0) return null;
		var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		if (stepEvents.length > 0 && curEventSelected >= 0 && curEventSelected < stepEvents.length)
			return stepEvents[curEventSelected];
		return null;
	}

	function changeSubEventSelected(change:Int):Void
	{
		if (selectedStep < 0) return;
		var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		if (stepEvents.length == 0) return;

		curEventSelected += change;
		if (curEventSelected < 0)
			curEventSelected = stepEvents.length - 1;
		else if (curEventSelected >= stepEvents.length)
			curEventSelected = 0;

		refreshInspector(true); // skip recreating pins since position is unchanged
	}

	function onAddSubEvent():Void
	{
		if (selectedStep < 0) return;

		var newEv:CameraEvent = {
			step: selectedStep,
			target_type: "zoom",
			target_id: 0,
			is_relative: false,
			x: 0.0,
			y: 0.0,
			zoom: -1.0,
			ease: "linear",
			duration: 0.0,
			standalone: false,
			lock_note_movement: false
		};
		cameraEvents.push(newEv);
		cameraEvents.sort(function(a, b) return Reflect.compare(a.step, b.step));

		var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		curEventSelected = stepEvents.indexOf(newEv);

		recreatePins();
		refreshInspector();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function onRemoveSubEvent():Void
	{
		if (selectedStep < 0) return;
		var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		if (stepEvents.length == 0) return;

		var toRemove = stepEvents[curEventSelected];
		cameraEvents.remove(toRemove);

		var remaining = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		if (remaining.length > 0)
		{
			curEventSelected = FlxMath.maxInt(0, curEventSelected - 1);
		}
		else
		{
			selectedStep = -1;
			curEventSelected = 0;
		}

		recreatePins();
		refreshInspector();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function onEditSelected():Void
	{
		if (selectedStep < 0) return;
		var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		if (stepEvents.length > 0 && curEventSelected >= 0 && curEventSelected < stepEvents.length)
		{
			var ev = stepEvents[curEventSelected];
			ev.target_type = targetTypeDropdown.selectedId;
			ev.target_id = Std.int(targetIdStepper.value);
			ev.is_relative = isRelativeCheckbox.checked;
			ev.x = xStepper.value;
			ev.y = yStepper.value;
			ev.zoom = zoomStepper.value;
			ev.ease = easeDropdown.selectedId;
			ev.duration = durationStepper.value;
			ev.standalone = standaloneCheckbox.checked;
			ev.lock_note_movement = lockNoteCheckbox.checked;

			// Sort in case step changed (though editing shouldn't change step, but safe to sort)
			cameraEvents.sort(function(a, b) return Reflect.compare(a.step, b.step));

			recreatePins();
			refreshInspector();
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
	}

	// ─── Button handlers ─────────────────────────────────────────────────────
	function onAddEvent():Void
	{
		var stepFloat:Float = Conductor.songPosition / Conductor.stepCrochet;
		if (!FlxG.keys.pressed.SHIFT)
			stepFloat = Math.fround(stepFloat * 4.0) / 4.0;

		var tt   = (targetTypeDropdown != null) ? targetTypeDropdown.selectedId : "global";
		var tid  = (targetIdStepper != null) ? Std.int(targetIdStepper.value) : 0;
		var rel  = (isRelativeCheckbox != null) ? isRelativeCheckbox.checked : false;
		var ease = (easeDropdown != null) ? easeDropdown.selectedId : "linear";
		var dur  = (durationStepper != null) ? durationStepper.value : 0.0;
		var sa   = (standaloneCheckbox != null) ? standaloneCheckbox.checked : false;
		var ln   = (lockNoteCheckbox != null) ? lockNoteCheckbox.checked : false;
		var ex   = (xStepper != null) ? xStepper.value : 0.0;
		var ey   = (yStepper != null) ? yStepper.value : 0.0;
		var zm   = (zoomStepper != null) ? zoomStepper.value : -1.0;

		var newEv:CameraEvent = {
			step: stepFloat,
			target_type: tt,
			target_id: tid,
			is_relative: rel,
			x: ex,
			y: ey,
			zoom: zm,
			ease: ease,
			duration: dur,
			standalone: sa,
			lock_note_movement: ln
		};

		cameraEvents.push(newEv);
		cameraEvents.sort(function(a, b) return Reflect.compare(a.step, b.step));

		selectedStep = stepFloat;
		var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		curEventSelected = stepEvents.indexOf(newEv);

		recreatePins();
		refreshInspector();
	}

	function onDeleteEvent():Void
	{
		if (selectedStep < 0) return;
		var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		if (stepEvents.length == 0) return;

		var toRemove = stepEvents[curEventSelected];
		cameraEvents.remove(toRemove);

		var remaining = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
		if (remaining.length > 0)
		{
			curEventSelected = FlxMath.maxInt(0, curEventSelected - 1);
		}
		else
		{
			selectedStep = -1;
			curEventSelected = 0;
		}

		recreatePins();
		refreshInspector();
		_splineDirty = true;
	}

	// ─── Inspector refresh ────────────────────────────────────────────────────
	function refreshInspector(?skipPins:Bool = false):Void
	{
		_suppressUIUpdate = true;

		var ev:CameraEvent = getSelectedSubEvent();

		if (ev != null)
		{
			stepLabel.text = "Step: " + FlxMath.roundDecimal(ev.step, 2)
				+ "   (" + FlxMath.roundDecimal(ev.step / 4.0, 2) + " beats)";

			var stepEvents = cameraEvents.filter(function(e) return Math.abs(e.step - selectedStep) < 0.02);
			selectedSubEventText.text = "Sub-Event: " + (curEventSelected + 1) + " / " + stepEvents.length;

			targetTypeDropdown.selectedId    = ev.target_type;
			targetIdStepper.value            = ev.target_id;
			isRelativeCheckbox.checked       = ev.is_relative;
			standaloneCheckbox.checked       = ev.standalone;
			lockNoteCheckbox.checked         = ev.lock_note_movement;
			xStepper.value                   = ev.x;
			yStepper.value                   = ev.y;

			var ease = (ev.ease != null && ev.ease.length > 0)
				? ev.ease : "linear";
			easeDropdown.selectedId          = ease;

			durationStepper.value = ev.duration;
			zoomStepper.value     = ev.zoom;

			infoText.text =
				"SELECTED EVENT\n" +
				"Step:   "   + FlxMath.roundDecimal(ev.step, 2) + "\n" +
				"Target: "   + ev.target_type +
					(ev.target_type == "extra_char" ? " [" + ev.target_id + "]" : "") + "\n" +
				"X: "        + FlxMath.roundDecimal(ev.x, 1) +
				"  Y: "      + FlxMath.roundDecimal(ev.y, 1) + "\n" +
				"Zoom: "     + FlxMath.roundDecimal(ev.zoom, 2) + "\n" +
				"Duration: " + ev.duration + " beats\n" +
				"Relative: " + ev.is_relative + "\n" +
				"Ease: "     + ease;
		}
		else
		{
			stepLabel.text = "Step: - (no event)";
			selectedSubEventText.text = "Sub-Event: None";
			infoText.text =
				"No event selected.\n\n" +
				"Press [C] to capture current\n" +
				"view values to UI controls,\n" +
				"then click [Add Here] or\n" +
				"[Edit Selected] to commit.";
		}

		_suppressUIUpdate = false;
		if (!skipPins)
			recreatePins();
		updateWidgetVisibility();
	}

	public function updateCameraToEvent(ev:CameraEvent):Void
	{
		if (ev == null || !paused) return;
		if (ev.target_type == "zoom")
		{
			if (ev.zoom != -1 && ev.zoom > 0)
				defaultCamZoom = ev.zoom;
		}
		else if (ev.target_type == "default")
		{
			var gpPos = getGameplayCameraPosition();
			camFollow.x = gpPos.x;
			camFollow.y = gpPos.y;
			gpPos.put();
			var stageFile = StageData.getStageFile(PlayState.curStage);
			if (stageFile != null)
				defaultCamZoom = stageFile.defaultZoom;
		}
		else if (ev.target_type == "midpoint")
		{
			var dadMid = dad.getMidpoint();
			var bfMid = boyfriend.getMidpoint();
			camFollow.x = (dadMid.x + bfMid.x) * 0.5 + ev.x;
			camFollow.y = (dadMid.y + bfMid.y) * 0.5 + ev.y;
			dadMid.put();
			bfMid.put();
			if (ev.zoom != -1 && ev.zoom > 0)
				defaultCamZoom = ev.zoom;
		}
		else
		{
			var tp = getCameraTargetPosition(ev.target_type, ev.target_id);
			camFollow.x = ev.is_relative ? (tp.x + ev.x) : ev.x;
			camFollow.y = ev.is_relative ? (tp.y + ev.y) : ev.y;
			if (ev.zoom != -1 && ev.zoom > 0)
				defaultCamZoom = ev.zoom;
		}
		_splineDirty = true;
	}

	public function getEventWorldPosition(ev:CameraEvent, index:Int):FlxPoint
	{
		if (ev == null) return new FlxPoint(0, 0);
		if (ev.target_type == "zoom")
		{
			if (index > 0)
			{
				return getEventWorldPosition(cameraEvents[index - 1], index - 1);
			}
			return getDefaultCameraPosition();
		}
		else if (ev.target_type == "default")
		{
			return getGameplayCameraPosition();
		}
		else if (ev.target_type == "midpoint")
		{
			var dadMid = dad.getMidpoint();
			var bfMid = boyfriend.getMidpoint();
			var mx = (dadMid.x + bfMid.x) * 0.5 + ev.x;
			var my = (dadMid.y + bfMid.y) * 0.5 + ev.y;
			dadMid.put();
			bfMid.put();
			return new FlxPoint(mx, my);
		}
		else
		{
			var tp = getCameraTargetPosition(ev.target_type, ev.target_id);
			var wx = ev.is_relative ? (tp.x + ev.x) : ev.x;
			var wy = ev.is_relative ? (tp.y + ev.y) : ev.y;
			return new FlxPoint(wx, wy);
		}
	}

	function updateWidgetVisibility():Void
	{
		var hasSelection = (selectedStep >= 0);
		
		selectedSubEventText.visible = hasSelection;
		prevSubEventBtn.visible = hasSelection;
		nextSubEventBtn.visible = hasSelection;
		addSubEventBtn.visible = hasSelection;
		removeSubEventBtn.visible = hasSelection;

		var type = (targetTypeDropdown != null) ? targetTypeDropdown.selectedId : "global";

		var showId = (type == "extra_char");
		var showRelative = (type != "global" && type != "zoom" && type != "default" && type != "midpoint");
		var showStandalone = (type != "zoom" && type != "default" && type != "midpoint");
		var showLockNote = (type != "zoom" && type != "default");
		var showCoords = (type != "zoom" && type != "default");
		var showZoom = (type != "default");
		var showDuration = true;
		var showEase = true;

		targetIdStepper.visible = showId;
		targetIdLabel.visible = showId;

		isRelativeCheckbox.visible = showRelative;
		standaloneCheckbox.visible = showStandalone;
		lockNoteCheckbox.visible = showLockNote;

		xStepper.visible = showCoords;
		xLabel.visible = showCoords;
		yStepper.visible = showCoords;
		yLabel.visible = showCoords;

		zoomStepper.visible = showZoom;
		zoomLabel.visible = showZoom;

		durationStepper.visible = showDuration;
		durationLabel.visible = showDuration;

		easeDropdown.visible = showEase;
		easeLabel.visible = showEase;
	}

	// ─── getEvent (numeric stepper changes) ──────────────────────────────────
	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (_suppressUIUpdate) return;
		if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			isManualPanning = false;
			_splineDirty = true;
		}
	}

	// ─── Pin recreation ───────────────────────────────────────────────────────
	public function recreatePins():Void
	{
		pinsGroup.clear();
		if (FlxG.sound.music == null || FlxG.sound.music.length <= 0) return;

		var uniqueSteps:Array<Float> = [];
		var stepToEventMap:Map<String, CameraEvent> = new Map<String, CameraEvent>();

		for (ev in cameraEvents)
		{
			var found = false;
			for (s in uniqueSteps)
			{
				if (Math.abs(s - ev.step) < 0.02)
				{
					found = true;
					break;
				}
			}
			if (!found)
			{
				uniqueSteps.push(ev.step);
				stepToEventMap.set(Std.string(ev.step), ev);
			}
		}

		updateTimelineBounds();
		var visibleRange:Float = timelineEndStep - timelineStartStep;

		for (stepVal in uniqueSteps)
		{
			if (stepVal < timelineStartStep || stepVal > timelineEndStep) continue;

			var ev = stepToEventMap.get(Std.string(stepVal));
			var pct:Float    = (stepVal - timelineStartStep) / visibleRange;
			var px:Float     = TL_X + pct * TL_W;

			var pin:CameraPin = new CameraPin(ev);
			var isSelected    = (Math.abs(stepVal - selectedStep) < 0.02);
			
			var pinColor:FlxColor = 0xFF757575; // Slate grey for global/default
			switch (ev.target_type)
			{
				case "dad":        pinColor = 0xFFFF00FF; // Magenta
				case "bf":         pinColor = 0xFF00FFFF; // Cyan
				case "gf":         pinColor = 0xFFFF0077; // Pink
				case "extra_char": pinColor = 0xFF00FF00; // Lime Green
			}

			if (isSelected)
			{
				pin.makeGraphic(14, Std.int(TL_H) + 16, FlxColor.WHITE);
				FlxSpriteUtil.drawRect(pin, 2, 2, 10, Std.int(TL_H) + 12, pinColor);
				pin.x = px - 7;
				pin.y = TL_Y - 8;
			}
			else
			{
				pin.makeGraphic(6, Std.int(TL_H) + 6, pinColor);
				pin.x = px - 3;
				pin.y = TL_Y - 3;
			}
			pin.scrollFactor.set(0, 0);
			pin.cameras = [camEditor];
			pinsGroup.add(pin);
		}
		_splineDirty = true;
	}

	// ─── Seek ─────────────────────────────────────────────────────────────────
	var lastSeekTime:Float = 0;
	public function seekTo(newTime:Float):Void
	{
		if (FlxG.sound.music == null) return;
		newTime = FlxMath.bound(newTime, 0, FlxG.sound.music.length);

		// Fix missing chart on backwards seek by reloading notes
		if (newTime < lastSeekTime - 100)
		{
			KillNotes();
			if (PlayState.SONG != null && PlayState.SONG.notes != null)
			{
				for (section in PlayState.SONG.notes)
				{
					for (songNotes in section.sectionNotes)
					{
						var daStrumTime:Float = songNotes[0];
						var daNoteData:Int = Std.int(songNotes[1] % 4);
						var noteCharID:Int = Std.int(songNotes[1] / 4);
						
						var gottaHitNote:Bool = (noteCharID == 1) ? true : (noteCharID < extraChars.length ? extraChars[noteCharID].isPlayer : false);
						
						var oldNote:Note = (unspawnNotes.length > 0) ? unspawnNotes[unspawnNotes.length - 1] : null;
						var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
						swagNote.charNoteID = noteCharID;
						swagNote.mustPress = gottaHitNote;
						swagNote.sustainLength = songNotes[2];
						swagNote.gfNote = (section.gfSection && (songNotes[1] < 4));
						swagNote.noteType = songNotes[3];
						if (!Std.isOfType(songNotes[3], String))
							swagNote.noteType = editors.ChartingState.noteTypeList[songNotes[3]];
						swagNote.scrollFactor.set();
						var susLength:Float = swagNote.sustainLength / Conductor.stepCrochet;
						unspawnNotes.push(swagNote);
						
						var floorSus:Int = Math.floor(susLength);
						if (floorSus > 0)
						{
							for (susNote in 0...floorSus + 1)
							{
								oldNote = unspawnNotes[unspawnNotes.length - 1];
								var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(songSpeed, 2)), daNoteData, oldNote, true);
								sustainNote.charNoteID = noteCharID;
								sustainNote.mustPress = gottaHitNote;
								sustainNote.gfNote = (section.gfSection && (songNotes[1] < 4));
								sustainNote.noteType = swagNote.noteType;
								sustainNote.scrollFactor.set();
								swagNote.tail.push(sustainNote);
								sustainNote.parent = swagNote;
								unspawnNotes.push(sustainNote);
								
								if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2;
								else if (ClientPrefs.middleScroll) {
									sustainNote.x += 310;
									if (daNoteData > 1) sustainNote.x += FlxG.width / 2 + 25;
								}
							}
						}
						
						if (swagNote.mustPress) swagNote.x += FlxG.width / 2;
						else if (ClientPrefs.middleScroll) {
							swagNote.x += 310;
							if (daNoteData > 1) swagNote.x += FlxG.width / 2 + 25;
						}
					}
				}
				unspawnNotes.sort(function(a, b) return Reflect.compare(a.strumTime, b.strumTime));
			}
		}

		Conductor.songPosition = newTime;
		songTime               = newTime;
		lastSeekTime           = newTime;

		FlxG.sound.music.time = newTime;
		if (vocals != null) vocals.time = newTime;

		if (paused)
		{
			FlxG.sound.music.pause();
			if (vocals != null) vocals.pause();
		}
		else
		{
			FlxG.sound.music.play();
			if (vocals != null) vocals.play();
		}

		startingSong = false;
		_splineDirty = true;
	}

	override function closeSubState()
	{
		var wasPaused = paused;
		// Trick PlayState into skipping its unpause logic
		paused = false; 
		super.closeSubState();
		// Restore our editor's paused state
		paused = wasPaused;
	}

	// ─── Update ──────────────────────────────────────────────────────────────
	override function update(elapsed:Float)
	{
		if (!paused)
		{
			if (FlxG.sound.music != null && FlxG.sound.music.playing)
			{
				Conductor.songPosition = FlxG.sound.music.time;
				songTime = Conductor.songPosition;
				
				// Sync vocals
				if (vocals != null && vocals.playing)
				{
					if (Math.abs(vocals.time - Conductor.songPosition) > 20)
					{
						vocals.time = Conductor.songPosition;
					}
				}
			}
		}

		var oldPos:Float = Conductor.songPosition;
		
		// Suppress PlayState camera tracking by spoofing isCameraOnForcedPos when paused
		var wasForcedPos:Bool = isCameraOnForcedPos;
		if (paused)
		{
			isCameraOnForcedPos = true;
		}

		// 1. FIX THE TICK RATE & UPDATE LOOP CYCLES: Call super.update at the very beginning of update
		super.update(elapsed);

		if (paused)
		{
			Conductor.songPosition = oldPos;
			songTime = oldPos;
			isCameraOnForcedPos = wasForcedPos;
		}

		updateTimelineBounds();
		if (timelineStartStep != lastStartStep || timelineEndStep != lastEndStep)
		{
			drawTimelineTicks();
			recreatePins();
			lastStartStep = timelineStartStep;
			lastEndStep = timelineEndStep;
		}

		if (FlxG.keys.justPressed.H) {
			helpPanel.visible = !helpPanel.visible;
		}

		if (helpPanel.visible) {
			if (FlxG.mouse.justPressed || FlxG.keys.justPressed.ESCAPE) {
				helpPanel.visible = false;
			}
			// Block interaction when help is visible, but do not double-call super.update
			return;
		}

		// ── Block hotkeys when a text input has focus ─────────────────────
		// (FlxUINumericStepper text fields can steal focus)
		var blockInput:Bool = FlxG.keys.pressed.CONTROL; // allow CTRL combos through

		// ── Ctrl + S = Save ───────────────────────────────────────────────
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
			saveCameraConfig();

		// ── SPACE = Play / Pause ──────────────────────────────────────────
		if (FlxG.keys.justPressed.SPACE && !blockInput || (FlxG.keys.justPressed.SPACE && !FlxG.keys.pressed.CONTROL))
		{
			if (paused)
			{
				isManualPanning = false;
				paused = false;
				if (FlxG.sound.music != null)
				{
					FlxG.sound.music.time = Conductor.songPosition;
					FlxG.sound.music.play();
				}
				if (vocals != null)
				{
					vocals.time = Conductor.songPosition;
					vocals.play();
				}
				previousFrameTime = FlxG.game.ticks;
			}
			else
			{
				paused = true;
				if (FlxG.sound.music != null) FlxG.sound.music.pause();
				if (vocals != null) vocals.pause();
			}
		}

		// ── Timeline clicks / scrubbing / dragging ─────────────────────────
		var noFocus:Bool = !FlxG.keys.pressed.CONTROL;
		if (noFocus)
		{
			var mousePos = FlxG.mouse.getScreenPosition(camEditor);
			var mx = mousePos.x;
			var my = mousePos.y;
			var smx = mousePos.x;
			var smy = mousePos.y;
			var dX = smx - lastMouseX;
			var dY = smy - lastMouseY;
			lastMouseX = Std.int(smx);
			lastMouseY = Std.int(smy);
			mousePos.put();

			var inTimelineY = (my >= TL_Y - 4 && my <= TL_Y + TL_H + 4);
			var inTimelineX = (mx >= TL_X && mx <= TL_X + TL_W);

			// ── Mouse Scroll to Zoom Editor or Timeline ──────────────────────────
			if (FlxG.mouse.wheel != 0) {
				if (inTimelineY && inTimelineX)
				{
					timelineZoom += FlxG.mouse.wheel * 0.5;
					if (timelineZoom < 1.0) timelineZoom = 1.0;
					if (timelineZoom > 50.0) timelineZoom = 50.0;
					updateTimelineBounds();
					drawTimelineTicks();
					recreatePins();
				}
				else
				{
					isManualPanning = true;
					defaultCamZoom += FlxG.mouse.wheel * 0.1;
					if (defaultCamZoom < 0.1) defaultCamZoom = 0.1;
					_splineDirty = true;
					
					if (selectedStep >= 0)
					{
						_suppressUIUpdate = true;
						zoomStepper.value = defaultCamZoom;
						_suppressUIUpdate = false;
					}
				}
			}

			// ── Mouse Drag Panning ──────────────────────────────────────────────
			if (FlxG.mouse.pressedRight || FlxG.mouse.pressedMiddle)
			{
				isManualPanning = true;
				var camSpeed = (defaultCamZoom > 0 ? 1/defaultCamZoom : 1);
				var shiftX = -dX * camSpeed;
				var shiftY = -dY * camSpeed;

				camFollow.x += shiftX;
				camFollow.y += shiftY;
				_splineDirty = true;
				
				if (selectedStep >= 0)
				{
					_suppressUIUpdate = true;
					var isRel = isRelativeCheckbox.checked;
					var targetType = targetTypeDropdown.selectedId;
					var targetId = Std.int(targetIdStepper.value);
					if (isRel)
					{
						var tp = getCameraTargetPosition(targetType, targetId);
						xStepper.value = camFollow.x - tp.x;
						yStepper.value = camFollow.y - tp.y;
					}
					else
					{
						xStepper.value = camFollow.x;
						yStepper.value = camFollow.y;
					}
					_suppressUIUpdate = false;
				}
			}



			if (FlxG.mouse.justPressed)
			{
				if (inTimelineY && inTimelineX)
				{
					var hitPin:CameraPin = null;
					for (pin in pinsGroup.members)
					{
						if (mx >= pin.x && mx <= pin.x + pin.width) { hitPin = pin; break; }
					}

					if (hitPin != null)
					{
						isManualPanning = false;
						draggingPin = hitPin;
						selectedStep = hitPin.event.step;
						curEventSelected = 0;
						seekTo(selectedStep * Conductor.stepCrochet);
						refreshInspector();
					}
					else
					{
						isManualPanning = false;
						_isScrubbing = true;
						var pct = FlxMath.bound((mx - TL_X) / TL_W, 0, 1);
						if (FlxG.sound.music != null)
						{
							updateTimelineBounds();
							var targetStep = timelineStartStep + pct * (timelineEndStep - timelineStartStep);
							var newTime = targetStep * Conductor.stepCrochet;
							if (!FlxG.keys.pressed.SHIFT) {
								var newStep = newTime / Conductor.stepCrochet;
								newStep = Math.fround(newStep * 4.0) / 4.0;
								newTime = newStep * Conductor.stepCrochet;
							}
							seekTo(newTime);
						}
					}
				}
			}
			else if (FlxG.mouse.pressed)
			{
				if (draggingPin != null)
				{
					var pct = FlxMath.bound((mx - TL_X) / TL_W, 0, 1);
					updateTimelineBounds();
					var newStep = timelineStartStep + pct * (timelineEndStep - timelineStartStep);
					
					// Optional grid snapping (snap to 0.25 steps unless SHIFT is held)
					if (!FlxG.keys.pressed.SHIFT)
						newStep = Math.fround(newStep * 4.0) / 4.0;
					
					var origStep = draggingPin.event.step;
					for (ev in cameraEvents)
					{
						if (Math.abs(ev.step - origStep) < 0.02)
						{
							ev.step = newStep;
						}
					}
					
					selectedStep = newStep;
					
					// Re-calculate X based on the snapped step
					updateTimelineBounds();
					var snappedPct = FlxMath.bound((newStep - timelineStartStep) / (timelineEndStep - timelineStartStep), 0, 1);
					draggingPin.x = TL_X + snappedPct * TL_W;
					
					var snappedTime = newStep * Conductor.stepCrochet;
					seekTo(snappedTime);
					refreshInspector(true); // Skip pins recreation during drag
				}
				else if (_isScrubbing)
				{
					var pct = FlxMath.bound((mx - TL_X) / TL_W, 0, 1);
					if (FlxG.sound.music != null)
					{
						updateTimelineBounds();
						var targetStep = timelineStartStep + pct * (timelineEndStep - timelineStartStep);
						var newTime = targetStep * Conductor.stepCrochet;
						if (!FlxG.keys.pressed.SHIFT) {
							var newStep = newTime / Conductor.stepCrochet;
							newStep = Math.fround(newStep * 4.0) / 4.0;
							newTime = newStep * Conductor.stepCrochet;
						}
						seekTo(newTime);
					}
				}
			}
			else if (FlxG.mouse.justReleased)
			{
				_isScrubbing = false;
				if (draggingPin != null)
				{
					// Sort events and rebuild pins
					cameraEvents.sort(function(a, b) return (a.step < b.step) ? -1 : 1);
					recreatePins();
					_splineDirty = true;
					draggingPin = null;
				}
			}
		}

		// ── Seek keys — only fire if UI stepper NOT focused ───────────────
		if (noFocus)
		{
			if (FlxG.keys.justPressed.LEFT)
			{
				isManualPanning = false;
				seekTo(FlxG.keys.pressed.SHIFT
					? Conductor.songPosition - 4 * Conductor.crochet
					: Conductor.songPosition - 10000);
			}
			if (FlxG.keys.justPressed.RIGHT)
			{
				isManualPanning = false;
				seekTo(FlxG.keys.pressed.SHIFT
					? Conductor.songPosition + 4 * Conductor.crochet
					: Conductor.songPosition + 10000);
			}
		}

		if (FlxG.keys.justPressed.R)   { isManualPanning = false; seekTo(0); }
		if (FlxG.keys.justPressed.END && FlxG.sound.music != null)
			{ isManualPanning = false; seekTo(FlxG.sound.music.length); }

		// ── TAB = Toggle UI visibility ────────────────────────────────────
		if (FlxG.keys.justPressed.TAB)
		{
			isUIVisible         = !isUIVisible;
			UI_mainbox.visible  = isUIVisible;
			timelineBG.visible  = isUIVisible;
			timelineTrack.visible= isUIVisible;
			timelineProgress.visible= isUIVisible;
			pinsGroup.visible   = isUIVisible;
			splineCanvas.visible= isUIVisible;
			infoText.visible    = isUIVisible;
			playbackText.visible= isUIVisible;

			topBar.visible          = isUIVisible;
			bottomBar.visible       = isUIVisible;
			guideFrame.visible      = isUIVisible;
			infoBG.visible          = isUIVisible;
			playbackBG.visible      = isUIVisible;
			recStatusText.visible   = isUIVisible;
			hudTimecodeText.visible = isUIVisible;
		}

		// ── Camera pan / zoom (IJKL + UO, only when paused) ─────────────
		if (paused)
		{
			var spd  = 500 * elapsed * (FlxG.keys.pressed.SHIFT ? 3.0 : 1.0);
			var zspd = 0.5  * elapsed * (FlxG.keys.pressed.SHIFT ? 3.0 : 1.0);
			var panned = false;

			if (FlxG.keys.pressed.I) { camFollow.y -= spd; panned = true; }
			if (FlxG.keys.pressed.K) { camFollow.y += spd; panned = true; }
			if (FlxG.keys.pressed.J) { camFollow.x -= spd; panned = true; }
			if (FlxG.keys.pressed.L) { camFollow.x += spd; panned = true; }
			if (FlxG.keys.pressed.U) { defaultCamZoom = Math.max(0.1, defaultCamZoom - zspd); panned = true; }
			if (FlxG.keys.pressed.O) { defaultCamZoom += zspd;                                  panned = true; }

			if (panned)
			{
				isManualPanning = true;
				_splineDirty    = true;
				
				if (selectedStep >= 0)
				{
					_suppressUIUpdate = true;
					var isRel = isRelativeCheckbox.checked;
					var targetType = targetTypeDropdown.selectedId;
					var targetId = Std.int(targetIdStepper.value);
					if (isRel)
					{
						var tp = getCameraTargetPosition(targetType, targetId);
						xStepper.value = camFollow.x - tp.x;
						yStepper.value = camFollow.y - tp.y;
					}
					else
					{
						xStepper.value = camFollow.x;
						yStepper.value = camFollow.y;
					}
					zoomStepper.value = defaultCamZoom;
					_suppressUIUpdate = false;
				}
			}
		}

		// ── C = Capture current viewport as a new/updated event ───────────
		if (FlxG.keys.justPressed.C)
			captureCurrentView();

		// ── Ctrl+Click (or M) = Place camera target ──────────────────────────
		if (FlxG.mouse.justPressed && (FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.M) && selectedStep >= 0)
		{
			var mousePos = FlxG.mouse.getScreenPosition(camEditor);
			var mx = mousePos.x;
			var my = mousePos.y;
			mousePos.put();
			
			if (mx < 930 && my > 55 && my < 585)
			{
				var clickWorld:FlxPoint = FlxG.mouse.getWorldPosition(camGame);
				_suppressUIUpdate = true;
				var isRel = isRelativeCheckbox.checked;
				var targetType = targetTypeDropdown.selectedId;
				var targetId = Std.int(targetIdStepper.value);
				if (isRel)
				{
					var tp = getCameraTargetPosition(targetType, targetId);
					xStepper.value = clickWorld.x - tp.x;
					yStepper.value = clickWorld.y - tp.y;
				}
				else
				{
					xStepper.value = clickWorld.x;
					yStepper.value = clickWorld.y;
				}
				_suppressUIUpdate = false;
				
				camFollow.x  = clickWorld.x;
				camFollow.y  = clickWorld.y;
				isManualPanning = false; // lock to this position
				_splineDirty = true;
			}
		}

		// ── Playhead indicator update ──────────────────────────────────────
		if (FlxG.sound.music != null && FlxG.sound.music.length > 0)
		{
			var currentStep = Conductor.songPosition / Conductor.stepCrochet;
			var pct = FlxMath.bound((currentStep - timelineStartStep) / (timelineEndStep - timelineStartStep), 0, 1);
			timelineProgress.x = TL_X + pct * TL_W - 1;
		}

		// ── Playback text ─────────────────────────────────────────────────
		var stepF = Conductor.songPosition / Conductor.stepCrochet;
		playbackText.text =
			"Time:  " + FlxMath.roundDecimal(Conductor.songPosition / 1000.0, 2) + "s\n" +
			"Step:  " + FlxMath.roundDecimal(stepF, 2) + "\n" +
			"Beat:  " + FlxMath.roundDecimal(stepF / 4.0, 2) + "\n" +
			"State: " + (paused ? "PAUSED" : "PLAYING") + "\n" +
			"Events:" + cameraEvents.length + "\n" +
			"Zoom:  " + FlxMath.roundDecimal(timelineZoom, 1) + "x";

		// ── Viewfinder HUD Updates ─────────────────────────────────────────
		_recBlinkTimer += elapsed;
		if (_recBlinkTimer >= 1.0) _recBlinkTimer -= 1.0;
		var showDot:Bool = (_recBlinkTimer < 0.5);

		if (paused)
		{
			recStatusText.text = "STBY";
			recStatusText.color = 0xFFFFB300; // Amber
		}
		else
		{
			recStatusText.text = showDot ? "● REC" : "  REC";
			recStatusText.color = 0xFFE53935; // Red
		}

		var tcMinutes:Int = Math.floor(Conductor.songPosition / 60000);
		var tcSeconds:Int = Math.floor((Conductor.songPosition % 60000) / 1000);
		var tcMS:Int = Math.floor((Conductor.songPosition % 1000) / 10);
		hudTimecodeText.text = (tcMinutes < 10 ? "0" : "") + tcMinutes + ":" + 
		                       (tcSeconds < 10 ? "0" : "") + tcSeconds + ":" + 
		                       (tcMS < 10 ? "0" : "") + tcMS;

		if (paused && !isManualPanning)
		{
			updateCameraEvents(elapsed);
		}

		// Set game camera properties
		camGame.scroll.x = camFollow.x - camGame.width * 0.5;
		camGame.scroll.y = camFollow.y - camGame.height * 0.5;
		camGame.zoom = defaultCamZoom;
		
		// Event-driven spline rendering: check if viewport actually changed or if manually marked dirty
		if (camGame.scroll.x != lastCamX || camGame.scroll.y != lastCamY || camGame.zoom != lastCamZoom)
		{
			_splineDirty = true;
			lastCamX = camGame.scroll.x;
			lastCamY = camGame.scroll.y;
			lastCamZoom = camGame.zoom;
		}

		if (_splineDirty) {
			drawVisualSplines();
			_splineDirty = false;
		}
	}

	// ─── Capture current viewport as event ────────────────────────────────────
	function captureCurrentView():Void
	{
		_suppressUIUpdate = true;
		var cx:Float = camGame.scroll.x + camGame.width * 0.5;
		var cy:Float = camGame.scroll.y + camGame.height * 0.5;

		var tt   = (targetTypeDropdown != null) ? targetTypeDropdown.selectedId : "global";
		var tid  = (targetIdStepper != null) ? Std.int(targetIdStepper.value) : 0;
		var rel  = (isRelativeCheckbox != null) ? isRelativeCheckbox.checked : false;

		if (rel)
		{
			var tp = getCameraTargetPosition(tt, tid);
			xStepper.value = cx - tp.x;
			yStepper.value = cy - tp.y;
		}
		else
		{
			xStepper.value = cx;
			yStepper.value = cy;
		}
		zoomStepper.value = camGame.zoom;
		_suppressUIUpdate = false;
		
		isManualPanning = false; // lock preview to these captured parameters
		_splineDirty = true;
		
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	// ─── Add / Update event in sorted list ────────────────────────────────────
	public function addOrUpdateEvent(
		step:Float, targetType:String, targetId:Int, isRelative:Bool,
		xVal:Float, yVal:Float, zoomVal:Float, easeVal:String,
		durationVal:Float, standaloneVal:Bool, lockNoteVal:Bool):CameraEvent
	{
		var event:CameraEvent = null;
		for (e in cameraEvents)
			if (Math.abs(e.step - step) < 0.02) { event = e; break; }

		if (event == null)
		{
			event = {
				step:               step,
				target_type:        targetType,
				target_id:          targetId,
				is_relative:        isRelative,
				x:                  xVal,
				y:                  yVal,
				zoom:               zoomVal,
				ease:               easeVal,
				duration:           durationVal,
				standalone:         standaloneVal,
				lock_note_movement: lockNoteVal
			};
			cameraEvents.push(event);
		}
		else
		{
			event.target_type        = targetType;
			event.target_id          = targetId;
			event.is_relative        = isRelative;
			event.x                  = xVal;
			event.y                  = yVal;
			event.zoom               = zoomVal;
			event.ease               = easeVal;
			event.duration           = durationVal;
			event.standalone         = standaloneVal;
			event.lock_note_movement = lockNoteVal;
		}

		cameraEvents.sort(function(a, b) return Reflect.compare(a.step, b.step));
		recreatePins();
		_splineDirty = true;
		return event;
	}

	// ─── World → screen coordinate conversion ────────────────────────────────
	public function worldToScreen(worldX:Float, worldY:Float):FlxPoint
	{
		var sx = (worldX - camGame.scroll.x) * camGame.zoom;
		var sy = (worldY - camGame.scroll.y) * camGame.zoom;
		return new FlxPoint(sx, sy);
	}

	// ─── Update visible timeline bounds ──────────────────────────────────────
	public function updateTimelineBounds():Void
	{
		if (FlxG.sound.music == null || FlxG.sound.music.length <= 0)
		{
			timelineStartStep = 0;
			timelineEndStep = 100;
			return;
		}

		// Freeze bounds during drag or scrub to prevent jitter/shifting
		if ((_isScrubbing || draggingPin != null) && timelineEndStep > timelineStartStep)
		{
			return;
		}

		var totalSteps:Float = FlxG.sound.music.length / Conductor.stepCrochet;
		var visibleStepsWindow:Float = totalSteps / timelineZoom;

		if (timelineZoom <= 1.01)
		{
			timelineStartStep = 0;
			timelineEndStep = totalSteps;
		}
		else
		{
			var currentStep:Float = Conductor.songPosition / Conductor.stepCrochet;
			timelineStartStep = currentStep - visibleStepsWindow * 0.5;
			if (timelineStartStep < 0)
			{
				timelineStartStep = 0;
			}
			timelineEndStep = timelineStartStep + visibleStepsWindow;
			if (timelineEndStep > totalSteps)
			{
				timelineEndStep = totalSteps;
				timelineStartStep = Math.max(0, timelineEndStep - visibleStepsWindow);
			}
		}
	}

	// ─── Draw timeline beat grid ticks ────────────────────────────────────────
	public function drawTimelineTicks():Void
	{
		if (FlxG.sound.music == null || FlxG.sound.music.length <= 0) return;

		timelineBG.pixels.fillRect(timelineBG.pixels.rect, 0xFF141416);

		var stepCrochet:Float = Conductor.stepCrochet;
		var totalSteps:Float = FlxG.sound.music.length / stepCrochet;
		var stepsPerBeat:Int = 4;
		var totalBeats:Int = Math.floor(totalSteps / stepsPerBeat);

		updateTimelineBounds();
		var visibleRange:Float = timelineEndStep - timelineStartStep;

		for (b in 0...totalBeats + 1)
		{
			var tickStep:Float = b * stepsPerBeat;
			if (tickStep < timelineStartStep - stepsPerBeat) continue;
			if (tickStep > timelineEndStep + stepsPerBeat) break;

			var pct:Float = (tickStep - timelineStartStep) / visibleRange;
			if (pct < 0 || pct > 1) continue;

			var tx:Float = pct * TL_W;
			var isMeasure:Bool = (b % 4 == 0);
			var tickH:Float = isMeasure ? TL_H : TL_H * 0.5;
			var tickColor:FlxColor = isMeasure ? 0xFF55555A : 0xFF2D2D32;
			var thickness:Float = isMeasure ? 1.5 : 1.0;

			FlxSpriteUtil.drawLine(timelineBG, tx, TL_H - tickH, tx, TL_H, {color: tickColor, thickness: thickness});
		}

		// Draw individual step ticks if zoomed in closely
		if (visibleRange < 64)
		{
			for (s in Math.floor(timelineStartStep)...Math.ceil(timelineEndStep) + 1)
			{
				if (s % 4 == 0) continue; // Beat ticks already drawn
				var pct:Float = (s - timelineStartStep) / visibleRange;
				if (pct >= 0 && pct <= 1)
				{
					var tx:Float = pct * TL_W;
					FlxSpriteUtil.drawLine(timelineBG, tx, TL_H - (TL_H * 0.25), tx, TL_H, {color: 0xFF1F1F24, thickness: 1.0});
				}
			}
		}
	}

	// ─── Draw interpolation splines on the spline canvas ─────────────────────
	public function drawVisualSplines():Void
	{
		_splineDirty = false;

		// Clear canvas
		splineCanvas.pixels.fillRect(splineCanvas.pixels.rect, 0);

		if (!isUIVisible || cameraEvents.length == 0) return;

		// Draw a dot for every event (using target-specific colors)
		for (i in 0...cameraEvents.length)
		{
			var ev = cameraEvents[i];
			var wp = getEventWorldPosition(ev, i);
			var sp = worldToScreen(wp.x, wp.y);
			wp.put();

			var dotColor:FlxColor = 0xFF757575;
			switch (ev.target_type)
			{
				case "dad":        dotColor = 0xFFFF00FF;
				case "bf":         dotColor = 0xFF00FFFF;
				case "gf":         dotColor = 0xFFFF0077;
				case "extra_char": dotColor = 0xFF00FF00;
				case "zoom":       dotColor = 0xFFFFA500;
				case "midpoint":   dotColor = 0xFFFFFF00;
				case "default":    dotColor = 0xFF808080;
			}

			if (ev == selectedEvent)
			{
				FlxSpriteUtil.drawCircle(splineCanvas, sp.x, sp.y, 9, FlxColor.WHITE);
				FlxSpriteUtil.drawCircle(splineCanvas, sp.x, sp.y, 7, dotColor);
			}
			else
			{
				FlxSpriteUtil.drawCircle(splineCanvas, sp.x, sp.y, 5, dotColor);
			}
		}

		// Draw focus ring and target reticle for selected event
		if (selectedEvent != null)
		{
			var selIndex = cameraEvents.indexOf(selectedEvent);
			var wp = getEventWorldPosition(selectedEvent, selIndex);
			var sp = worldToScreen(wp.x, wp.y);
			wp.put();

			// Draw focus ring around the target
			FlxSpriteUtil.drawCircle(splineCanvas, sp.x, sp.y, 18, FlxColor.TRANSPARENT, {color: 0xFF00FFFF, thickness: 1.5});
			// Draw crosshair notches
			FlxSpriteUtil.drawLine(splineCanvas, sp.x - 25, sp.y, sp.x - 10, sp.y, {color: 0xFF00FFFF, thickness: 1.5});
			FlxSpriteUtil.drawLine(splineCanvas, sp.x + 10, sp.y, sp.x + 25, sp.y, {color: 0xFF00FFFF, thickness: 1.5});
			FlxSpriteUtil.drawLine(splineCanvas, sp.x, sp.y - 25, sp.x, sp.y - 10, {color: 0xFF00FFFF, thickness: 1.5});
			FlxSpriteUtil.drawLine(splineCanvas, sp.x, sp.y + 10, sp.x, sp.y + 25, {color: 0xFF00FFFF, thickness: 1.5});
		}
	}

	// ─── Save camera.json ─────────────────────────────────────────────────────
	public function saveCameraConfig():Void
	{
		var content  = haxe.Json.stringify({camera_events: cameraEvents}, "\t");
		var savePath = PlayState.getCameraSavePath(PlayState.SONG.song);

		#if sys
		try
		{
			var parts   = savePath.split('/');
			parts.pop();
			var dirPath = parts.join('/');
			if (!sys.FileSystem.exists(dirPath))
				sys.FileSystem.createDirectory(dirPath);
			sys.io.File.saveContent(savePath, content);
			trace("Camera config saved: " + savePath);

			// Flash confirmation
			var flash = new FlxText(TL_X, TL_Y - 70, TL_W, "CONFIG SAVED!", 18);
			flash.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.GREEN, CENTER,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			flash.scrollFactor.set(0, 0);
			flash.cameras = [camEditor];
			add(flash);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			flixel.tweens.FlxTween.tween(flash, {alpha: 0}, 2.0,
				{onComplete: function(_) flash.destroy()});
		}
		catch (e:Dynamic)
		{
			trace("Error saving camera config: " + e);
		}
		#end
	}

	// ─── Exit editor ──────────────────────────────────────────────────────────
	public function exitEditor():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;
		#if PRELOAD_ALL
		FreeplayState.destroyFreeplayVocals();
		#end
		FlxG.mouse.visible = false;
		MusicBeatState.switchState(new editors.MasterEditorMenu());
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
}
