/**
 * NetworkClient Implementation
 */
class NetworkClient {
  post(url, config) {
    return this.request({ ...config, url, method: "POST" });
  }
  get(url, config) {
    return this.request({ ...config, url, method: "GET" });
  }
  async request(request) {
    request = (await this.requestInterceptHandler?.(request)) ?? request;
    let response = await window.webkit.messageHandlers.networking.postMessage(
      request
    );
    response = (await this.responseInterceptHandler?.(response)) ?? response;
    return response;
  }
}
/**
 * SecureStore Implementation
 */
class SecureStore {
  async get(key) {
    const str = await window.webkit.messageHandlers.store.postMessage({
      store: "ss",
      action: "get",
      key,
    });

    if (!str) return null;
    return JSON.parse(str);
  }
  async set(key, value) {
    await window.webkit.messageHandlers.store.postMessage({
      store: "ss",
      action: "set",
      key,
      value: JSON.stringify(value),
    });
    return;
  }
  async remove(key) {
    await window.webkit.messageHandlers.store.postMessage({
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
    const str = await window.webkit.messageHandlers.store.postMessage({
      store: "os",
      action: "get",
      key,
    });
    if (!str) return null;
    return JSON.parse(str);
  }
  async set(key, value) {
    await window.webkit.messageHandlers.store.postMessage({
      store: "os",
      action: "set",
      key,
      value: JSON.stringify(value),
    });
    return;
  }
  async remove(key) {
    await window.webkit.messageHandlers.store.postMessage({
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
  // Handle Load Event
  window.addEventListener("load", function (event) {
    console.log("Client Ready!");
    window.webkit.messageHandlers.state.postMessage("loaded");
  });

  // Set JSON Date Format
  const moment = require("moment");
  Date.prototype.toJSON = function () {
    return moment(this).format();
  };

  // Initialize Runner & Make Global
  const RUNNER = new STTPackage.Target();
  window.RUNNER = RUNNER;

  // Required Set Up Methods
  overrideConsole(RUNNER.info.id);
  setupSourceConfig();

  // Run Post Initialization Methods
  if (RUNNER.onSourceLoaded) {
    RUNNER.onSourceLoaded()
      .then(() => {
        console.log("Runner OnSourceLoaded Executed");
      })
      .catch((err) => {
        console.log("Runner OnSourceLoaded Failed", err);
      });
  }

  //
  console.log(`${RUNNER.info.name} Initialized.`);
};

try {
  main();
} catch (err) {
  console.log(err);
}
const prepare = (data) => {
  if (!data) return;
  return JSON.stringify(data);
};

// * Content Source Methods

const getContent = async (id) => {
  const data = await RUNNER.getContent(id);
  return prepare(data);
};

const getChapters = async (id) => {
  const data = await RUNNER.getChapters(id);
  return prepare(data);
};

const getChapterData = async (contentId, chapterId) => {
  const data = await RUNNER.getChapterData(contentId, chapterId);
  return prepare(data);
};

const getSearchResults = async (request) => {
  const data = await RUNNER.getSearchResults(request);
  return prepare(data);
};

const getSearchFilters = async () => {
  const data = await RUNNER.getSearchFilters?.();
  return prepare(data);
};
const getSearchSorters = async () => {
  const data = await RUNNER.getSearchSorters?.();
  return prepare(data);
};
const createExploreCollections = async () => {
  const data = await RUNNER.createExploreCollections?.();
  return prepare(data);
};

const willResolveExploreCollections = async () => {
  if (!RUNNER.willResolveExploreCollections) return;
  await RUNNER.willResolveExploreCollections();
};

const resolveExploreCollection = async (excerpt) => {
  if (!RUNNER.resolveExploreCollection) throw "This method is not implemented";
  const data = await RUNNER.resolveExploreCollection(excerpt);
  return prepare(data);
};

const getExplorePageTags = async () => {
  const data = await RUNNER.getExplorePageTags?.();
  return prepare(data);
};

const getSourceTags = async () => {
  const data = await RUNNER.getSourceTags?.();
  return prepare(data);
};

// const getSourcePreferences = async () => {
//   const data = await RUNNER.getSourcePreferences?.();
//   return prepare(data);
// };
const getSourcePreferences = async () => {
  const data = await RUNNER.getSourcePreferences();
  for (const [index, group] of data.entries()) {
    const populated = await Promise.all(
      group.children.map(async (v) => ({
        ...v,
        value: v.action ? "" : await v.value.get(),
      }))
    );
    data[index].children = populated;
  }
  return prepare(data);
};

const updateSourcePreferences = async (key, value) => {
  const groups = await RUNNER.getSourcePreferences();
  const pref = groups.flatMap((v) => v.children).find((v) => v.key === key);

  if (!pref) return;

  if (pref.action) {
    return pref.action();
  } else {
    return pref.value.set(value);
  }
};
const handleIdentifierForUrl = async (url) => {
  const data = await RUNNER.handleIdentifierForUrl?.(url);
  return prepare(data);
};

// * Sync Source Methods

const onContentsAddedToLibrary = async (ids) => {
  const data = await RUNNER.onContentsAddedToLibrary?.(ids);
  return prepare(data);
};

const onContentsRemovedFromLibrary = async (ids) => {
  const data = await RUNNER.onContentsRemovedFromLibrary?.(ids);
  return prepare(data);
};

const onContentsReadingFlagChanged = async (ids, flag) => {
  const data = await RUNNER.onContentsReadingFlagChanged?.(ids, flag);
  return prepare(data);
};

const onChaptersMarked = async (contentId, chapterIds, completed) => {
  const data = await RUNNER.onChaptersMarked?.(
    contentId,
    chapterIds,
    completed
  );
  return prepare(data);
};

const onChapterRead = async (contentId, chapterId) => {
  const data = await RUNNER.onChapterRead?.(contentId, chapterId);
  return prepare(data);
};

const syncUserLibrary = async (library) => {
  const data = await RUNNER.syncUserLibrary?.(library);
  return prepare(data);
};

const getReadChapterMarkers = async (contentId) => {
  const data = await RUNNER.getReadChapterMarkers?.(contentId);
  return prepare(data);
};

// * Auth Source Methods
const getAuthenticatedUser = async () => {
  const data = await RUNNER.getAuthenticatedUser();
  return prepare(data);
};

const handleBasicAuthentication = async (id, password) => {
  if (!RUNNER.handleBasicAuthentication)
    throw new Error(
      "Method Not Implemented. The Source has stated it uses basic authentication but the handler method has not been implemented"
    );
  return await RUNNER.handleBasicAuthentication(id, password);
};

const handleUserSignOut = async () => {
  if (!RUNNER.handleUserSignOut)
    throw new Error(
      "Method Not Implemented. The Source has provided an authentication solution but not implemented the Sign-Out Handler"
    );
  return await RUNNER.handleUserSignOut();
};

const willRequestAuthenticationWebView = async () => {
  if (!RUNNER.willRequestAuthenticationWebView)
    throw new Error(
      "Method Not Implemented. The Source has stated it uses the WebView Authentication method but has not implemented the required handler method (willRequestAuthenticationWebView)"
    );

  const data = await RUNNER.willRequestAuthenticationWebView();
  return prepare(data);
};

const didReceiveAuthenticationCookieFromWebView = async (cookie) => {
  if (!RUNNER.didReceiveAuthenticationCookieFromWebView)
    throw new Error(
      "Method Not Implemented. The Source has stated it uses the WebView Authentication method but has not implemented the required handler method (didReceiveAuthenticationCookieFromWebView)"
    );

  const didReceive = await RUNNER.didReceiveAuthenticationCookieFromWebView(
    cookie
  );

  return prepare({ didReceive });
};

//
function setupSourceConfig() {
  try {
    const config = RUNNER.info.config ?? {};

    config.hasExplorePage = !!RUNNER.createExploreCollections;
    config.hasExplorePageTags = !!RUNNER.getExplorePageTags;
    config.hasSourceTags = !!RUNNER.getSourceTags;
    config.canFetchChapterMarkers = !!RUNNER.getReadChapterMarkers;
    config.canSyncWithSource = !!RUNNER.syncUserLibrary;
    config.hasPreferences = !!RUNNER.getSourcePreferences;
    config.hasThumbnailInterceptor = !!RUNNER.willRequestImage;
    config.hasCustomCloudflareRequest =
      !!RUNNER.getCloudflareVerificationRequest;

    if (config.chapterDataCachingDisabled === undefined)
      config.chapterDataCachingDisabled = false;
    if (config.chapterDateUpdateDisabled === undefined)
      config.chapterDateUpdateDisabled = false;

    RUNNER.info.config = config;
  } catch (err) {
    console.log("Err");
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
    window.webkit.messageHandlers.logging.postMessage({
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

  window.addEventListener("error", function (e) {
    log("JS Error", [`${e.message}`]);
  });
}
