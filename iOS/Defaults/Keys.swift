//
//  Keys.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-01.
//

enum STTKeys {
    static let IntialTabIndex = "APP.initial_tab"
    static let OpenAllTitlesOnAppear = "LIBRARY.open_all"

    static let TileStyle = "APP.tile_style"

    static let LibraryGridSortKey = "LIBRARY.sort_key"
    static let LibraryGridSortOrder = "LIBRARY.sort_order"

    static let ChapterListSortKey = "CHAPTER_LIST.sort_key"
    static let ChapterListDescending = "CHAPTER_LIST.sort_order"

    static let ChapterListFilterDuplicates = "CHAPTER_LIST.fitler_duplicates"
    static let ChapterListShowOnlyDownloaded = "CHAPTER_LIST.show_only_downloaded"

    static let incognito = "READER.incognito"

    // Content Specific
    static let IsReadingVertically = "READER.reading_mode_vertical"
    static let VerticalPagerEnabled = "READER.pager.vertical_enabled"
    static let IsDoublePagedEnabled = "READER.paged_double"
    static let PagedDirection = "READER.paged_h_direction"
    static let VerticalAutoScroll = "READER.vertical_auto_scroll"
    static let VerticalAutoScrollSpeed = "READER.vertical_auto_scroll_speed"
    static let VerticalPagePadding = "READER.vertical_page_padding"
    static let VerticalPagePaddingAmount = "READER.vertical.padding.amount"
    static let ForceTransition = "READER.force_transitions"

    static let BackgroundColor = "READER.bg_color"
    static let UseSystemBG = "READER.use_sys_bg"
    static let ReaderFilterBlendMode = "READER.filter_blend_mode"
    static let ReaderGrayScale = "READER.grayscale"
    static let ReaderColorInvert = "Reader.color_invert"

    static let CropWhiteSpaces = "READER.crop_ws"
    static let DownsampleImages = "READER.downsample_images"

    static let EnableOverlay = "READER.enable_overlay"
    static let OverlayColor = "READER.overlay_color"
    static let OverlayStrenth = "READER.overlay_strength"

    static let TapSidesToNavigate = "READER.tap_to_navigate"
    static let InvertNavigationSides = "READER.invert_tap_to_navigate"
    static let ImageInteractions = "READER.image_interactions"

    static let PagedNavigator = "READER.paged_navigator"
    static let VerticalNavigator = "READER.vertical_navigator"

    static let LastFetchedUpdates = "APP.last_fetched_updates"

    static let LibraryAuth = "LOCAL_AUTH.lib_auth"
    static let LastVerifiedAuth = "LOCAL_AUTH.last_auth_ver"
    static let TimeoutDuration = "LOCAL_AUTH.timeout"

    static let ShowOnlyDownloadedTitles = "LIBRARY.download_only"
    static let LibraryShowBadges = "LIBRARY.badges"
    static let LibraryBadgeType = "LIBRARY.badge_type"
    static let ShowNavigationOverlay = "READER.display_overlay"

    // Novel Reader
    static let NovelFontSize = "NOVEL.font_size"
    static let NovelFontColor = "NOVEL.font_color"
    static let NovelUseSystemColor = "NOVEL.default_colors"
    static let NovelBGColor = "NOVEL.bg_color"
    static let NovelOrientationLock = "NOVEL.orientation_lock"
    static let NovelUseVertical = "NOVEL.vertical"
    static let NovelUseDoublePaged = "NOVEL.double_paged"
    static let NovelFont = "NOVEL.font"

    // Local
    static let LocalSortLibrary = "LIBRARY.LOCAL.sort"
    static let LocalOrderLibrary = "LIBRARY.LOCAL.order"
    static let LocalThumnailOnly = "LIBRARY.LOCAL.thumnail_only"
    static let LocalHideInfo = "LIBRARY.LOCAL.hide_info"

    // Downloads
    static let DownloadsSortLibrary = "LIBRARY.DOWNLOADS.sort"

    // Global Source Settings
    static let SourcesDisabledFromHistory = "APP.progress_mark_disabled_sources"
    static let SourcesDisabledFromGlobalSearch = "APP.global_search_disabled_sources"

