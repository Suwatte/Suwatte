var global = global || window;

// Initialize Global Handlers
let IDENTIFIER;
let RunnerObject;
let RunnerEnvironment = "unknown";
let RunnerIntents = {
  // Core
  preferenceMenuBuilder: false,
  authenticatable: false,
  authenticationMethod: null,
  // Content Source
  chapterEventHandler: false,
  contentEventHandler: false,
  chapterSyncHandler: false,
  librarySyncHandler: false,
  imageRequestHandler: false,
  explorePageHandler: false,
  hasRecommendedTags: false,
  hasFullTagList: false,

  // Content Tracker
  advancedTracker: false,
  libraryTabProvider: false,
  browseTabProvider: false,
};
const ObjectStore = new STTStore("os");
const SecureStore = new STTStore("ss");

const evaluateEnvironment = () => {
  if (!RunnerObject) return "unknown";

  // Runner Has Implemented all methods required of a "Content Source"
  if (
    RunnerObject.getContent &&
    RunnerObject.getChapters &&
    RunnerObject.getChapterData &&
    RunnerObject.getDirectory &&
    RunnerObject.getDirectoryConfig
  )
    return "source";

  // Runner Has Implemented all methods required of a "Content Plugin"

  if (
    RunnerObject.getHomeFeed &&
    RunnerObject.getFeed &&
    RunnerObject.getDirectory &&
    RunnerObject.getDirectoryConfig
  )
    return "plugin";

  // Runner Has Implemented all methods required of a "Tracker Source"

  if (
    RunnerObject.getTrackState &&
    RunnerObject.getLatestReadChapter &&
    RunnerObject.getResultsForTitles &&
    RunnerObject.getTrackState &&
    RunnerObject.updateTrackState
  )
    return "tracker";

  // Runner author lacks a few brain cells
  return "unknown";
};

const main = () => {
  // Set JSON Date Format
  const moment = require("moment");
  Date.prototype.toJSON = function () {
    return moment(this).format();
  };

  // Initialize Runner & Make Global
  try {
    RunnerObject = new STTPackage.Target(); // Target is a class
  } catch {
    RunnerObject = STTPackage.Target; // Target is an object
  }

  IDENTIFIER = RunnerObject.info.id;
  RunnerEnvironment = evaluateEnvironment();
  // Required Set Up Methods
  overrideConsole(IDENTIFIER);
  setupSourceConfig();

  // Run Post Initialization Methods
  RunnerObject.onRunnerLoaded?.().catch((err) => {
    console.error(`[onRunnerLoaded]`, err);
  });

  // Log
  console.log(`Ready!`);
};

try {
  main();
} catch (err) {
  console.log(err);
}
//
function setupSourceConfig() {
  try {
    ctx = RunnerObject;
    // Preference menu
    RunnerIntents.preferenceMenuBuilder = !!ctx.buildPreferenceMenu;

    // Authentication
    const RunnerAuthenticatable =
      ctx.getAuthenticatedUser && ctx.handleUserSignOut;
    const authenticatable =
      !!ctx.handleBasicAuth ||
      (!!ctx.willRequestWebViewAuth && !!ctx.didReceiveWebAuthCookie);
    if (RunnerAuthenticatable && authenticatable) {
      RunnerIntents.authenticatable = true;
      RunnerIntents.authenticationMethod = !!ctx.handleBasicAuth
        ? "basic"
        : "webview";
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
      RunnerIntents.imageRequestHandler = !!ctx.willRequestImage;
      RunnerIntents.explorePageHandler =
        !!ctx.createExploreCollections &&
        !!ctx.willResolveExploreCollections &&
        !!ctx.resolveExploreCollection;
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
const getSourcePreferences = async () => {
  const data = await RunnerObject.getSourcePreferences();
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
  const groups = await RunnerObject.getSourcePreferences();
  const pref = groups.flatMap((v) => v.children).find((v) => v.key === key);
  if (!pref) return;
  if (pref.action) {
    return pref.action();
  } else {
    return pref.value.set(value);
  }
};
