// Initialize Global Handlers
_logger = new LogHandler();
_store = new StoreHandler();
_network = new NetworkHandler();
let DAISUKE_RUNNER;

/**
 * STT STore Implementation
 */

class STTStore {
  constructor(store) {
    this.store = store;
  }
  store;
  async get(key) {
    const str = await _store.post({
      store: this.store,
      action: "get",
      key,
    });
    if (!str) return null;
    return JSON.parse(str);
  }
  async set(key, value) {
    await _store.post({
      store: this.store,
      action: "set",
      key,
      value: JSON.stringify(value),
    });
    return;
  }
  async remove(key) {
    await _store.post({
      store: this.store,
      action: "remove",
      key,
    });
    return;
  }

  async string(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "string")
      throw new Error(
        "ObjectStore Type Assertion failed, value is not a string"
      );
    return value;
  }
  async boolean(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "boolean")
      throw new Error(
        "ObjectStore Type Assertion failed, value is not a boolean"
      );
    return value;
  }
  async number(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "number")
      throw new Error("ObjectStore Type Assertion failed, value is not number");
    return value;
  }

  async stringArray(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "object" || !Array.isArray(value))
      throw new Error(
        "ObjectStore type assertion failed, value is not an array"
      );

    if (!value?.[0]) return value; // Return If Empty

    const isValid = value.every((v) => typeof v === "string");
    if (!isValid)
      throw new Error(
        `ObjectStore Type Assertion Failed, Elements of Array are not of type string`
      );
    return value;
  }
}
/**
 * ObjectStore Implementation
 *
 */
class ObjectStore extends STTStore {
  constructor() {
    super("os");
  }
}

/**
 * SecureStore Implementation
 */

class SecureStore extends STTStore {
  constructor() {
    super("ss");
  }
}

class NetworkError extends Error {
  req;
  res;
  constructor(name, message, req, res) {
    super(message);
    this.name = name;
    this.message = message;
    this.req = req;
    this.res = res;
  }
}

class CloudflareError extends Error {
  constructor() {
    super("The requested resource is cloudflare protected");
    this.name = "CloudflareError";
  }
}

class NetworkClient {
  transformRequest;
  transformResponse;
  async get(url, config) {
    return this.request({ url, method: "GET", ...config });
  }
  async post(url, config) {
    return this.request({ url, method: "POST", ...config });
  }
  async request(request) {
    const factory = async (r, methods) => {
      for (const m of methods) {
        r = await m(r);
      }
      return r;
    };

    //  Request Transform
    const reqTransformers = [];
    if (this.transformRequest) {
      if (typeof this.transformRequest === "function")
        reqTransformers.push(this.transformRequest);
      else reqTransformers.push(...this.transformRequest);
    }

    if (request.transformRequest) {
      if (typeof request.transformRequest === "function")
        reqTransformers.push(request.transformRequest);
      else reqTransformers.push(...request.transformRequest);
    }

    // Response Transform
    const resTransformers = [];
    if (this.transformResponse) {
      if (typeof this.transformResponse === "function")
        resTransformers.push(this.transformResponse);
      else resTransformers.push(...this.transformResponse);
    }

    if (request.transformResponse) {
      if (typeof request.transformResponse === "function")
        resTransformers.push(request.transformResponse);
      else resTransformers.push(...request.transformResponse);
    }

    // Run Request Transformers
    request = await factory(request, reqTransformers);

    // Dispatch
    let response = await _network.post(request);

    // Run Response Transformers
    response = await factory(response, resTransformers);

    // Validate Status
    const defaultValidateStatus = (s) => s >= 200 && s < 300;
    const validateStatus = request.validateStatus ?? defaultValidateStatus;

    if (!validateStatus(response.status)) {
      if (
        [503, 403].includes(response.status) &&
        response.headers["Server"] === "cloudflare"
      )
        throw new CloudflareError();

      const error = new NetworkError(
        "NetworkError",
        `Request failed with status ${response.status}`,
        request,
        response
      );
      switch (response.status) {
        case 400:
          error.message = "Bad Request";
          break;
        case 401:
          error.message = "Unauthorized";
          break;
        case 403:
          error.message = "Forbidden";
          break;
        case 404:
          error.message =
            "Not Found.\nThe server cannot find the requested resource.";
          break;
        case 405:
          error.message =
            "Method Not Allowed\nThe request method is known by the server but is not supported by the target resource.";
          break;
        case 410:
          error.message = "Gone.";
          break;
        case 429:
          error.message = "Too Many Requests.";
          break;
        case 431:
          error.message =
            "Request Header Fields Too Large.\nThe server is unwilling to process the request because its header fields are too large. ";
          break;
        case 500:
          error.message =
            "Internal Server Error.\nThe server has encountered a situation it does not know how to handle.";
          break;
        case 501:
          error.message =
            "Not Implemented\nThe request method is not supported by the server and cannot be handled.";
          break;
        case 502:
          error.message =
            "Bad Gateway\nThis error response means that the server, while working as a gateway to get a response needed to handle the request, got an invalid response.";
          break;
        case 503:
          error.message =
            "Service Unavailable.The server is not ready to handle the request. Common causes are a server that is down for maintenance or that is overloaded.";
          break;
        case 504:
          error.message =
            "Gateway Timeout\nThis error response is given when the server is acting as a gateway and cannot get a response in time.";
          break;
      }

      throw error;
    }

    return {
      ...response,
      request: request,
    };
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
