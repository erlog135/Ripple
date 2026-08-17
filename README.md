# ![Ripple](./assets/RippleFull5.png)

### About this thing
Ripple is a lightweight vector graphics editor and animation studio. (Well, the app itself isn't very lightweight, just the graphics format.)
It's free & open source, and compatible with all major desktop platforms, plus the web.

### What it's for
It's designed to let you create, edit, and convert PDC ([Pebble Draw Command](https://developer.repebble.com/guides/graphics-and-animations/vector-graphics/)) files. Though it is intended for building graphics and animations for the Pebble smartwatch platform, SVG imports and SVG/PNG/GIF exports are supported. So you can certainly use this for general purpose creations, provided you can work with the limited selection of graphics types. 

### How I built it
This app is wholly a [Godot](https://godotengine.org/) project (apart from the Pebble previewing app). App code and architecture were devised in other places, including Cursor and Google AI Studio. Despite being intended for games, the Godot Engine has a surprisingly mature GUI framework, which made some parts of app construction easier. Another big advantage is that it's multiplatform, so I can export this app for Windows, macOS, Linux, and the web! (Plus Android and iOS if I wanted to)

### Why I built it
Ripple was built to solve a very niche problem: there is no free, accessible, modern software that lets you edit vector graphic animations (PDC compatible or otherwise) frame by frame, and import/export in a standard vector file batch. *Please disprove me, because I spent way too much time looking for equivalent software and working on this project.*

Also, this project is intended to be the ancestor of a monumental effort of mine (a glimpse of which is over at [estherapp.org](https://estherapp.org/)), coming some time in the future. With Ripple, I was able to familiarize myself a little bit with a few aspects and best practices of a Model View Controller architecture. I may also use it as a sort of testing ground for more trendy features (like MCP) that I want to try out.

### Problems I'll fix later
- "Raster Preview" doesn't perfectly recreate the rendering logic of Pebble watches. Utilities like [`pdc_tool`](https://pdc-tool.heikobehrens.com/) are currently more accurate for previewing purposes.
- Rasterization tool is slow (it's still GDScript right now)
- SVG imports sometimes crash the editor
- Focus behaves strangely
- Can't rearrange any windows