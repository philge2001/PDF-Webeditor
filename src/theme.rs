//! Erscheinungsbild wie im Portal (github.com/philge2001/portal) und im Hausbuch
//! (github.com/philge2001/vermietung): Apple-Systemfarben, hellgrauer Fenstergrund, weiße Flächen,
//! Haarlinien, Systemblau als Akzent, großzügig gerundete Ecken und weiche Schatten.
//!
//! PDF Tool bringt in `PdfToolApp::new` ein eigenes Schema mit (PDF-Tool `app::style`). egui fragt
//! die Farben bei jedem Bild neu ab, also genügt es, danach einmal unsere Werte darüberzulegen.
//! Ein paar Flächen färbt PDF Tool direkt (Hintergrund hinter den Seiten, schwebende Leisten) –
//! die bleiben, wie sie sind.

use eframe::egui::epaint::text::{FontInsert, FontPriority, FontTweak, InsertFontFamily};
use eframe::egui::{self, Color32, CornerRadius, FontData, FontFamily, Shadow, Stroke, Theme};

/// Farb-Tokens, benannt wie die CSS-Variablen im Portal (`public/css/style.css`).
struct Tokens {
    /// `--bg`: Fenstergrund (Leisten, Seitenbereiche).
    bg: Color32,
    /// `--surface-solid`: Dialoge, Menüs.
    surface: Color32,
    /// Eingabefelder (iOS-Suchfeld: graue Füllung statt Rahmen).
    field: Color32,
    /// `--surface-2` auf dem Fenstergrund: Sekundär-Buttons im Ruhezustand.
    fill: Color32,
    fill_hover: Color32,
    fill_press: Color32,
    /// `--border`: Haarlinien.
    border: Color32,
    /// `--text` und `--text-2`.
    text: Color32,
    text_2: Color32,
    /// `--accent`, `--danger` und Warnfarbe (Hausbuch `--color-warn`).
    accent: Color32,
    danger: Color32,
    warn: Color32,
    /// Schattenfarbe (`--shadow-lg`).
    shadow: Color32,
}

const fn rgb(r: u8, g: u8, b: u8) -> Color32 {
    Color32::from_rgb(r, g, b)
}

// Halbtransparente Portal-Farben (z. B. `rgba(118, 118, 128, 0.12)`) sind hier schon mit dem
// Untergrund verrechnet: egui zeichnet Flächen deckend übereinander, ohne Unschärfe dahinter.
const LIGHT: Tokens = Tokens {
    bg: rgb(242, 242, 247),
    surface: rgb(255, 255, 255),
    field: rgb(236, 236, 240),
    fill: rgb(229, 229, 234),
    fill_hover: rgb(219, 219, 224),
    fill_press: rgb(209, 209, 214),
    border: rgb(216, 216, 221),
    text: rgb(29, 29, 31),
    text_2: rgb(110, 110, 115),
    accent: rgb(0, 113, 227),
    danger: rgb(215, 0, 21),
    warn: rgb(201, 52, 0),
    shadow: Color32::from_black_alpha(36),
};

const DARK: Tokens = Tokens {
    bg: rgb(28, 28, 30),
    surface: rgb(28, 28, 30),
    field: rgb(44, 44, 46),
    fill: rgb(44, 44, 46),
    fill_hover: rgb(58, 58, 60),
    fill_press: rgb(72, 72, 74),
    border: rgb(56, 56, 58),
    text: rgb(245, 245, 247),
    text_2: rgb(161, 161, 166),
    accent: rgb(10, 132, 255),
    danger: rgb(255, 69, 58),
    warn: rgb(255, 159, 10),
    shadow: Color32::from_black_alpha(110),
};

/// Name der UI-Schrift in egui (Inter, wie im Hausbuch als Ersatz für San Francisco).
const UI_FONT: &str = "inter";

