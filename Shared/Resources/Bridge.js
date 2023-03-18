// Initialize Global Handlers
_logger = new LogHandler();
_store = new StoreHandler();
let DAISUKE_RUNNER;
/**
 * SecureStore Implementation
 */
class SecureStore {
  async get(key) {
    const str = await _store.post({
      store: "ss",
      action: "get",
      key,
    });

    if (!str) return null;
    return JSON.parse(str);
  }
  async set(key, value) {
    await _store.post({
      store: "ss",
      action: "set",
      key,
      value: JSON.stringify(value),
    });
    return;
  }
  async remove(key) {
    await _store.post({
      store: "ss",
      action: "remove",
      key,
    });
    return;
  }
}

/**
 * ObjectStore Implementation
 *
 */
class ObjectStore {
  async get(key) {
    const str = await _store.post({
      store: "os",
      action: "get",
      key,
    });
    if (!str) return null;
    return JSON.parse(str);
  }
  async set(key, value) {
    await _store.post({
      store: "os",
      action: "set",
      key,
      value: JSON.stringify(value),
    });
    return;
  }
  async remove(key) {
    await _store.post({
      store: "os",
      action: "remove",
      key,
    });
    return;
  }
}

/**
 * Required Setup
 */
const main = () => {
  // Set JSON Date Format
  const moment = require("moment");
  Date.prototype.toJSON = function () {
    return moment(this).format();
  };

  // Initialize Runner & Make Global
  DAISUKE_RUNNER = new STTPackage.Target();
  // Required Set Up Methods
  overrideConsole(DAISUKE_RUNNER.info.id);
  setupSourceConfig();

  // Run Post Initialization Methods
  if (DAISUKE_RUNNER.onSourceLoaded) {
    DAISUKE_RUNNER.onSourceLoaded()
      .then(() => {
        console.log("Runner OnSourceLoaded Executed");
      })
      .catch((err) => {
        console.log("Runner OnSourceLoaded Failed", err);
      });
  }

  //
  console.log(`${DAISUKE_RUNNER.info.name} Initialized.`);
};

try {
  main();
} catch (err) {
  console.log(err);
}
//
function setupSourceConfig() {
  try {
    const config = DAISUKE_RUNNER.info.config ?? {};

    config.hasExplorePage = !!DAISUKE_RUNNER.createExploreCollections;
    config.hasExplorePageTags = !!DAISUKE_RUNNER.getExplorePageTags;
    config.hasSourceTags = !!DAISUKE_RUNNER.getSourceTags;
    config.canFetchChapterMarkers = !!DAISUKE_RUNNER.getReadChapterMarkers;
    config.canSyncWithSource = !!DAISUKE_RUNNER.syncUserLibrary;
    config.hasPreferences = !!DAISUKE_RUNNER.getSourcePreferences;
    config.hasThumbnailInterceptor = !!DAISUKE_RUNNER.willRequestImage;
    config.hasCustomCloudflareRequest =
      !!DAISUKE_RUNNER.getCloudflareVerificationRequest;

    if (config.chapterDataCachingDisabled === undefined)
      config.chapterDataCachingDisabled = false;
    if (config.chapterDateUpdateDisabled === undefined)
      config.chapterDateUpdateDisabled = false;

    DAISUKE_RUNNER.info.config = config;
  } catch (err) {
    console.log("Source Configuration Error", err);
  }
}
function overrideConsole(context) {
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
      context,
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
// Helper Methods
const getSourcePreferences = async () => {
  const data = await DAISUKE_RUNNER.getSourcePreferences();
  for (const [index, group] of data.entries()) {
    const populated = await Promise.all(
      group.children.map(async (v) => ({
        ...v,
        value: v.action ? "" : await v.value.get(),
      }))
    );
    data[index].children = populated;
  }
  return data;
};

const updateSourcePreferences = async (key, value) => {
  const groups = await DAISUKE_RUNNER.getSourcePreferences();
  const pref = groups.flatMap((v) => v.children).find((v) => v.key === key);
  if (!pref) return;
  if (pref.action) {
    return pref.action();
  } else {
    return pref.value.set(value);
  }
};
