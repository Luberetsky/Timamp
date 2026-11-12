/// The name this build shows to the user.
///
/// Internal identifiers keep the upstream "AmpX": the bundle identifier, the UserDefaults keys and
/// the type names. Renaming those would drop saved settings, playlists and window positions.
/// `CFBundleName` and `CFBundleDisplayName` in `Resources/Info.plist` repeat `name`; macOS takes the
/// menu bar title and the About panel name from there. The app target therefore has
/// `GENERATE_INFOPLIST_FILE = NO`: with generation on, Xcode replaces `CFBundleName` with `PRODUCT_NAME`.
enum AmpXBrand {
    /// Program name in running text: menus, alerts, panels, accessibility.
    static let name = "Timamp"
    /// Wordmark drawn next to the bolt in module headers and in the collapsed strip.
    static let wordmark = "TIMAMP"
}