    static let GridItemsPerRow_P = "APP.grid_items_per_row_portrait"
    static let GridItemsPerRow_LS = "APP.grid_items_per_row_landscape"

    static let LibrarySections = "LIBRARY.sections_1"

    static let SelectiveUpdates = "APP.selective_updates"
    static let JSCommonsVersion = "APP.js_common_version"
    static let AppAccentColor = "APP.accent_color"

    static let HideNSFWRunners = "APP.hide_nsfw_runners"
    static let UpdateInterval = "APP.update_interval"

    static let LastAutoBackup = "APP.last_auto_backup"

    static let OldProgressMarkersMigrated = "APP.old_progressmarkers_migrated"

    static let CheckLinkedOnUpdateCheck = "APP.check_linked_on_update_check"
    static let BlurWhenAppSwiching = "APP.blur_while_switching"
    static let DefaultUserAgent = "APP.default_UserAgent"
    static let UpdateContentData = "APP.update_content_data"
    static let UpdateSkipConditions = "APP.update_skip_conditions"
    static let FilteredProviders = "CONTENT.filtered_providers"
    static let FilteredLanguages = "CONTENT.filtered_langauges"

    static let AlwaysAskForLibraryConfig = "APP.library_always_asks"
    static let DefaultCollection = "LIBRARY.default_collection"
    static let DefaultReadingFlag = "LIBRARY.default_reading_flag"

    static let LocalStorageUsesICloud = "APP.local_use_icloud"

    static func RunnerOverridesImageRequest(_ id: String) -> String {
        "RUNNER.IRH:\(id)"
    }

    static func PageLinkResolver(_ id: String) -> String {
        "RUNNER.PLR:\(id)"
    }

    static let MoveDownloadToArchive = "APP.archive_sdm_objct"

    static let GlobalContentLanguages = "APP.global.content_languages"

    static let GlobalHideNSFW = "APP.global.hide_nsfw"

    static func BlackListedProviders(_ id: String) -> String {
        "RUNNER.BLP:\(id)"
    }

    static let GroupByVolume = "APP.chapter_list.group_by_volume"
    static let GroupByChapter = "APP.chapter_list.group_by_chapter"

    static let OnlyCheckForUpdateInSpecificCollections = "APP.updates.use_collections"
    static let UpdateApprovedCollections = "APP.updates.collections"

    static let RunnerDevMode = "DEBUG.RUNNER_DEV_MODE"
    static let LogAddress = "DEBUG.LOG_ADDRESS"

    static func SourceChapterProviderPriority(_ id: String) -> String {
        "RUNNER.SCPP:\(id)"
    }

    static func TitleHighPriorityOrder(_ id: String) -> String {
        "RUNNER.THPO:\(id)"
    }

    static func TitleBlackListedProviders(_ id: String) -> String {
        "RUNNER.TBLP:\(id)"
    }

    static let BlackListOnSourceLevel = "APP.blacklist_on_source_level"

    static let SyncDatabase = "APP.sync_db"

    static let UseCompactLibraryView = "APP.compact_library"
    
    static let TrackerAutoSync = "APP.tracker_auto_sync"

    static let ImageScaleType = "READER.image_scale"
    static let ReaderType = "READER.type"
    static let VerticalPillarBoxEnabled = "READER.pillar_box_enabled"
    static let VerticalPillarBoxPCT = "READER.pillar_box_pct"
    static let EnableReaderHaptics = "READER.haptics"
    static let PagedSplitsWide = "READER.split_wide"
    static let PagedZoomWide = "READER.zoom_wide"
    static let DefaultPanelReadingMode = "READER.panel_default_mode"
    static let CurrentReadingMode = "READER.current_mode"
    static let OverrideSourceRecommendedReadingMode = "READER.override_provided_mode"
    static let AlwaysMarkFirstPageAsSinglePanel = "READER.mark_first_as_single"
    static let ReaderScrollbarPosition = "READER.scrollbar_position"
    static let ReaderBottomScrollbarDirection = "READER.bottom_scrollbar_direction"
    static let ReaderScrollbarWidth = "READER.scrollbar_width"
    static let ReaderHideMenuOnSwipe = "READER.hide_menu_on_swipe"
}