/// Legt das Portal-Schema über beide Designs (hell und dunkel).
pub fn install(ctx: &egui::Context) {
    for theme in [Theme::Light, Theme::Dark] {
        let t = if theme == Theme::Dark { &DARK } else { &LIGHT };
        ctx.style_mut_of(theme, |style| {
            let v = &mut style.visuals;
            v.panel_fill = t.bg;
            v.window_fill = t.surface;
            v.faint_bg_color = t.field;
            v.extreme_bg_color = t.surface;
            v.text_edit_bg_color = Some(t.field);
            v.code_bg_color = t.field;
            v.override_text_color = Some(t.text);
            v.weak_text_color = Some(t.text_2);
            v.hyperlink_color = t.accent;
            v.error_fg_color = t.danger;
            v.warn_fg_color = t.warn;
            v.selection.bg_fill = t.accent;
            // Auswahlrahmen (z. B. Fokus im Eingabefeld) in Akzentfarbe, wie `.input:focus`.
            v.selection.stroke = Stroke::new(
                1.0,
                if theme == Theme::Dark {
                    Color32::WHITE
                } else {
                    t.accent
                },
            );

            // Dialoge wie `dialog` im Portal, Menüs wie `.menu`, Schaltflächen etwas runder.
            v.window_stroke = Stroke::new(1.0, t.border);
            v.window_corner_radius = CornerRadius::same(18);
            v.menu_corner_radius = CornerRadius::same(14);
            v.window_shadow = Shadow {
                offset: [0, 16],
                blur: 48,
                spread: 0,
                color: t.shadow,
            };
            v.popup_shadow = Shadow {
                offset: [0, 8],
                blur: 24,
                spread: 0,
                color: t.shadow,
            };

            let w = &mut v.widgets;
            for wv in [
                &mut w.noninteractive,
                &mut w.inactive,
                &mut w.hovered,
                &mut w.active,
                &mut w.open,
            ] {
                wv.corner_radius = CornerRadius::same(8);
                wv.fg_stroke.color = t.text;
            }
            w.noninteractive.bg_fill = t.bg;
            w.noninteractive.weak_bg_fill = t.bg;
            w.noninteractive.bg_stroke = Stroke::new(1.0, t.border);
            w.noninteractive.fg_stroke.color = t.text_2;
            for (wv, fill) in [
                (&mut w.inactive, t.fill),
                (&mut w.hovered, t.fill_hover),
                (&mut w.active, t.fill_press),
                (&mut w.open, t.fill_hover),
            ] {
                wv.bg_fill = fill;
                wv.weak_bg_fill = fill;
                wv.bg_stroke = Stroke::NONE;
                // Kein „Aufblähen“ beim Überfahren: Apple-Buttons bleiben ruhig stehen.
                wv.expansion = 0.0;
            }
            // egui füllt damit auch die Titelzeile des aktiven Fensters; im Portal haben Dialoge
            // keine abgesetzte Titelzeile. Geöffnete Menüknöpfe zeigen dadurch eine helle Pille.
            w.open.weak_bg_fill = t.surface;

            let s = &mut style.spacing;
            s.item_spacing = egui::vec2(8.0, 6.0);
            s.button_padding = egui::vec2(12.0, 5.0);
            s.interact_size.y = 28.0;
            s.menu_margin = egui::Margin::same(6);
            s.window_margin = egui::Margin::same(20);
        });
    }
}

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

/// Hält das Design der umgebenden Webseite (Kopfleiste) im Gleichschritt mit der App:
/// PDF Tool lässt hell/dunkel auch unabhängig vom System umschalten.
/// `Themed` reicht alles an die eigentliche App weiter und meldet nur, wenn das Design wechselt.
pub struct Themed<A> {
    app: A,
    on_theme: Box<dyn FnMut(Theme)>,
    last: Option<Theme>,
}

impl<A> Themed<A> {
    pub fn new(app: A, on_theme: impl FnMut(Theme) + 'static) -> Self {
        Self {
            app,
            on_theme: Box::new(on_theme),
            last: None,
        }
    }
}

impl<A: eframe::App> eframe::App for Themed<A> {
    fn ui(&mut self, ui: &mut egui::Ui, frame: &mut eframe::Frame) {
        self.app.ui(ui, frame);
        let theme = ui.ctx().theme();
        if self.last != Some(theme) {
            self.last = Some(theme);
            (self.on_theme)(theme);
        }
    }

    fn save(&mut self, storage: &mut dyn eframe::Storage) {
        self.app.save(storage);
    }
}
