implement BouncingBall;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Point, Rect, Display, Image, Screen, Context: import draw;

include "tk.m";
include "wmclient.m";
	wmclient: Wmclient;
	Window: import wmclient;

include "arg.m";

BouncingBall: module {
	init:	fn(ctxt: ref Context, argv: list of string);
};

ZP: con Point(0, 0);	# 0,0 point

bg: ref Image;			# Window background color
width: int = 600;		# Width of window

radius: int = 20;		# Radius of ball
BP: Point;				# Point of ball relative to top left corner
ballimg: ref Image;		# Image of ball

# Draw a bouncing ball on the screen
init(ctxt: ref Context, argv: list of string) {
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	wmclient = load Wmclient Wmclient->PATH;
	arg := load Arg Arg->PATH;

	# Commandline args
	arg->init(argv);
	arg->setusage("bb [-r radius] [-w width]");

	while((c := arg->opt()) != 0)
		case c {
		'r' =>
			radius = int arg->earg();
		'w' =>
			width = int arg->earg();
		* =>
			arg->usage();
		}

	argv = arg->argv();

	# Window setup
	sys->pctl(Sys->NEWPGRP, nil);
	wmclient->init();

	w := wmclient->window(ctxt, "Bouncing ball", Wmclient->Appl);

	display := w.display;

	# Graphical artifacts
	bg = display.rgb(192, 192, 192);
	ballimg = display.newimage(Rect(ZP, (radius,radius)), Draw->CMAP8, 1, Draw->Red);

	# Make the window appear
	w.reshape(Rect(ZP, (width, width)));
	w.startinput("ptr" :: nil);
	w.onscreen(nil);

	# Set initial ball location to center of window
	# r.min in this case is top left of a window, r.max bottom right
	r := w.image.r;
	offset := r.max.sub(r.min).div(2);
	#offset := Point(width/2, width/2);
	BP = r.min.add(offset);

	# Draw ball initially
	drawball(w.image);

	for(;;)
		alt{
		ctl := <-w.ctl or
		ctl = <-w.ctxt.ctl =>
			w.wmctl(ctl);
			if(ctl != nil && ctl[0] == '!')
				# draw ball again
				drawball(w.image);

		p := <-w.ctxt.ptr =>
			w.pointer(*p);

		# Maybe set up a tick channel to re-draw frame by frame?
		}

	exit;
}

# Draw the ball for a frame
drawball(screen: ref Image) {
	if(screen == nil)
		return;

	# Draw the screen background
	screen.draw(screen.r, bg, nil, ZP);

	# TODO - Move circle?

	# Get the range of pixels in the screen 
	r := screen.r;

	targ := r.min.add(BP);

	# Draw circle
	screen.fillellipse(targ, radius, radius, ballimg, ZP);

	# Flush screen
	screen.flush(Draw->Flushnow);
}

# Move the ball in reference to screen corner
mvball(screen: ref Image, x, y: int) {
	if(screen == nil)
		return;

	r := screen.r;

	# TODO - Handle collisions

	#BP = p;
}
