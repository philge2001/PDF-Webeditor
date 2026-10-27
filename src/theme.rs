//! Ergänzungen fürs Erscheinungsbild im Browser: Farben und Formen wie Portal
//! (github.com/philge2001/portal) und Hausbuch (github.com/philge2001/vermietung) bringt PDF Tool
//! selbst mit (PDF-Tool `app::style`, Hell/Dämmerung/Dunkel). Hier kommen dazu:
//! - Inter als Oberflächenschrift (wie im Hausbuch; die Desktop-App bleibt bei der egui-Schrift),
//! - die gemeinsame Darstellung: Cookie `pz_theme` für die ganze Domain philippzent.com, das auch
//!   Portal und Hausbuch lesen und schreiben (dort `public/js/theme.js` bzw. `lib/theme.ts`).
//!   Wer im Portal „Dämmerung“ wählt, sieht sie hier auch – und umgekehrt.

use eframe::egui::epaint::text::{FontInsert, FontPriority, FontTweak, InsertFontFamily};
use eframe::egui::{self, FontData, FontFamily, Theme};
use pdftool_app::{Appearance, PdfToolApp};
use wasm_bindgen::JsCast;

/// Name der UI-Schrift in egui (Inter, wie im Hausbuch als Ersatz für San Francisco).
const UI_FONT: &str = "inter";

/// Installiert Inter als erste UI-Schrift (die übrigen Schriften bleiben als Ersatz dahinter).
pub fn install_ui_font(ctx: &egui::Context, ttf: Vec<u8>) {
    ctx.add_font(FontInsert::new(
        UI_FONT,
        // Inter läuft breiter als egui's eingebaute Schrift; PDF Tool setzt Kacheln und Leisten mit
        // festen Maßen. Etwas kleiner skaliert passt alles wie bisher (Inter bleibt gut lesbar).
        FontData::from_owned(ttf).tweak(FontTweak {
            scale: 0.92,
            ..Default::default()
        }),
        vec![InsertFontFamily {
            family: FontFamily::Proportional,
            priority: FontPriority::Highest,
        }],
    ));
}

// ---------------------------------------------------------------- gemeinsame Darstellung

const COOKIE: &str = "pz_theme";

/// Wert des Cookies → Darstellung (kein oder unbekannter Wert = wie das System).
pub fn parse_appearance(value: Option<&str>) -> Appearance {
    match value {
        Some("light") => Appearance::Light,
        Some("dusk") => Appearance::Dusk,
        Some("dark") => Appearance::Dark,
        _ => Appearance::System,
    }
}

fn cookie_value(a: Appearance) -> Option<&'static str> {
    match a {
        Appearance::System => None,
        Appearance::Light => Some("light"),
        Appearance::Dusk => Some("dusk"),
        Appearance::Dark => Some("dark"),
    }
}

fn html_document() -> Option<web_sys::HtmlDocument> {
    web_sys::window()?.document()?.dyn_into().ok()
}

/// Aktueller Wert des Cookies (kann sich im Portal oder Hausbuch geändert haben).
fn read_cookie() -> Option<String> {
    let all = html_document()?.cookie().ok()?;
    all.split("; ")
        .find_map(|c| c.strip_prefix(COOKIE)?.strip_prefix('='))
        .filter(|v| !v.is_empty())
        .map(str::to_owned)
}

/// Schreibt das Cookie wie Portal und Hausbuch: unter philippzent.com für die ganze Domain,
/// sonst nur für diesen Host; „System“ löscht es.
fn write_cookie(value: Option<&str>) {
    let Some(doc) = html_document() else { return };
    let location = doc.location();
    let host = location
        .as_ref()
        .and_then(|l| l.hostname().ok())
        .unwrap_or_default();
    let https = location.and_then(|l| l.protocol().ok()).as_deref() == Some("https:");
    let mut cookie = format!(
        "{COOKIE}={}; Path=/; {}; SameSite=Lax",
        value.unwrap_or(""),
        // 400 Tage: die längste Dauer, die Browser zulassen.
        if value.is_some() {
            "Max-Age=34560000"
        } else {
            "Max-Age=0"
        }
    );
    if host == "philippzent.com" || host.ends_with(".philippzent.com") {
        cookie.push_str("; Domain=philippzent.com");
    }
    if https {
        cookie.push_str("; Secure");
    }
    let _ = doc.set_cookie(&cookie);
}

/// `data-theme` an `<html>`: die sichtbare Darstellung, danach richtet sich die Titelleiste.
fn set_page_theme(name: &str) {
    if let Some(root) = web_sys::window()
        .and_then(|w| w.document())
        .and_then(|d| d.document_element())
    {
        let _ = root.set_attribute("data-theme", name);
    }
}

/// Umhüllt die App und hält Cookie, App und Titelleiste im Gleichschritt:
/// - wählt man in der App eine Darstellung, wird das Cookie geschrieben,
/// - ein woanders (Portal, Hausbuch, anderer Tab) geändertes Cookie wird übernommen,
/// - die Titelleiste (`data-theme`) zeigt immer, was die App gerade zeigt.
pub struct Shared {
    app: PdfToolApp,
    /// Zuletzt gesehener Cookie-Wert und Darstellung der App.
    cookie: Option<String>,
    appearance: Appearance,
    page_theme: &'static str,
}

impl Shared {
    /// `cookie`: Wert beim Start (aus `web/index.html`); er hat Vorrang vor der gespeicherten Wahl.
    pub fn new(mut app: PdfToolApp, ctx: &egui::Context, cookie: Option<String>) -> Self {
        let appearance = parse_appearance(cookie.as_deref());
        app.set_appearance(ctx, appearance);
        Self {
            app,
            cookie,
            appearance,
            page_theme: "",
        }
    }

    fn sync(&mut self, ctx: &egui::Context) {
        // Im Portal oder Hausbuch geänderte Wahl übernehmen. egui zeichnet nur bei Eingaben neu
        // (z. B. wenn man in den Tab zurückkommt und die Maus bewegt); das Cookie bei jedem Bild
        // zu lesen kostet kaum etwas und braucht keine Fokus-Ereignisse.
        let cookie = read_cookie();
        if cookie != self.cookie {
            self.appearance = parse_appearance(cookie.as_deref());
            self.app.set_appearance(ctx, self.appearance);
            self.cookie = cookie;
        }

        // In der App umgeschaltet: Cookie schreiben (gilt dann auch in Portal und Hausbuch).
        let appearance = self.app.appearance();
        if appearance != self.appearance {
            self.appearance = appearance;
            let value = cookie_value(appearance);
            write_cookie(value);
            self.cookie = value.map(str::to_owned);
        }

        let page_theme = match (appearance, ctx.theme()) {
            (Appearance::Dusk, _) => "dusk",
            (_, Theme::Dark) => "dark",
            (_, Theme::Light) => "light",
        };
        if page_theme != self.page_theme {
            self.page_theme = page_theme;
            set_page_theme(page_theme);
        }
    }
}

impl eframe::App for Shared {
    fn ui(&mut self, ui: &mut egui::Ui, frame: &mut eframe::Frame) {
        self.app.ui(ui, frame);
        let ctx = ui.ctx().clone();
        self.sync(&ctx);
    }

    fn save(&mut self, storage: &mut dyn eframe::Storage) {
        self.app.save(storage);
    }
}
