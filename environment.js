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
		ctx.drawImage(background_ctx, 0, 0);
		ctx.drawImage(base_ctx, 0, 0);
		ctx.drawImage(upper_ctx, 0, 0);
	}
}

function resize() {
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
	canvases.forEach(e => {
		e.width = window.innerWidth;
		e.height = window.innerHieght;
	})
}
resize();
window.onresize = resize;
