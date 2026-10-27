//! Ergänzungen fürs Erscheinungsbild im Browser: Farben und Formen wie Portal
//! (github.com/philge2001/portal) und Hausbuch (github.com/philge2001/vermietung) bringt PDF Tool
//! selbst mit (PDF-Tool `app::style`). Hier kommen dazu:
//! - Inter als Oberflächenschrift (wie im Hausbuch; die Desktop-App bleibt bei der egui-Schrift),
//! - `Themed`: meldet der Webseite, ob die App gerade hell oder dunkel ist (Titelleiste folgt).

use eframe::egui::epaint::text::{FontInsert, FontPriority, FontTweak, InsertFontFamily};
use eframe::egui::{self, FontData, FontFamily, Theme};

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
