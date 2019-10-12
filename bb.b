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
include "daytime.m";
include "rand.m";

BouncingBall: module {
	init:	fn(ctxt: ref Context, argv: list of string);
};

NE, NW, SE, SW: con iota;	# Directions ball can move
ZP: con Point(0, 0);		# 0,0 point
delay: con 10;				# ms to draw on

bg: ref Image;				# Window background color
width: int = 600;			# Width of window

bearing: int;				# Starting movement vector of ball
radius: int = 20;			# Radius of ball
BP: Point;					# Point of ball relative to top left corner
ballimg: ref Image;			# Image of ball
ballbg: ref Image;

# Draw a bouncing ball on the screen
init(ctxt: ref Context, argv: list of string) {
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	wmclient = load Wmclient Wmclient->PATH;
	arg := load Arg Arg->PATH;
	rand := load Rand Rand->PATH;
	time := load Daytime Daytime->PATH;

	rand->init(time->now());

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
	bg = display.rgb(192, 192, 192);	# 0xC0C0C0FF
	ballbg = display.newimage(Rect(ZP, (radius+2,radius+2)), Draw->RGB24, 1, int 16rC0C0C0FF);	# (192, 192, 192)
	ballimg = display.newimage(Rect(ZP, (radius,radius)), Draw->RGB24, 1, Draw->Red);

	# Make the window appear
	w.reshape(Rect(ZP, (width, width)));
	w.startinput("ptr" :: nil);
	w.onscreen(nil);

	# Set initial ball location to above center of window
	# We don't want exact center to avoid cornering ☺
	# Windows are represented as rectangles
	# r.min in this case is top left of a window, r.max bottom right
	r := w.image.r;
	offset := r.max.sub(r.min).div(2);
	offset = offset.sub(Point(0, offset.y/2));
	BP = r.min.add(offset);

	# Draw background and ball initially
	w.image.draw(w.image.r, bg, nil, ZP);
	drawball(w.image);
	bearing = rand->rand(4);	# 4 bearings

	# Kick off draw timer
	tickchan := chan of int;
	spawn ticker(tickchan);

	for(;;)
		alt {
		ctl := <-w.ctl or
		ctl = <-w.ctxt.ctl =>
			w.wmctl(ctl);
			if(ctl != nil && ctl[0] == '!')
				# draw ball again(?)
				;

		p := <-w.ctxt.ptr =>
			w.pointer(*p);

		# Draw on ticks
		<-tickchan =>
			drawball(w.image);
		}

	exit;
}

# Draw the ball for a frame
drawball(screen: ref Image) {
	if(screen == nil)
		return;

	# Get the range of pixels in the screen 
	r := screen.r;

	# Draw an ellipse around where we were in the bg color of thickness 2px
	targ := r.min.add(BP);
	screen.ellipse(targ, radius+2, radius+2, 2, ballbg, ZP);

	# Move circle
	mvball(screen, bear(BP));

	targ = r.min.add(BP);

	# Draw circle
	screen.fillellipse(targ, radius, radius, ballimg, ZP);

	# Flush screen
	#screen.flush(Draw->Flushnow);
}

# Apply bearing shifts to the ball
bear(p: Point): Point {
	x := p.x;
	y := p.y;

	case bearing {
		NE =>
			x++;
			y--;
		NW => 
			x--;
			y--;
		SE =>
			x++;
			y++;
		SW =>
			x--;
			y++;
	}

	return Point(x, y);
}

# Move the ball in reference to screen corner
mvball(screen: ref Image, p: Point) {
	if(screen == nil)
		return;

	# Window rectangle
	r := screen.r;

	# Make the rectangle smaller by radius for collision
	r.min.x += radius;
	r.min.y -= radius;
	r.max.x -= radius;
	r.max.y -= radius*3;	# Oh no is this some π shenanigans?

	# Point.add() means negative values should concatenate just fine
	targ := p;

	# Check if we're within the rectangle
	if(! targ.in(r)) {

		# We rotate our direction
		case bearing {
		NE =>
			bearing = SE;
		NW => 
			bearing = NE;
		SE =>
			bearing = SW;
		SW =>
			bearing = NW;
		}

		targ = BP;
	}

	BP = targ;
}

# Ticks every delay milliseconds to draw
ticker(tickchan: chan of int) {
	for(;;) {
		sys->sleep(delay);
		tickchan <-= 1;
	}
}
