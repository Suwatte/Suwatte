// Initialize Global Handlers
let RunnerObject;
let RunnerEnvironment = "unknown";
let RunnerIntents = {
  // Core
  preferenceMenuBuilder: false,
  authenticatable: false,
  authenticationMethod: "unknown",
  pageLinkResolver: false,
  pageLinkProvider: false,
  imageRequestHandler: false,

  // Content Source
  chapterEventHandler: false,
  contentEventHandler: false,
  chapterSyncHandler: false,
  librarySyncHandler: false,
  hasTagsView: false,
  // Content Tracker
  advancedTracker: false,
};

const ObjectStore = new STTStore("os");
const SecureStore = new STTStore("ss");

// Reference:
function isClass(v) {
  return typeof v === "function" && /^\s*class\s+/.test(v.toString());
}

const evaluateEnvironment = () => {
  if (!RunnerObject) return "unknown";

  // Runner Has Implemented all methods required of a "Content Source"
  if (
    RunnerObject.getContent &&
    RunnerObject.getChapters &&
    RunnerObject.getChapterData
  )
    return "source";

  // Runner Has Implemented all methods required of a "Content Plugin"

  if (RunnerObject.getHomeFeed && RunnerObject.getFeed) return "plugin";

  // Runner Has Implemented all methods required of a "Tracker Source"

  if (
    RunnerObject.didUpdateLastReadChapter &&
    RunnerObject.getResultsForTitles &&
    RunnerObject.getTrackItem &&
    RunnerObject.beginTracking &&
    RunnerObject.stopTracking &&
    RunnerObject.getEntryForm &&
    RunnerObject.didSubmitEntryForm
  )
    return "tracker";

  // Runner author lacks a few brain cells
  return "unknown";
};

const bootstrap = () => {
  // Set JSON Date Format
  const moment = require("moment");
  Date.prototype.toJSON = function () {
    return moment(this).format();
  };

  const T = STTPackage.Target;

  if (isClass(T)) {
    RunnerObject = new T();
  } else {
    RunnerObject = T;
  }

  IDENTIFIER = RunnerObject.info.id;
  RunnerEnvironment = evaluateEnvironment();
  // Required Set Up Methods
  setupSourceConfig();

  // Run Post Initialization Methods
  RunnerObject.onRunnerLoaded?.().catch((err) => {
    console.error(`[onRunnerLoaded]`, err);
  });

  // Log
  console.log(`Ready!`);
};

//
function setupSourceConfig() {
  try {
    ctx = RunnerObject;
    // Preference menu
    RunnerIntents.preferenceMenuBuilder = !!ctx.buildPreferenceMenu;

    //Image Handler
    RunnerIntents.imageRequestHandler = !!ctx.willRequestImage;

    // PageLink
    RunnerIntents.pageLinkResolver =
      !!ctx.getPage && !!ctx.willResolvePage && !!ctx.resolvePageSection;
    RunnerIntents.pageLinkProvider =
      !!ctx.getLibraryPageLinks && !!ctx.getBrowsePageLinks;
    // Authentication
    const RunnerAuthenticatable =
      !!ctx.getAuthenticatedUser && !!ctx.handleUserSignOut;

    const basicAuthenticatable = !!ctx.handleBasicAuth;
    const webViewAuthenticatable =
      !!ctx.getWebAuthRequestURL &&
      !!ctx.didReceiveSessionCookieFromWebAuthResponse;
    const oAuthAuthenticatable =
      !!ctx.getOAuthRequestURL && !!ctx.handleOAuthCallback;
    const authenticatable =
      basicAuthenticatable || webViewAuthenticatable || oAuthAuthenticatable;
    if (RunnerAuthenticatable && authenticatable) {
      RunnerIntents.authenticatable = true;
      RunnerIntents.authenticationMethod = basicAuthenticatable
        ? "basic"
        : webViewAuthenticatable
        ? "webview"
        : oAuthAuthenticatable
        ? "oauth"
        : "unknown";
      RunnerIntents.basicAuthLabel = ctx.BasicAuthUIIdentifier;
    }

    // Content Source Intents
    if (RunnerEnvironment === "source") {
      RunnerIntents.chapterEventHandler =
        !!ctx.onChaptersMarked && !!ctx.onChapterRead;
      RunnerIntents.contentEventHandler =
        !!ctx.onContentsAddedToLibrary &&
        !!ctx.onContentsRemovedFromLibrary &&
        !!ctx.onContentsReadingFlagChanged;
      RunnerIntents.chapterSyncHandler = !!ctx.getReadChapterMarkers;
      RunnerIntents.librarySyncHandler = !!ctx.syncUserLibrary;
      RunnerIntents.explorePageHandler =
        !!ctx.createExploreCollections && !!ctx.resolveExploreCollection;
      RunnerIntents.hasTagsView = !!ctx.getTags;
    }

    // Content Tracker Intents
    if (RunnerEnvironment === "tracker") {
      RunnerIntents.advancedTracker =
        !!ctx.getRecommendedTitles &&
        !!ctx.getDirectory &&
        !!ctx.getDirectoryConfig &&
        !!ctx.getInfo;

      RunnerIntents.libraryTabProvider = !!ctx.getLibraryTabs;
      RunnerIntents.browseTabProvider = !!ctx.getBrowseTabs;
    }
  } catch (err) {
    console.error("[Intents]", err);
  }
}

// Helper Methods
const generatePreferenceMenu = async () => {
  const data = await RunnerObject.buildPreferenceMenu();
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
  const groups = await RunnerObject.buildPreferenceMenu();
  const pref = groups.flatMap((v) => v.children).find((v) => v.key === key);
  if (!pref) return;
  if (pref.action) {
    return pref.action();
  } else {
    return pref.value.set(value);
  }
};

try {
  bootstrap();
} catch (err) {
  console.error("Failed to bootstrap runner object.", err.message);
}
