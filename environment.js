let background_canvas = document.createElement("canvas");
let base_canvas = document.createElement("canvas");
let mid_canvas = document.createElement("canvas");
let upper_canvas = document.createElement("canvas");

let canvas = document.getElementById("c");
let ctx = canvas.getContext("2d");

let canvases = [
	background_canvas,
	base_canvas,
	mid_canvas,
	upper_canvas,
];

let ctxs = canvases.map(e => e.getContext("2d"));
const text_decoder = new TextDecoder("utf-8");

let mouse_position = {
	x: 0,
	y: 0,
};

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
	canvas_fill_text: function(c, ptr, len, x, y) {
		const bytes = new Uint8Array(wasm.memory.buffer, ptr, len);
		const str = text_decoder.decode(bytes);
		ctxs[c].fillText(str, x, y);
	}
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

function mousemove(e) {
	mouse_position.x = e.clientX;
	mouse_position.y = e.clientY;
}
window.onmousemove = mousemove;

WebAssembly.instantiateStreaming(fetch("zig-out/bin/nsweep.wasm"), {env: zig_environment}).then(
	(result) => {
		wasm = result.instance.exports;
		wasm.initialize_board((Math.random() * 2 ** 32) >>> 0);
		function render_frame() {
			wasm.update_mouse(mouse_position.x, mouse_position.y);
			wasm.render_board();
			window.requestAnimationFrame(render_frame);
		}
		render_frame();
	},
);
