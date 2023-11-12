extends Node

class_name dynamicQuality

## the fps we want to have. the code will try to always stay over this frame rate
@export var targetFps:int = 60
## current / starting resolution
@export var resolutionScale := .5
## do not go below this resolution
@export var minScale := .4
## do not go over this resolution
@export var maxScale := 1.
## in what increments we increase&decrease
@export var stepSize := .1
## a label where we will show the current framerate and resolutionScale
@export var textLabel:Label


var measureFrames := 20;	# how many frames to measure before making a decision
var measured := 0 			# how many frames we have measured
var accumulate := 0.		# accumulate measured frame time
var skipFrames := 5 		# frames to skip, is set after making an adjustment
var skipAfterAdjustment := 5# how many frames we wait after adjusting
var viewport_rid :RID;

func _ready():
	# Enable measurements on our viewport
	viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	# set our intial scale
	get_viewport().scaling_3d_scale = resolutionScale

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	# skip measuring frames shortly after an adjustment,
	# because a frame drop is expected when changing resolution
	if skipFrames > 0:
		skipFrames -= 1
		return
	
	#measure new frames
	if measured < measureFrames:
		measured += 1
		
		# Get measurements of cpu and gpu time
		var frametime_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()
		var frametime_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		var frametime = (frametime_cpu+frametime_gpu)/1000.
		#frametime = delta # this is an alternative, that will not work when vsync is active, but will get all times
		
		accumulate += frametime
	
	#make a decision
	else:
		var targetFrameTime = 1./targetFps
		var currentFrameTime = accumulate/measured
		var relative = currentFrameTime/targetFrameTime # how much of target frame time we use
		var relResolution := pow(relative, .5) 			# we scale resolution in x&y, so it will effect performance squared
		
		var newScale := resolutionScale/relResolution 	# adjust so we precisely hit fps target
		newScale = floor(newScale/stepSize)*stepSize	# snap to closest increment, floor because we want to stay above target
		newScale = clamp(newScale, minScale, maxScale)
		
		var currentfps :int = round(1./currentFrameTime)
		if textLabel:
			textLabel.text = str(currentfps) + "fps at " + str(round(resolutionScale*100)) + "%"
		
		#adjust resolution if it has been changed
		if newScale != resolutionScale:
			#print("-- resolution change --")
			#print("we are hitting " + str(relative) + " of target frame time")
			#print("adjust resolution by factor " + str(1./relResolution) )
			print("going from scale " + str(resolutionScale) + " to " + str(newScale) + " at " + str(currentfps) + "fps")
			get_viewport().scaling_3d_scale = newScale
			resolutionScale = newScale
			skipFrames = skipAfterAdjustment
		
		#reset counters
		measured = 0
		accumulate = 0
