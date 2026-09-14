let background_canvas = document.createElement("canvas");
let base_canvas = document.createElement("canvas");
let upper_canvas = document.createElement("canvas");

let canvas = document.getElementById("c");
let ctx = canvas.getContext("2d");

let canvases = [
	background_canvas,
	base_canvas,
	upper_canvas,
];

let ctxs = canvases.map(e => e.getContext("2d"));

let zig_environment = {
	get_width: function() { return canvas.width },
	get_height: function() { return canvas.height },
	render: function() {
		ctx.clearRect(0, 0, canvas.width, canvas.height);
		canvases.forEach(e => ctx.drawImage(e, 0, 0));
	},
	canvas_begin_path: function(c) { ctxs[c].beginPath() },
	canvas_line_to: function(c, x, y) { ctxs[c].lineTo(x, y) },
	canvas_move_to: function(c, x, y) { ctxs[c].moveTo(x, y) },
	canvas_fill: function(c) { ctxs[c].fill() },
	canvas_set_fill: function(c, r, g, b) { ctxs[c].fillStyle = `rgb(${r}, ${g}, ${b})` },
}

function resize() {
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
	canvases.forEach(e => {
		e.width = window.innerWidth;
		e.height = window.innerHeight;
	})
}
resize();
window.onresize = resize;
