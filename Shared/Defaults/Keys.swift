//
//  Keys.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-01.
//

enum STTKeys {
    static var IntialTabIndex = "APP.initial_tab"
    static var OpenAllTitlesOnAppear = "LIBRARY.open_all"

    static var TileStyle = "APP.tile_style"
    static var TileSize = "App.tile_size"

    static var AdultContent = "APP.adult_content"
    static var LiveNotifications = "APP.live_notifs"

    static var LibraryGridSortKey = "LIBRARY.sort_key"
    static var LibraryGridSortOrder = "LIBRARY.sort_order"

    static var ChapterListSortKey = "CHAPTER_LIST.sort_key"
    static var ChapterListDescending = "CHAPTER_LIST.sort_order"

    static var ChapterListFilterDuplicates = "CHAPTER_LIST.fitler_duplicates"
    static var ChapterListShowOnlyDownloaded = "CHAPTER_LIST.show_only_downloaded"

    static var incognito = "READER.incognito"

    // Content Specific
    static var IsReadingVertically = "READER.reading_mode_vertical"
    static var IsDoublePagedEnabled = "READER.paged_double"
    static var PagedDirection = "READER.paged_h_direction"

    static var PagePadding = "READER.page_padding"
    static var ForceTransition = "READER.force_transitions"

    static var BackgroundColor = "READER.bg_color"
    static var UseSystemBG = "READER.use_sys_bg"

    static var CropWhiteSpaces = "READER.crop_ws"
    static var DownsampleImages = "READER.downsample_images"

    static var EnableOverlay = "READER.enable_overlay"
    static var OverlayColor = "READER.overlay_color"
    static var OverlayStrenth = "READER.overlay_strength"

    static var TapSidesToNavigate = "READER.tap_to_navigate"
    static var InvertNavigationSides = "READER.invert_tap_to_navigate"
    static var ImageInteractions = "READER.image_interactions"

    static var PagedNavigator = "READER.paged_navigator"
    static var VerticalNavigator = "READER.vertical_navigator"

    static var LastFetchedUpdates = "APP.last_fetched_updates"

    static var LibraryAuth = "LOCAL_AUTH.lib_auth"
    static var LastVerifiedAuth = "LOCAL_AUTH.last_auth_ver"
    static var TimeoutDuration = "LOCAL_AUTH.timeout"

    static var ShowOnlyDownloadedTitles = "LIBRARY.download_only"
    static var ShowUpdateBadges = "LIBRARY.update_badges"

    static var ShowNavigationOverlay = "READER.display_overlay"

    static var anilistAccessToken = "ANILIST.ACCESS_TOKEN"
    static var anilistRefreshToken = "ANILIST.REFRESH_TOKEN"
    static var anilistClientId = "8119"
    static var anilistClientSecret = "35dSqhnynKICceBLJ8dsRFNFNptCJihuj1BW5j55"
    static var anilistRedirectUrl = "suwatte://anilistCallback"

    // Novel Reader
    static var NovelFontSize = "NOVEL.font_size"
    static var NovelFontColor = "NOVEL.font_color"
    static var NovelUseSystemColor = "NOVEL.default_colors"
    static var NovelBGColor = "NOVEL.bg_color"
    static var NovelOrientationLock = "NOVEL.orientation_lock"
    static var NovelUseVertical = "NOVEL.vertical"
    static var NovelUseDoublePaged = "NOVEL.double_paged"
    static var NovelFont = "NOVEL.font"

    // Local
    static var LocalSortLibrary = "LIBRARY.LOCAL.sort"
    static var LocalOrderLibrary = "LIBRARY.LOCAL.order"
    static var LocalThumnailOnly = "LIBRARY.LOCAL.thumnail_only"
    static var LocalHideInfo = "LIBRARY.LOCAL.hide_info"

    // Downloads
    static var DownloadsSortLibrary = "LIBRARY.DOWNLOADS.sort"

    // Global Source Settings
    static var SourcesDisabledFromHistory = "APP.disabled_history"
    static var SourcesHiddenFromGlobalSearch = "APP.global_search_hidden"

    static var GridItemsPerRow_P = "APP.grid_items_per_row_potrait"
    static var GridItemsPerRow_LS = "APP.grid_items_per_row_landscape"

    static var LibrarySections = "LIBRARY.sections"
}
