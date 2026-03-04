{{flutter_js}}

// Request the HTML renderer so that Agora RTC <video> platform views
// are rendered correctly (CanvasKit composites them behind the canvas).
_flutter.loader.load({
  config: {
    // canvasKitBaseUrl: "canvaskit/",
    renderer: "html",
  },
});
