let RunnerObject;
let RunnerEnvironment = "unknown";
let RunnerIntents = {
  // Core
  preferenceMenuBuilder: false,
  requiresSetup: false,
  authenticatable: false,
  authenticationMethod: "unknown",
  pageLinkResolver: false,
  libraryPageLinkProvider: false,
  browsePageLinkProvider: false,
  imageRequestHandler: false,

  // Content Source
  chapterEventHandler: false,
  contentEventHandler: false,
  librarySyncHandler: false,

  // MSB
  pageReadHandler: false,
  isAcquisitionEnabled: false,

  // Context Provider
  providesReaderContext: false,
  isContextMenuProvider: false,
  canRefreshHighlight: false,

  // Tags View
  hasTagsView: false,
  // Content Tracker
  advancedTracker: false,

  // hasURL Handler
  canHandleURL: false,

  // Progress Sync Handler
  progressSyncHandler: false,

  groupedUpdateFetcher: false,
};

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

  // Runner Has Implemented all methods required of a "Content Plugin"star

  if (RunnerObject.getHomeFeed && RunnerObject.getFeed) return "plugin";

  // Runner Has Implemented all methods required of a "Content Tracker"

  if (
    RunnerObject.didUpdateLastReadChapter &&
    RunnerObject.getResultsForTitles &&
    RunnerObject.getTrackItem &&
    RunnerObject.beginTracking &&
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
  RunnerObject.onEnvironmentLoaded?.().catch((err) => {
    console.error(`[onEnvironmentLoaded]`, err);
  });

  // Log
  console.log(`Ready!`);

  try {
    if (window) {
      window.addEventListener("load", function (event) {
        window.webkit.messageHandlers.state.postMessage("loaded");
      });
    }
  } catch (err) {}
};

//
function setupSourceConfig() {
  try {
    ctx = RunnerObject;
    // Preference menu
    RunnerIntents.preferenceMenuBuilder = !!ctx.getPreferenceMenu;

    // Requires Setup
    RunnerIntents.requiresSetup =
      !!ctx.getSetupMenu && !!ctx.validateSetupForm && !!ctx.isRunnerSetup;

    //Image Handler
    RunnerIntents.imageRequestHandler = !!ctx.willRequestImage;

    // PageLink
    RunnerIntents.pageLinkResolver =
      !!ctx.getSectionsForPage && !!ctx.resolvePageSection;
    RunnerIntents.libraryPageLinkProvider = !!ctx.getLibraryPageLinks;
    RunnerIntents.browsePageLinkProvider = !!ctx.getBrowsePageLinks;
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
      RunnerIntents.librarySyncHandler = !!ctx.syncUserLibrary;
      RunnerIntents.explorePageHandler =
        !!ctx.createExploreCollections && !!ctx.resolveExploreCollection;
      RunnerIntents.hasTagsView = !!ctx.getTags;

      // MSB
      RunnerIntents.pageReadHandler = !!ctx.onPageRead;
      RunnerIntents.providesReaderContext = !!ctx.provideReaderContext;

      // Context
      RunnerIntents.isContextMenuProvider =
        !!ctx.getContextActions && !!ctx.didTriggerContextAction;
      RunnerIntents.canRefreshHighlight = !!ctx.getHighlight;
      RunnerIntents.progressSyncHandler = !!ctx.getProgressState;
      RunnerIntents.groupedUpdateFetcher = !!ctx.getGroupedUpdates;
        
      RunnerIntents.isRedrawingHandler = !!ctx.shouldRedrawImage && !!ctx.redrawImageWithSize;
    }

    // Content Tracker Intents
    if (RunnerEnvironment === "tracker") {
      RunnerIntents.advancedTracker =
        !!ctx.getDirectory &&
        !!ctx.getDirectoryConfig &&
        !!ctx.getFullInformation;
    }

    RunnerIntents.canHandleURL = !!ctx.handleURL;
  } catch (err) {
    console.error("[Intents]", err.message);
  }
}

// Helper Methods
const updateSourcePreferences = async (id, value) => {
  const form = await RunnerObject.getPreferenceMenu();
  const pref = form.sections
    .flatMap((v) => v.children)
    .find((v) => v.id === id);
  if (!pref) return;
  if (pref.action) {
    return pref.action();
  } else {
    return pref.didChange?.(value);
  }
};

try {
  bootstrap();
} catch (err) {
  console.error("Failed to bootstrap runner object.", err.message);
}
