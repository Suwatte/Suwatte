_logger = new LogHandler();

function overrideConsole() {
    function log(level, args) {
        const message = `${Object.values(args)
      .map((v) =>
        typeof v === "undefined"
          ? "undefined"
          : typeof v === "object"
          ? JSON.stringify(v)
          : v.toString()
      )
      .map((v) => v.substring(0, 3000)) // Limit msg to 3000 chars
      .join(", ")}`;
        _logger.post({
            context: IDENTIFIER ?? "BOOTSTRAP",
            level,
            message,
        });
    }
    
    let originalLog = console.log;
    let originalWarn = console.warn;
    let originalError = console.error;
    let originalDebug = console.debug;
    let originalInfo = console.info;
    
    console.log = function () {
        log("LOG", arguments);
        originalLog.apply(null, arguments);
    };
    console.warn = function () {
        log("WARN", arguments);
        originalWarn.apply(null, arguments);
    };
    console.error = function () {
        log("ERROR", arguments);
        originalError.apply(null, arguments);
    };
    console.debug = function () {
        log("DEBUG", arguments);
        originalDebug.apply(null, arguments);
    };
    console.info = function () {
        log("INFO", arguments);
        originalInfo.apply(null, arguments);
    };
}

try {
    overrideConsole();
} catch (err) {
    _logger.post({
    level: "ERROR",
    message: err.message,
    });
}

