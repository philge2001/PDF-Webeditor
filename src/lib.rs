//! PDF Webeditor – PDF Tool im Browser.
//!
//! Die Oberfläche ist dieselbe wie in der Desktop-App: [`pdftool_app::PdfToolApp`] aus dem
//! PDF-Tool-Repository. Hier passiert nur der Start im `<canvas>` der Webseite, dazu die
//! Oberflächenschrift Inter und der Abgleich hell/dunkel mit der Seite (Modul `theme`).
//! Der Code läuft nur im Browser (`wasm32`); auf dem Host bleibt die Bibliothek leer.

#[cfg(target_arch = "wasm32")]
pub use web_entry::start;

#[cfg(target_arch = "wasm32")]
mod theme;

#[cfg(target_arch = "wasm32")]
mod web_entry {
    use wasm_bindgen::JsCast;
    use wasm_bindgen::prelude::*;

    /// Startet die App im `<canvas>` mit der angegebenen ID.
    ///
    /// Wird aus `web/index.html` aufgerufen, NACHDEM `initialize_pdfium_render` die Brücke
    /// zu pdfium.wasm hergestellt hat – sonst findet die App PDFium nicht.
    /// `ui_font`: Inter als `.ttf` (aus `fonts/ui/`); fehlt sie, bleibt egui bei seiner Schrift.
    #[wasm_bindgen]
    pub async fn start(canvas_id: String, ui_font: Option<Vec<u8>>) -> Result<(), JsValue> {
        console_error_panic_hook::set_once();
        // Log-Meldungen der App (tracing) in die Browser-Konsole (F12).
        tracing_wasm::set_as_global_default();

        let canvas = web_sys::window()
            .and_then(|w| w.document())
            .and_then(|d| d.get_element_by_id(&canvas_id))
            .ok_or_else(|| JsValue::from_str("Canvas nicht gefunden"))?
            // `dyn_into` prüft zur Laufzeit, ob das Element wirklich ein <canvas> ist.
            .dyn_into::<web_sys::HtmlCanvasElement>()?;

        eframe::WebRunner::new()
            .start(
                canvas,
                eframe::WebOptions::default(),
                // Keine Startdateien und kein Vergleich – im Browser öffnet man über die Oberfläche.
                Box::new(|cc| {
                    // Farben und Formen wie Portal/Hausbuch bringt PDF Tool selbst mit (`app::style`).
                    let app = pdftool_app::PdfToolApp::new(cc, Vec::new(), None);
                    if let Some(ttf) = ui_font {
                        crate::theme::install_ui_font(&cc.egui_ctx, ttf);
                    }
                    Ok(Box::new(crate::theme::Themed::new(app, set_page_theme)))
                }),
            )
            .await
    }

    /// Schreibt das aktuelle Design als `data-theme` an `<html>`; das CSS der Seite richtet sich danach.
    fn set_page_theme(theme: eframe::egui::Theme) {
        let name = match theme {
            eframe::egui::Theme::Dark => "dark",
            eframe::egui::Theme::Light => "light",
        };
        if let Some(root) = web_sys::window()
            .and_then(|w| w.document())
            .and_then(|d| d.document_element())
        {
            let _ = root.set_attribute("data-theme", name);
        }
    }
}
