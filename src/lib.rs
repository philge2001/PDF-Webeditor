//! PDF Webeditor – PDF Tool im Browser.
//!
//! Stand W0 (Machbarkeitstest): PDF öffnen, mit PDFium (WebAssembly) rendern, mit
//! `pdftool-core` lesen, eine Notiz einfügen und als Download speichern.
//! Der Code läuft nur im Browser (`wasm32`); auf dem Host bleibt die Bibliothek leer.

#[cfg(target_arch = "wasm32")]
mod app;
#[cfg(target_arch = "wasm32")]
mod browser;
#[cfg(target_arch = "wasm32")]
mod pdf;

#[cfg(target_arch = "wasm32")]
pub use web_entry::start;

#[cfg(target_arch = "wasm32")]
mod web_entry {
    use wasm_bindgen::JsCast;
    use wasm_bindgen::prelude::*;

    /// Startet die App im `<canvas>` mit der angegebenen ID.
    ///
    /// Wird aus `web/index.html` aufgerufen, NACHDEM `initialize_pdfium_render` die Brücke
    /// zu pdfium.wasm hergestellt hat – sonst findet pdfium-render keine Bibliothek.
    #[wasm_bindgen]
    pub async fn start(canvas_id: String) -> Result<(), JsValue> {
        console_error_panic_hook::set_once();
        // Schlägt fehl, wenn pdfium-render schon einen Logger gesetzt hat – das ist in Ordnung.
        let _ = console_log::init_with_level(log::Level::Info);

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
                Box::new(|cc| Ok(Box::new(crate::app::WebApp::new(cc)))),
            )
            .await
    }
}
